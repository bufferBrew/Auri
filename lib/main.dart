import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'appearance_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/read_aloud/data/file_importer.dart';
import 'features/read_aloud/data/incoming_text.dart';
import 'features/read_aloud/domain/text_chunk.dart';
import 'features/read_aloud/domain/text_import.dart';
import 'mp3.dart';
import 'settings_screen.dart';
import 'speech_api.dart';
import 'speech_preset.dart';
import 'ui/player_bar.dart';
import 'ui/reading_view.dart';
import 'ui/voice_widgets.dart';
import 'voice_settings.dart';

void main() => runApp(const VoxenApp());

class VoxenApp extends StatefulWidget {
  const VoxenApp({super.key, this.settings, this.appearance});

  /// Injected by tests; the app makes its own on the device.
  final VoiceSettings? settings;
  final AppearanceSettings? appearance;

  @override
  State<VoxenApp> createState() => _VoxenAppState();
}

class _VoxenAppState extends State<VoxenApp> {
  late final _store = DeviceSettingsStore();
  late final VoiceSettings _settings =
      widget.settings ?? (VoiceSettings(store: _store)..load());
  late final AppearanceSettings _appearance =
      widget.appearance ?? (AppearanceSettings(store: _store)..load());

  @override
  void dispose() {
    if (widget.settings == null) _settings.dispose();
    if (widget.appearance == null) _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _appearance,
    builder: (context, _) => MaterialApp(
      title: 'Voxen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(_appearance.palette, Brightness.light),
      darkTheme: AppTheme.of(_appearance.palette, Brightness.dark),
      themeMode: _appearance.themeMode,
      home: ReaderScreen(settings: _settings, appearance: _appearance),
    ),
  );
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.settings, this.appearance});
  final VoiceSettings settings;
  final AppearanceSettings? appearance;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  VoiceSettings get s => widget.settings;
  final _text = TextEditingController();
  final _title = TextEditingController();
  final _incoming = IncomingText();

  /// Holds keyboard focus when no field does, so Ctrl/⌘+Enter always works.
  final _screenFocus = FocusNode(debugLabel: 'reader');
  FlutterTts? _tts;
  AudioPlayer? _audio;
  StreamSubscription<Duration>? _position;
  http.Client? _request;
  Uint8List? _mp3;
  bool _playing = false, _busy = false;
  double _speed = 1;
  int _offset = 0, _session = 0;

  /// The word being spoken, when the device voice reports it.
  BodySpan? _word;

  /// How far through a generated MP3 playback is (Other API).
  double _mp3Progress = 0;

  /// What's happening right now, shown under the voice while busy.
  String? _activity;

  /// A problem the user should read; warnings (offline) aren't errors.
  String? _notice;
  bool _noticeIsError = false;

  /// The voice reading now (or that read last), and why, if it's a fallback.
  VoiceSource? _source;
  String? _fallback;

  /// Kokoro audio already made this session, by voice and chunk text, so
  /// pausing and resuming doesn't synthesise the same chunk again.
  final _kokoroAudio = <String, Uint8List>{};

  bool get _locked => _playing || _busy;
  bool get _hasText => _text.text.trim().isNotEmpty;
  bool get _api => s.mode == ReadMode.api;
  bool get _showReader => _hasText && (_locked || _offset > 0);

  void _activityIs(String? text) {
    if (mounted) setState(() => _activity = text);
  }

  void _warn(String message, {bool error = false}) {
    if (mounted) {
      setState(() {
        _notice = message;
        _noticeIsError = error;
        _activity = null;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  VoiceSource get _kokoroSource => VoiceSource(
    Icons.graphic_eq_rounded,
    'Kokoro · ${s.kokoroVoice}',
    s.kokoroHost.isEmpty ? 'Your Kokoro server' : 'From ${s.kokoroHost}',
  );

  VoiceSource get _deviceSource => VoiceSource(
    Icons.phone_android_rounded,
    s.deviceVoice == null ? 'Device voice' : 'Device · ${s.deviceVoice}',
    kIsWeb ? 'From this browser' : 'From this device',
  );

  VoiceSource get _apiSource => VoiceSource(
    Icons.cloud_outlined,
    '${presetSettings(s.apiPreset).label} · ${s.apiVoice.isEmpty ? 'no voice set' : s.apiVoice}',
    'From ${Uri.tryParse(s.apiEndpoint)?.host.nonEmpty ?? 'an endpoint you set'}',
  );

  /// The voice the next Read aloud would use.
  VoiceSource get _nextSource => switch (s.mode) {
    ReadMode.device => _deviceSource,
    ReadMode.api => _apiSource,
    ReadMode.kokoro => _kokoroSource,
    ReadMode.auto => s.wouldUseKokoro ? _kokoroSource : _deviceSource,
  };

  double get _deviceRate =>
      (kIsWeb ? _speed : _speed * 0.5).clamp(0.1, kIsWeb ? 4.0 : 1.0);

  void _setSpeed(double value) {
    setState(() => _speed = value);
    // Applies at once to Kokoro and MP3s; the device voice from its next part.
    _audio?.setSpeed(value);
    _tts?.setSpeechRate(_deviceRate);
  }

  Future<void> _stop({bool reset = false}) async {
    _session++;
    _request?.close();
    _request = null;
    final tts = _tts;
    _tts = null;
    if (mounted) {
      setState(() {
        _playing = false;
        _busy = false;
        _activity = null;
        _word = null;
        if (reset) _offset = 0;
      });
    }
    await tts?.stop();
    await _audio?.pause();
  }

  void _togglePlay() {
    if (_locked) {
      _stop();
    } else if (_hasText) {
      _api ? _playApi() : _readAloud();
    }
  }

  /// Read aloud in the chosen mode. Automatic picks Kokoro when it answers,
  /// and the device voice when it doesn't.
  Future<void> _readAloud() async {
    if (!_hasText) return;
    _screenFocus.requestFocus();
    setState(() {
      _fallback = null;
      _notice = null;
    });
    if (s.mode == ReadMode.device) return _readDevice();
    setState(() => _busy = true);
    _activityIs('Checking Kokoro…');
    final status = await s.checkKokoro();
    if (!mounted) return;
    setState(() => _busy = false);
    if (status.isAvailable) return _readKokoro();
    if (s.mode == ReadMode.auto) {
      _fallback = 'Kokoro ${status.short.toLowerCase()}';
      return _readDevice();
    }
    _warn(
      'Kokoro can’t read right now: ${status.label}',
      error: status.state == KokoroState.rejected,
    );
  }

  Future<void> _readDevice() async {
    final session = ++_session;
    final tts = FlutterTts();
    _tts = tts;
    setState(() {
      _playing = true;
      _source = _deviceSource;
      _activity = null;
    });
    try {
      await tts.awaitSpeakCompletion(true);
      await tts.setSpeechRate(_deviceRate);
      // A fresh engine per session binds late callbacks to their original run.
      if (!mounted || session != _session) return;
      var from = _offset.clamp(0, _text.text.length);
      for (final chunk in chunkText(_text.text.substring(from))) {
        if (!mounted || session != _session) return;
        final start = from + chunk.start;
        setState(() => _offset = start);
        tts.setProgressHandler((
          String _,
          int wordStart,
          int wordEnd,
          String word,
        ) {
          if (mounted && session == _session) {
            setState(() {
              _offset = start + wordStart;
              _word = BodySpan(start + wordStart, start + wordEnd);
            });
          }
        });
        final result = await tts.speak(chunk.text);
        if (!mounted || session != _session) return;
        if (result == 0) {
          throw const SpeechException(
            'Device speech could not start. Install a system voice or try another browser.',
          );
        }
        _offset = from + chunk.end;
      }
      if (mounted && session == _session) {
        setState(() {
          _playing = false;
          _offset = 0;
          _word = null;
        });
        _toast('Finished reading');
      }
    } catch (_) {
      if (mounted && session == _session) {
        setState(() {
          _playing = false;
          _word = null;
        });
        _warn(
          'The device voice is unavailable. Install a system voice, or pick another voice.',
          error: true,
        );
      }
    }
  }

  /// Kokoro, chunk by chunk: the next chunk is made while this one plays.
  /// A whole reading from the start also becomes an MP3 you can export.
  Future<void> _readKokoro() async {
    final session = ++_session;
    final client = http.Client();
    _request = client;
    final api = SpeechApi(client);
    final from = _offset.clamp(0, _text.text.length);
    final chunks = chunkText(_text.text.substring(from));
    if (chunks.isEmpty) {
      client.close();
      setState(() => _offset = 0);
      return;
    }
    final voice = s.kokoroVoice;
    final parts = <Uint8List>[];
    setState(() {
      _playing = true;
      _busy = true;
      _source = _kokoroSource;
      _word = null;
    });
    _activityIs('Getting Kokoro audio…');

    Future<Uint8List> fetch(TextChunk chunk) {
      final key = '$voice\n${chunk.text}';
      final cached = _kokoroAudio[key];
      if (cached != null) return Future.value(cached);
      final future = api
          .generate(
            text: chunk.text,
            endpoint: s.kokoroEndpoint,
            apiKey: s.kokoroToken,
            model: kokoroModel,
            voice: voice,
          )
          .then((bytes) => _kokoroAudio[key] = bytes);
      // A paused reading never awaits its prefetch; don't let that fail loudly.
      future.ignore();
      return future;
    }

    try {
      await _audio?.dispose();
      final player = AudioPlayer();
      _audio = player;
      var next = fetch(chunks.first);
      for (var i = 0; i < chunks.length; i++) {
        final bytes = await next;
        if (!mounted || session != _session) return;
        if (i + 1 < chunks.length) next = fetch(chunks[i + 1]);
        parts.add(bytes);
        setState(() {
          _offset = from + chunks[i].start;
          _busy = false;
          _activity = null;
        });
        await player.setUrl(
          Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg').toString(),
        );
        await player.setSpeed(_speed);
        if (!mounted || session != _session) return;
        await player.play();
        if (!mounted || session != _session) return;
        _offset = from + chunks[i].end;
      }
      if (mounted && session == _session) {
        setState(() {
          _playing = false;
          _offset = 0;
          if (from == 0) _mp3 = concatMp3(parts);
        });
        _toast(
          from == 0
              ? 'Finished · the MP3 is ready to export'
              : 'Finished reading',
        );
      }
    } catch (e) {
      if (!mounted || session != _session) return;
      setState(() {
        _playing = false;
        _busy = false;
      });
      final rejected =
          e is SpeechException && (e.status == 401 || e.status == 403);
      if (rejected) {
        _warn('Kokoro rejected the token. Check it in Settings.', error: true);
        return;
      }
      s.markKokoroOffline();
      if (s.mode == ReadMode.auto) {
        _fallback = 'Kokoro stopped answering';
        await _readDevice();
      } else {
        _warn(
          'Can’t reach Kokoro. Check the Mac is awake and online'
          '${kIsWeb ? ', and that the server allows CORS' : ''}.',
        );
      }
    } finally {
      client.close();
      if (_request == client) _request = null;
    }
  }

  /// Other API: generate the MP3 if there isn't one, then play it.
  Future<void> _playApi() async {
    _screenFocus.requestFocus();
    setState(() {
      _notice = null;
      _fallback = null;
    });
    if (_mp3 == null) await _generate();
    if (_mp3 != null && mounted) await _playMp3();
  }

  Future<void> _generate() async {
    final session = ++_session;
    final client = http.Client();
    _request = client;
    setState(() {
      _busy = true;
      _mp3 = null;
      _source = _apiSource;
    });
    _activityIs('Generating audio…');
    try {
      final bytes = await SpeechApi(client).generate(
        text: _text.text,
        endpoint: s.apiEndpoint,
        apiKey: s.apiKey,
        model: s.apiModel,
        voice: s.apiVoice,
        onProgress: (done, total) {
          if (session == _session && total > 1) {
            _activityIs('Generating audio · part ${done + 1} of $total');
          }
        },
      );
      if (!mounted || session != _session) return;
      setState(() => _mp3 = bytes);
    } on SpeechException catch (e) {
      if (session == _session) _warn(e.message, error: e.status != null);
    } catch (_) {
      if (session == _session) {
        _warn(
          'Can’t reach the speech provider. Check your connection and endpoint'
          '${kIsWeb ? '; web providers must allow CORS' : ''}.',
        );
      }
    } finally {
      client.close();
      if (mounted && session == _session) {
        setState(() {
          _busy = false;
          _request = null;
          _activity = null;
        });
      }
    }
  }

  Future<void> _playMp3() async {
    final session = ++_session;
    setState(() {
      _playing = true;
      _mp3Progress = 0;
    });
    try {
      await _position?.cancel();
      await _audio?.dispose();
      if (!mounted || session != _session) return;
      final player = AudioPlayer();
      _audio = player;
      final total = await player.setUrl(
        Uri.dataFromBytes(_mp3!, mimeType: 'audio/mpeg').toString(),
      );
      await player.setSpeed(_speed);
      _position = player.positionStream.listen((p) {
        final ms = total?.inMilliseconds ?? 0;
        if (mounted && ms > 0) {
          setState(() => _mp3Progress = (p.inMilliseconds / ms).clamp(0, 1));
        }
      });
      if (!mounted || session != _session) return;
      await player.play();
      if (mounted && session == _session) {
        setState(() => _playing = false);
        _toast('Finished playing');
      }
    } catch (_) {
      if (mounted && session == _session) {
        setState(() => _playing = false);
        _warn(
          'Audio playback failed. You can still export the MP3.',
          error: true,
        );
      }
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      _toast('The clipboard has no text');
      return;
    }
    setState(() {
      _text.text = text;
      _offset = 0;
      _mp3 = null;
    });
  }

  Future<void> _import() async {
    if (_locked) await _stop();
    setState(() => _busy = true);
    _activityIs('Opening the document…');
    try {
      final file = await const FileImporter().pick();
      if (file == null || !mounted) return;
      if (file.text.body.trim().isEmpty) {
        throw const ImportException('This file contains no readable text.');
      }
      setState(() {
        _title.text = file.text.title;
        _text.text = file.text.body;
        _offset = 0;
        _mp3 = null;
        _notice = null;
      });
      _toast('Imported ${file.text.title}');
    } on ImportException catch (e) {
      _warn(e.message, error: true);
    } catch (_) {
      _warn(
        'This file could not be read. Try a TXT, Markdown, PDF, or EPUB file.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = null;
        });
      }
    }
  }

  Future<void> _export() async {
    try {
      final saved = await FilePicker.saveFile(
        fileName: mp3FileName(
          _title.text.trim().isEmpty ? 'Voxen' : _title.text,
        ),
        bytes: _mp3!,
        mimeType: 'audio/mpeg',
      );
      if (saved != null) _toast('MP3 exported');
    } catch (_) {
      _warn('The MP3 could not be saved. Try again.', error: true);
    }
  }

  void _invalidate() => setState(() {
    _mp3 = null;
    _offset = 0;
    _word = null;
  });

  void _clear() {
    _text.clear();
    _title.clear();
    _invalidate();
  }

  ReadMode? _lastMode;

  void _settingsChanged() {
    if (!mounted) return;
    setState(() {
      // A different mode starts the reading over.
      if (_lastMode != null && _lastMode != s.mode) {
        _offset = 0;
        _mp3 = null;
        _notice = null;
        _fallback = null;
      }
      _lastMode = s.mode;
    });
  }

  Future<void> _openSettings() async {
    if (_locked) await _stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SettingsScreen(settings: s, appearance: widget.appearance),
      ),
    );
  }

  Future<void> _openVoiceSheet() async {
    if (_locked) await _stop();
    if (!mounted) return;
    s.checkKokoro();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text('Voice', style: context.typography.title),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReadModePicker(settings: s),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      _openSettings();
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Voice settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _lastText = '';
  void _textChanged() {
    if (_text.text == _lastText) return;
    _lastText = _text.text;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _lastMode = s.mode;
    s.addListener(_settingsChanged);
    _text.addListener(_textChanged);
    _incoming.listen(_readIncoming);
  }

  /// Text selected in another app: load it and start reading right away,
  /// except with Other API, which costs money and waits for you.
  Future<void> _readIncoming(String text) async {
    if (!mounted) return;
    await _stop(reset: true);
    if (!mounted) return;
    setState(() {
      _title.text = 'Selected text';
      _text.text = text.trim();
      _offset = 0;
      _mp3 = null;
    });
    if (!_api) await _readAloud();
  }

  @override
  void dispose() {
    s.removeListener(_settingsChanged);
    _incoming.dispose();
    _session++;
    _request?.close();
    _tts?.stop();
    _position?.cancel();
    _audio?.dispose();
    _text.dispose();
    _title.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  String get _subtitle {
    if (_activity != null) return _activity!;
    final source = _locked && _source != null ? _source! : _nextSource;
    return _fallback == null ? source.origin : '${source.origin} · $_fallback';
  }

  String? get _readerStatus {
    final length = _text.text.length;
    if (_api) return _playing ? 'Playing the MP3' : null;
    if (length == 0) return null;
    final pct = (_offset / length * 100).clamp(0, 100).round();
    return _playing ? 'Reading · $pct%' : 'Paused · $pct%';
  }

  @override
  Widget build(BuildContext context) {
    final source = _locked && _source != null ? _source! : _nextSource;
    final length = _text.text.length;
    final progress = _api
        ? _mp3Progress
        : length == 0
        ? 0.0
        : (_offset / length).clamp(0.0, 1.0);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _togglePlay,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            _togglePlay,
      },
      child: Focus(
        focusNode: _screenFocus,
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: AppSpacing.lg,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.smAll,
                  child: Image.asset(
                    'assets/branding/logo.png',
                    width: 28,
                    height: 28,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                const Text('Voxen'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Import document',
                onPressed: _locked ? null : _import,
                icon: const Icon(Icons.file_open_outlined),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final gutter = AppSpacing.gutter(box.maxWidth);
                    final padding = EdgeInsets.fromLTRB(
                      gutter,
                      AppSpacing.md,
                      gutter,
                      AppSpacing.lg,
                    );
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: AppBreakpoints.readingMaxWidth + 2 * gutter,
                        ),
                        child: AnimatedSwitcher(
                          duration: AppMotion.of(context, AppMotion.fast),
                          child: _showReader
                              ? ReadingView(
                                  key: const ValueKey('reader'),
                                  title: _title.text,
                                  text: _text.text,
                                  offset: _offset,
                                  word: _word,
                                  highlight: !_api,
                                  status: _readerStatus,
                                  onEdit: _locked
                                      ? null
                                      : () => _stop(reset: true),
                                  padding: padding,
                                )
                              : _Editor(
                                  key: const ValueKey('editor'),
                                  title: _title,
                                  text: _text,
                                  enabled: !_locked,
                                  padding: padding,
                                  onPaste: _paste,
                                  onImport: _import,
                                  onChanged: _invalidate,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_notice != null)
                NoticeBanner(
                  message: _notice!,
                  error: _noticeIsError,
                  onDismiss: () => setState(() => _notice = null),
                ),
              PlayerBar(
                source: source,
                subtitle: _subtitle,
                progress: progress,
                playing: _playing,
                busy: _busy,
                playTooltip: _api
                    ? (_mp3 == null ? 'Generate and play' : 'Play')
                    : (_offset > 0 ? 'Resume' : 'Read aloud'),
                onPlay: _hasText ? _togglePlay : null,
                onPause: () => _stop(),
                speed: _speed,
                onSpeed: _setSpeed,
                onVoiceTap: _openVoiceSheet,
                actions: [
                  PlayerAction(
                    'Export MP3',
                    Icons.download_rounded,
                    _mp3 == null || _locked ? null : _export,
                  ),
                  PlayerAction(
                    'Start over',
                    Icons.replay_rounded,
                    _offset > 0 && !_locked ? () => _stop(reset: true) : null,
                  ),
                  PlayerAction(
                    'Clear text',
                    Icons.delete_outline_rounded,
                    _hasText && !_locked ? _clear : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Writing surface: a title, the text, and — while empty — the two ways in.
class _Editor extends StatelessWidget {
  const _Editor({
    super.key,
    required this.title,
    required this.text,
    required this.enabled,
    required this.padding,
    required this.onPaste,
    required this.onImport,
    required this.onChanged,
  });

  final TextEditingController title;
  final TextEditingController text;
  final bool enabled;
  final EdgeInsets padding;
  final VoidCallback onPaste;
  final VoidCallback onImport;
  final VoidCallback onChanged;

  static const _plain = InputDecoration(
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    isCollapsed: true,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;
    final words = RegExp(r'\S+').allMatches(text.text).length;
    final minutes = (words / 170).ceil();
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: title,
            enabled: enabled,
            style: t.headline,
            textInputAction: TextInputAction.next,
            decoration: _plain.copyWith(
              hintText: 'Untitled',
              hintStyle: t.headline.copyWith(color: c.textTertiary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            words == 0
                ? 'Paste or write something, then press play.'
                : '$words ${words == 1 ? 'word' : 'words'} · about $minutes min to listen',
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          if (words == 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: enabled ? onPaste : null,
                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                  label: const Text('Paste'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onImport : null,
                  icon: const Icon(Icons.file_open_outlined, size: 18),
                  label: const Text('Import document'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'TXT, Markdown, PDF with text or EPUB',
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: TextField(
              controller: text,
              enabled: enabled,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: t.reading,
              decoration: _plain.copyWith(
                hintText: 'Text to read',
                hintStyle: t.reading.copyWith(color: c.textTertiary),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
