import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'speech_preset.dart';
import 'voice_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final VoiceSettings settings;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  VoiceSettings get s => widget.settings;
  late final _url = TextEditingController(text: s.kokoroUrl);
  late final _token = TextEditingController(text: s.kokoroToken);
  late final _endpoint = TextEditingController(text: s.apiEndpoint);
  late final _key = TextEditingController(text: s.apiKey);
  late final _model = TextEditingController(text: s.apiModel);
  late final _voice = TextEditingController(text: s.apiVoice);

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
    s.checkKokoro();
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    s.removeListener(_changed);
    for (final c in [_url, _token, _endpoint, _key, _model, _voice]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncApiFields() {
    _endpoint.text = s.apiEndpoint;
    _key.text = s.apiKey;
    _model.text = s.apiModel;
    _voice.text = s.apiVoice;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kokoro = s.kokoroStatus;
    final device = 'Available · ${s.deviceVoice ?? 'system default voice'}';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text('Reading mode', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                RadioGroup<ReadMode>(
                  groupValue: s.mode,
                  onChanged: (m) => s.mode = m!,
                  child: Column(
                    children: [
                      _mode(
                        ReadMode.auto,
                        'Kokoro when it’s available, otherwise the device voice. '
                        'Right now: ${s.wouldUseKokoro ? 'Kokoro' : 'device voice'}.',
                      ),
                      _mode(ReadMode.kokoro, 'Kokoro · ${kokoro.label}'),
                      _mode(ReadMode.device, 'This device · $device'),
                      _mode(
                        ReadMode.api,
                        'OpenAI or your own endpoint · '
                        '${s.apiKey.isEmpty ? 'needs a key' : 'key entered'}',
                      ),
                    ],
                  ),
                ),
                const Divider(height: AppSpacing.xxl),
                Text('Kokoro', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Your own Kokoro voice server, the one Synapse reads aloud with. '
                  'No provider charges.',
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'In a browser, Kokoro also needs the server to allow CORS. '
                    'The Android app doesn’t.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _StatusDot(kokoro.state),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(kokoro.label),
                      ),
                    ),
                    TextButton(
                      onPressed: kokoro.state == KokoroState.checking
                          ? null
                          : () => s.checkKokoro(maxAge: Duration.zero),
                      child: const Text('Check now'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'https://<your-server>',
                  ),
                  onChanged: (v) => s.kokoroUrl = v,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _token,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Kokoro token'),
                  onChanged: (v) => s.kokoroToken = v,
                  onSubmitted: (_) => s.checkKokoro(maxAge: Duration.zero),
                ),
                if (VoiceSettings.canRemember)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remember token on this device'),
                    subtitle: const Text(
                      'Kept in Android’s encrypted storage. Off: forgotten when you close Voxen.',
                    ),
                    value: s.rememberToken,
                    onChanged: (v) => s.rememberToken = v,
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (s.kokoroVoices case final voices? when voices.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey(voices),
                    initialValue: voices.contains(s.kokoroVoice)
                        ? s.kokoroVoice
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kokoro voice',
                    ),
                    items: [
                      for (final v in voices)
                        DropdownMenuItem(value: v, child: Text(v)),
                    ],
                    onChanged: (v) => s.kokoroVoice = v!,
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Kokoro voice',
                    ),
                    child: Text(
                      '${s.kokoroVoice} · the full list appears once Kokoro is available',
                    ),
                  ),
                const Divider(height: AppSpacing.xxl),
                Text('Other API', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Makes an MP3 you can export. Your text goes to the endpoint below, '
                  'and provider charges may apply. The key stays in memory only.',
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<SpeechPreset>(
                  initialValue: s.apiPreset,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: [
                    for (final p in SpeechPreset.values)
                      DropdownMenuItem(
                        value: p,
                        child: Text(presetSettings(p).label),
                      ),
                  ],
                  onChanged: (p) {
                    s.choosePreset(p!);
                    _syncApiFields();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _endpoint,
                  'HTTPS speech endpoint',
                  (v) => s.updateApi(endpoint: v),
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _key,
                  'API key',
                  (v) => s.updateApi(key: v),
                  secret: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(_model, 'Model', (v) => s.updateApi(model: v)),
                const SizedBox(height: AppSpacing.md),
                _field(_voice, 'Voice', (v) => s.updateApi(voice: v)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      _key.clear();
                      s.updateApi(key: '');
                    },
                    child: const Text('Clear API key'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mode(ReadMode mode, String subtitle) => RadioListTile<ReadMode>(
    value: mode,
    contentPadding: EdgeInsets.zero,
    title: Text(mode.label),
    subtitle: Text(subtitle),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    ValueChanged<String> onChanged, {
    bool secret = false,
  }) => TextField(
    controller: controller,
    obscureText: secret,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(labelText: label),
    onChanged: onChanged,
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.state);
  final KokoroState state;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (state == KokoroState.checking) {
      return const SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final color = switch (state) {
      KokoroState.available => Colors.green.shade600,
      KokoroState.offline || KokoroState.rejected => scheme.error,
      _ => scheme.outline,
    };
    return Icon(Icons.circle, size: 12, color: color);
  }
}
