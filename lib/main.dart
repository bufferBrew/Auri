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
import 'speech_api.dart';

void main() => runApp(const VoiceBrewApp());

class VoiceBrewApp extends StatelessWidget {
  const VoiceBrewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VoiceBrew',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: const ReaderScreen(),
  );
}

enum SpeechMode { device, api }

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _text = TextEditingController();
  final _title = TextEditingController(text: 'My reading');
  final _endpoint = TextEditingController(
    text: 'https://api.openai.com/v1/audio/speech',
  );
  final _key = TextEditingController();
  final _model = TextEditingController(text: 'tts-1');
  final _voice = TextEditingController(text: 'alloy');
  final _incoming = IncomingText();
  SpeechMode _mode = SpeechMode.device;
  FlutterTts? _tts;
  AudioPlayer? _audio;
  http.Client? _request;
  Uint8List? _mp3;
  bool _playing = false, _busy = false;
  double _speed = 1;
  int _offset = 0, _session = 0;
  String _status = 'Ready to read';
  bool _error = false;
  bool get _locked => _playing || _busy;

  void _message(String message, {bool error = false}) {
    if (mounted) {
      setState(() {
        _status = message;
        _error = error;
      });
    }
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
        if (reset) _offset = 0;
      });
    }
    await tts?.stop();
    await _audio?.pause();
    _message(reset ? 'Ready to read' : 'Paused');
  }

  Future<void> _readDevice() async {
    if (_text.text.trim().isEmpty) {
      _message('Paste or import some text first.');
      return;
    }
    final session = ++_session;
    final tts = FlutterTts();
    _tts = tts;
    setState(() {
      _playing = true;
      _error = false;
      _status = 'Reading with device TTS';
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
          'Device TTS is unavailable. Install a system voice or choose API voice.',
          error: true,
        );
      }
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
    });
    try {
      final bytes = await SpeechApi(client).generate(
        text: _text.text,
        endpoint: _endpoint.text,
        apiKey: _key.text,
        model: _model.text,
        voice: _voice.text,
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
      _message('Playing generated voice');
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

  @override
  void initState() {
    super.initState();
    _incoming.listen(_readIncoming);
  }

  /// Text selected in another app: load it and, with device voices, start
  /// reading right away. API voices wait for the user, since generating costs
  /// money and needs a key.
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
    if (_mode == SpeechMode.device) {
      await _readDevice();
    } else {
      _message('Text loaded — generate audio to listen');
    }
  }

  @override
  void dispose() {
    _incoming.dispose();
    _session++;
    _request?.close();
    _tts?.stop();
    _audio?.dispose();
    for (final c in [_text, _title, _endpoint, _key, _model, _voice]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('VoiceBrew')),
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
                DropdownButtonFormField<SpeechMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Speech engine'),
                  items: const [
                    DropdownMenuItem(
                      value: SpeechMode.device,
                      child: Text('Device TTS · default'),
                    ),
                    DropdownMenuItem(
                      value: SpeechMode.api,
                      child: Text('API voice · MP3 export'),
                    ),
                  ],
                  onChanged: _locked
                      ? null
                      : (value) {
                          setState(() {
                            _mode = value!;
                            _offset = 0;
                          });
                        },
                ),
                if (_mode == SpeechMode.api) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Generated voices are AI audio. Your text is sent to the endpoint below; provider charges may apply. Your key stays in memory until you close or reload this app.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _field(_endpoint, 'HTTPS speech endpoint'),
                  const SizedBox(height: AppSpacing.md),
                  _field(_key, 'API key', secret: true),
                  const SizedBox(height: AppSpacing.md),
                  _field(_model, 'Model'),
                  const SizedBox(height: AppSpacing.md),
                  _field(_voice, 'Voice'),
                  TextButton(
                    onPressed: _locked
                        ? null
                        : () {
                            _key.clear();
                            _invalidate();
                          },
                    child: const Text('Clear API key'),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Uses your system’s default voice and language. No API key needed. Offline availability depends on your installed voice.',
                  ),
                ],
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
                            _mp3 = null;
                          });
                        },
                ),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    if (_mode == SpeechMode.device)
                      FilledButton.icon(
                        onPressed: _locked ? null : _readDevice,
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
                      OutlinedButton.icon(
                        onPressed: _locked || _mp3 == null ? null : _export,
                        icon: const Icon(Icons.download),
                        label: const Text('Export MP3'),
                      ),
                    ],
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
                  'Documents and keys are not saved by VoiceBrew. Export your MP3 before closing.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
  }) => TextField(
    controller: controller,
    enabled: !_locked,
    obscureText: secret,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => _invalidate(),
  );
}
