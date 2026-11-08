import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'core/theme/app_theme.dart';
import 'features/read_aloud/data/file_importer.dart';
import 'features/read_aloud/data/incoming_text.dart';
import 'features/read_aloud/domain/text_chunk.dart';
import 'features/read_aloud/domain/text_import.dart';
import 'mp3.dart';
import 'settings_screen.dart';
import 'speech_api.dart';
import 'speech_preset.dart';
import 'voice_settings.dart';

void main() => runApp(const VoxenApp());

class VoxenApp extends StatefulWidget {
  const VoxenApp({super.key, this.settings});

  /// Injected by tests; the app makes its own on the device.
  final VoiceSettings? settings;

  @override
  State<VoxenApp> createState() => _VoxenAppState();
}

class _VoxenAppState extends State<VoxenApp> {
  late final VoiceSettings _settings =
      widget.settings ?? (VoiceSettings(store: DeviceSettingsStore())..load());

  @override
  void dispose() {
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Voxen',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: ReaderScreen(settings: _settings),
  );
}

/// What is reading, and where its voice comes from.
@immutable
class VoiceSource {
  const VoiceSource(this.icon, this.title, this.origin);
  final IconData icon;
  final String title;
  final String origin;
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.settings});
  final VoiceSettings settings;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  VoiceSettings get s => widget.settings;
  final _text = TextEditingController();
  final _title = TextEditingController(text: 'My reading');
  final _incoming = IncomingText();
  FlutterTts? _tts;
  AudioPlayer? _audio;
  http.Client? _request;
  Uint8List? _mp3;
  bool _playing = false, _busy = false;
  double _speed = 1;
  int _offset = 0, _session = 0;
  String _status = 'Ready to read';
  bool _error = false;

  /// The voice reading now (or that read last), and why, when it's a fallback.
  VoiceSource? _source;
  String? _fallback;

  /// Kokoro audio already made this session, by voice and chunk text, so
  /// pausing and resuming doesn't synthesise the same chunk again.
  final _kokoroAudio = <String, Uint8List>{};

  bool get _locked => _playing || _busy;

  void _message(String message, {bool error = false}) {
    if (mounted) {
      setState(() {
        _status = message;
        _error = error;
      });
    }
  }

  VoiceSource get _kokoroSource => VoiceSource(
    Icons.graphic_eq,
    'Kokoro · ${s.kokoroVoice}',
    'From your Kokoro server${s.kokoroHost.isEmpty ? '' : ', ${s.kokoroHost}'}',
  );

  VoiceSource get _deviceSource => VoiceSource(
    Icons.phone_android,
    'Device voice · ${s.deviceVoice ?? 'system default'}',
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
        if (reset) _offset = 0;
      });
    }
    await tts?.stop();
    await _audio?.pause();
    _message(reset ? 'Ready to read' : 'Paused');
  }

  /// Read aloud in the chosen mode. Automatic picks Kokoro when it answers,
  /// and the device voice when it doesn't.
  Future<void> _readAloud() async {
    if (_text.text.trim().isEmpty) {
      _message('Paste or import some text first.');
      return;
    }
    _fallback = null;
    if (s.mode == ReadMode.device) return _readDevice();
    setState(() => _busy = true);
    _message('Checking Kokoro…');
    final status = await s.checkKokoro();
    if (!mounted) return;
    setState(() => _busy = false);
    if (status.isAvailable) return _readKokoro();
    if (s.mode == ReadMode.auto) {
      _fallback =
          'Kokoro isn’t available (${status.label}). Using the device voice.';
      return _readDevice();
    }
    _message('Kokoro can’t read now: ${status.label}', error: true);
  }

  Future<void> _readDevice() async {
    final session = ++_session;
    final tts = FlutterTts();
    _tts = tts;
    setState(() {
      _playing = true;
      _error = false;
      _source = _deviceSource;
      _status = 'Reading with the device voice';
    });
    try {
      await tts.awaitSpeakCompletion(true);
      await tts.setSpeechRate(
        (kIsWeb ? _speed : _speed * 0.5).clamp(0.1, kIsWeb ? 4.0 : 1.0),
      );
      // A fresh engine per session binds late callbacks to their original run.
      if (!mounted || session != _session) return;
      var from = _offset.clamp(0, _text.text.length);
      for (final chunk in chunkText(_text.text.substring(from))) {
        if (!mounted || session != _session) return;
        final start = from + chunk.start;
        tts.setProgressHandler((
          String _,
          int wordStart,
          int wordEnd,
          String word,
        ) {
          if (mounted && session == _session) {
            setState(() {
              _offset = start + wordStart;
              _status = 'Reading: $word';
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
        });
        _message('Finished reading');
      }
    } catch (_) {
      if (mounted && session == _session) {
        setState(() => _playing = false);
        _message(
          'The device voice is unavailable. Install a system voice, or pick another mode in Settings.',
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
      _message('Finished reading');
      return;
    }
    final voice = s.kokoroVoice;
    final parts = <Uint8List>[];
    setState(() {
      _playing = true;
      _error = false;
      _source = _kokoroSource;
      _status = 'Getting Kokoro audio…';
    });

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
        setState(() => _offset = from + chunks[i].start);
        _message(
          chunks.length == 1
              ? 'Reading with Kokoro'
              : 'Reading with Kokoro: part ${i + 1} of ${chunks.length}',
        );
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
        _message(
          from == 0
              ? 'Finished reading · MP3 ready to export'
              : 'Finished reading',
        );
      }
    } catch (e) {
      if (!mounted || session != _session) return;
      setState(() => _playing = false);
      final rejected =
          e is SpeechException && (e.status == 401 || e.status == 403);
      if (rejected) {
        _message(
          'Kokoro rejected the token. Check it in Settings.',
          error: true,
        );
        return;
      }
      s.markKokoroOffline();
      if (s.mode == ReadMode.auto) {
        _fallback =
            'Kokoro stopped answering. Carrying on with the device voice.';
        await _readDevice();
      } else {
        _message(
          'Could not reach Kokoro. Check the Mac is awake and online'
          '${kIsWeb ? ', and that the server allows CORS' : ''}.',
          error: true,
        );
      }
    } finally {
      client.close();
      if (_request == client) _request = null;
    }
  }

  Future<void> _generate() async {
    final session = ++_session;
    final client = http.Client();
    _request = client;
    setState(() {
      _busy = true;
      _mp3 = null;
      _error = false;
      _fallback = null;
      _source = _apiSource;
    });
    try {
      final bytes = await SpeechApi(client).generate(
        text: _text.text,
        endpoint: s.apiEndpoint,
        apiKey: s.apiKey,
        model: s.apiModel,
        voice: s.apiVoice,
        speed: _speed,
        onProgress: (done, total) {
          if (session == _session) {
            _message('Generating audio: $done of $total parts');
          }
        },
      );
      if (!mounted || session != _session) return;
      setState(() => _mp3 = bytes);
      _message('MP3 ready — play or export it below');
    } on SpeechException catch (e) {
      if (session == _session) _message(e.message, error: true);
    } catch (_) {
      if (session == _session) {
        _message(
          'Could not reach the speech provider. Check your connection and endpoint; web providers must allow CORS.',
          error: true,
        );
      }
    } finally {
      client.close();
      if (mounted && session == _session) {
        setState(() {
          _busy = false;
          _request = null;
        });
      }
    }
  }

  Future<void> _playMp3() async {
    final session = ++_session;
    setState(() {
      _playing = true;
      _error = false;
    });
    try {
      await _audio?.dispose();
      if (!mounted || session != _session) return;
      final player = AudioPlayer();
      _audio = player;
      await player.setUrl(
        Uri.dataFromBytes(_mp3!, mimeType: 'audio/mpeg').toString(),
      );
      if (!mounted || session != _session) return;
      _message('Playing the MP3');
      await player.play();
      if (mounted && session == _session) {
        setState(() => _playing = false);
        _message('Playback finished');
      }
    } catch (_) {
      if (mounted && session == _session) {
        setState(() => _playing = false);
        _message(
          'Audio playback failed. You can still export the MP3.',
          error: true,
        );
      }
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
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
      });
      _message('Imported ${file.text.title}');
    } on ImportException catch (e) {
      _message(e.message, error: true);
    } catch (_) {
      _message(
        'This file could not be read. Try a TXT, Markdown, PDF, or EPUB file.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    try {
      final saved = await FilePicker.saveFile(
        fileName: mp3FileName(_title.text),
        bytes: _mp3!,
        mimeType: 'audio/mpeg',
      );
      if (saved != null) _message('MP3 exported');
    } catch (_) {
      _message('The MP3 could not be saved. Try again.', error: true);
    }
  }

  void _invalidate() => setState(() {
    _mp3 = null;
    _offset = 0;
  });

  ReadMode? _lastMode;

  void _settingsChanged() {
    if (!mounted) return;
    setState(() {
      // A different mode starts the reading over.
      if (_lastMode != null && _lastMode != s.mode) {
        _offset = 0;
        _mp3 = null;
      }
      _lastMode = s.mode;
    });
  }

  Future<void> _openSettings() async {
    if (_locked) await _stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: s)),
    );
  }

  @override
  void initState() {
    super.initState();
    _lastMode = s.mode;
    s.addListener(_settingsChanged);
    _incoming.listen(_readIncoming);
  }

  /// Text selected in another app: load it and start reading right away,
  /// except with Other API, which costs money and waits for Generate.
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
    if (s.mode == ReadMode.api) {
      _message('Text loaded — generate audio to listen');
    } else {
      await _readAloud();
    }
  }

  @override
  void dispose() {
    s.removeListener(_settingsChanged);
    _incoming.dispose();
    _session++;
    _request?.close();
    _tts?.stop();
    _audio?.dispose();
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = s.mode == ReadMode.api;
    final source = _locked && _source != null ? _source! : _nextSource;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voxen'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  'Give your words a voice.',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Paste text or bring a document. Listen at your own pace.',
                ),
                const SizedBox(height: AppSpacing.xl),
                _SourceCard(
                  heading: _playing
                      ? 'Reading with'
                      : _busy
                      ? 'Getting ready'
                      : 'Will read with',
                  source: source,
                  mode: s.mode,
                  note: _fallback,
                  onChange: _locked ? null : _openSettings,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _title,
                  enabled: !_locked,
                  decoration: const InputDecoration(labelText: 'Reading title'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _text,
                  enabled: !_locked,
                  minLines: 8,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: 'Text to read',
                    hintText: 'Paste your article, notes, or story…',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => _invalidate(),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _locked ? null : _import,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import document'),
                    ),
                    TextButton(
                      onPressed: _locked
                          ? null
                          : () {
                              _text.clear();
                              _invalidate();
                            },
                      child: const Text('Clear text'),
                    ),
                  ],
                ),
                const Text('TXT · Markdown · PDF with text · EPUB'),
                const SizedBox(height: AppSpacing.lg),
                Text('Speed: ${_speed.toStringAsFixed(2)}×'),
                Slider(
                  value: _speed,
                  min: 0.5,
                  max: 2,
                  divisions: 6,
                  label: '${_speed.toStringAsFixed(2)}×',
                  onChanged: _locked
                      ? null
                      : (v) {
                          setState(() {
                            _speed = v;
                            if (api) _mp3 = null;
                          });
                        },
                ),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    if (!api)
                      FilledButton.icon(
                        onPressed: _locked ? null : _readAloud,
                        icon: const Icon(Icons.volume_up),
                        label: Text(
                          _offset > 0 ? 'Resume reading' : 'Read aloud',
                        ),
                      )
                    else ...[
                      FilledButton.icon(
                        onPressed: _locked ? null : _generate,
                        icon: const Icon(Icons.graphic_eq),
                        label: const Text('Generate MP3'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _locked || _mp3 == null ? null : _playMp3,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play MP3'),
                      ),
                    ],
                    if (api || _mp3 != null)
                      OutlinedButton.icon(
                        onPressed: _locked || _mp3 == null ? null : _export,
                        icon: const Icon(Icons.download),
                        label: const Text('Export MP3'),
                      ),
                    if (_playing || (_busy && _request != null))
                      OutlinedButton(
                        onPressed: () => _stop(),
                        child: Text(_busy ? 'Cancel' : 'Pause'),
                      ),
                    if (_offset > 0 && !_locked)
                      TextButton(
                        onPressed: () => _stop(reset: true),
                        child: const Text('Start over'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _status,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _error ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'Documents and audio are not saved by Voxen. Export your MP3 before closing.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.heading,
    required this.source,
    required this.mode,
    required this.onChange,
    this.note,
  });
  final String heading;
  final VoiceSource source;
  final ReadMode mode;
  final String? note;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$heading · ${mode.label}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  TextButton(onPressed: onChange, child: const Text('Change')),
                ],
              ),
              Row(
                children: [
                  Icon(source.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(source.title, style: theme.textTheme.titleMedium),
                        Text(source.origin, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(note!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
