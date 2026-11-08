import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'speech_api.dart';
import 'speech_preset.dart';

/// How Voxen reads.
enum ReadMode {
  /// Kokoro when it answers, otherwise the device voice.
  auto,
  kokoro,
  device,

  /// OpenAI or another OpenAI-compatible endpoint, as a generated MP3.
  api,
}

extension ReadModeLabel on ReadMode {
  String get label => switch (this) {
    ReadMode.auto => 'Automatic',
    ReadMode.kokoro => 'Kokoro only',
    ReadMode.device => 'Device voice only',
    ReadMode.api => 'Other API · MP3 export',
  };
}

enum KokoroState {
  notSetUp,
  needsToken,
  unknown,
  checking,
  available,
  offline,
  rejected,
}

@immutable
class KokoroStatus {
  const KokoroStatus(this.state, {this.voiceCount = 0, this.checkedAt});
  final KokoroState state;
  final int voiceCount;
  final DateTime? checkedAt;

  bool get isAvailable => state == KokoroState.available;

  String get label => switch (state) {
    KokoroState.notSetUp => 'Not set up: add the server address',
    KokoroState.needsToken => 'Needs the token',
    KokoroState.unknown => 'Not checked yet',
    KokoroState.checking => 'Checking…',
    KokoroState.available => 'Available · $voiceCount voices',
    KokoroState.offline => 'Offline: is the Mac awake and online?',
    KokoroState.rejected => 'Token rejected',
  };
}

/// Where settings live. Plain values go to preferences; the Kokoro token goes
/// to the platform's secure storage, and only when the user asks.
abstract class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<String?> readSecret(String key);
  Future<void> writeSecret(String key, String? value);
}

class DeviceSettingsStore implements SettingsStore {
  final _secure = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    value == null ? await prefs.remove(key) : await prefs.setString(key, value);
  }

  @override
  Future<String?> readSecret(String key) => _secure.read(key: key);

  @override
  Future<void> writeSecret(String key, String? value) => value == null
      ? _secure.delete(key: key)
      : _secure.write(key: key, value: value);
}

class MemorySettingsStore implements SettingsStore {
  final values = <String, String>{};
  final secrets = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
  @override
  Future<String?> readSecret(String key) async => secrets[key];
  @override
  Future<void> writeSecret(String key, String? value) async =>
      value == null ? secrets.remove(key) : secrets[key] = value;
}

/// Everything about which voice reads, shared by the reader and Settings.
class VoiceSettings extends ChangeNotifier {
  VoiceSettings({
    required this.store,
    http.Client Function()? client,
    this.checkTimeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client.new;

  final SettingsStore store;
  final http.Client Function() _client;
  final Duration checkTimeout;

  /// Remembering is offered where secure storage is real: not on web.
  static const canRemember = !kIsWeb;

  static const _modeKey = 'read_mode';
  static const _urlKey = 'kokoro_url';
  static const _voiceKey = 'kokoro_voice';
  static const _rememberKey = 'kokoro_remember';
  static const _tokenKey = 'kokoro_token';

  ReadMode _mode = ReadMode.auto;
  String _kokoroUrl = kokoroDefaultUrl;
  String _kokoroToken = '';
  String _kokoroVoice = kokoroDefaultVoice;
  bool _remember = false;
  List<String>? kokoroVoices;
  KokoroStatus _status = const KokoroStatus(KokoroState.unknown);
  String? deviceVoice;

  // Other API: kept in memory only, as before.
  SpeechPreset apiPreset = SpeechPreset.openai;
  String apiEndpoint = presetSettings(SpeechPreset.openai).endpoint;
  String apiKey = '';
  String apiModel = presetSettings(SpeechPreset.openai).model;
  String apiVoice = presetSettings(SpeechPreset.openai).voice;

  ReadMode get mode => _mode;
  String get kokoroUrl => _kokoroUrl;
  String get kokoroToken => _kokoroToken;
  String get kokoroVoice => _kokoroVoice;
  bool get rememberToken => _remember;
  String get kokoroEndpoint => kokoroSpeechEndpoint(_kokoroUrl);
  String get kokoroHost => Uri.tryParse(kokoroEndpoint)?.host ?? '';

  KokoroStatus get kokoroStatus {
    if (kokoroEndpoint.isEmpty) return const KokoroStatus(KokoroState.notSetUp);
    if (_kokoroToken.trim().isEmpty) {
      return const KokoroStatus(KokoroState.needsToken);
    }
    return _status;
  }

  /// Whether Kokoro or the device voice would read right now in [mode].
  bool get wouldUseKokoro => switch (_mode) {
    ReadMode.kokoro => true,
    ReadMode.auto => kokoroStatus.isAvailable,
    _ => false,
  };

  Future<void> load() async {
    try {
      final mode = await store.read(_modeKey);
      _mode = ReadMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ReadMode.auto,
      );
      _kokoroUrl = await store.read(_urlKey) ?? kokoroDefaultUrl;
      _kokoroVoice = await store.read(_voiceKey) ?? kokoroDefaultVoice;
      _remember = canRemember && await store.read(_rememberKey) == 'true';
      if (_remember) _kokoroToken = await store.readSecret(_tokenKey) ?? '';
    } catch (_) {
      // Unreadable storage: start from the defaults, as on a first launch.
    }
    notifyListeners();
    unawaited(loadDeviceVoice());
    if (_mode == ReadMode.auto || _mode == ReadMode.kokoro) {
      unawaited(checkKokoro());
    }
  }

  set mode(ReadMode value) {
    if (value == _mode) return;
    _mode = value;
    notifyListeners();
    unawaited(store.write(_modeKey, value.name));
    if (value == ReadMode.auto || value == ReadMode.kokoro) {
      unawaited(checkKokoro());
    }
  }

  set kokoroUrl(String value) {
    if (value == _kokoroUrl) return;
    _kokoroUrl = value.trim();
    _resetKokoro();
    unawaited(store.write(_urlKey, _kokoroUrl));
  }

  set kokoroToken(String value) {
    if (value == _kokoroToken) return;
    _kokoroToken = value.trim();
    _resetKokoro();
    if (_remember) {
      unawaited(
        store.writeSecret(
          _tokenKey,
          _kokoroToken.isEmpty ? null : _kokoroToken,
        ),
      );
    }
  }

  set kokoroVoice(String value) {
    if (value == _kokoroVoice) return;
    _kokoroVoice = value;
    notifyListeners();
    unawaited(store.write(_voiceKey, value));
  }

  set rememberToken(bool value) {
    if (!canRemember || value == _remember) return;
    _remember = value;
    notifyListeners();
    unawaited(store.write(_rememberKey, value ? 'true' : null));
    unawaited(
      store.writeSecret(
        _tokenKey,
        value && _kokoroToken.isNotEmpty ? _kokoroToken : null,
      ),
    );
  }

  void choosePreset(SpeechPreset preset) {
    apiPreset = preset;
    apiKey = '';
    if (preset != SpeechPreset.custom) {
      final s = presetSettings(preset);
      apiEndpoint = s.endpoint;
      apiModel = s.model;
      apiVoice = s.voice;
    }
    notifyListeners();
  }

  void updateApi({
    String? endpoint,
    String? key,
    String? model,
    String? voice,
  }) {
    apiEndpoint = endpoint ?? apiEndpoint;
    apiKey = key ?? apiKey;
    apiModel = model ?? apiModel;
    apiVoice = voice ?? apiVoice;
    notifyListeners();
  }

  void _resetKokoro() {
    _status = const KokoroStatus(KokoroState.unknown);
    kokoroVoices = null;
    notifyListeners();
  }

  /// Called when Kokoro stops answering mid-reading.
  void markKokoroOffline() {
    _status = KokoroStatus(KokoroState.offline, checkedAt: DateTime.now());
    notifyListeners();
  }

  Future<KokoroStatus>? _checking;

  /// Asks the server for its voice list. A result younger than [maxAge] is
  /// reused, so pressing Read aloud doesn't wait on a fresh check each time.
  Future<KokoroStatus> checkKokoro({
    Duration maxAge = const Duration(minutes: 1),
  }) {
    final current = kokoroStatus;
    if (current.state == KokoroState.notSetUp ||
        current.state == KokoroState.needsToken) {
      return Future.value(current);
    }
    final at = _status.checkedAt;
    if (at != null &&
        _status.state != KokoroState.checking &&
        DateTime.now().difference(at) < maxAge) {
      return Future.value(_status);
    }
    return _checking ??= _check().whenComplete(() => _checking = null);
  }

  Future<KokoroStatus> _check() async {
    final url = _kokoroUrl, token = _kokoroToken;
    _status = const KokoroStatus(KokoroState.checking);
    notifyListeners();
    final client = _client();
    KokoroStatus result;
    List<String>? voices;
    try {
      voices = await SpeechApi(
        client,
      ).voices(endpoint: kokoroEndpoint, apiKey: token).timeout(checkTimeout);
      result = KokoroStatus(
        KokoroState.available,
        voiceCount: voices.length,
        checkedAt: DateTime.now(),
      );
    } on SpeechException catch (e) {
      result = KokoroStatus(
        e.status == 401 || e.status == 403
            ? KokoroState.rejected
            : KokoroState.offline,
        checkedAt: DateTime.now(),
      );
    } catch (_) {
      result = KokoroStatus(KokoroState.offline, checkedAt: DateTime.now());
    } finally {
      client.close();
    }
    // Settings changed while checking: that answer is for something else.
    if (url != _kokoroUrl || token != _kokoroToken) return kokoroStatus;
    _status = result;
    if (voices != null) kokoroVoices = voices;
    notifyListeners();
    return result;
  }

  Future<void> loadDeviceVoice() async {
    try {
      // Only Android names its default voice. Browsers load their voice list
      // late, so an early empty list says nothing: a missing voice shows up
      // as an error when reading starts instead.
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
      final voice = await FlutterTts().getDefaultVoice;
      if (voice is Map) {
        final name = voice['name'], locale = voice['locale'];
        deviceVoice = [?name?.toString(), ?locale?.toString()].join(' · ');
        notifyListeners();
      }
    } catch (_) {
      // No plugin (tests) or an engine that won't say: keep "system default".
    }
  }
}
