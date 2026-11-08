import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'appearance_settings.dart';
import 'core/theme/app_theme.dart';
import 'speech_preset.dart';
import 'ui/voice_widgets.dart';
import 'voice_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, this.appearance});
  final VoiceSettings settings;
  final AppearanceSettings? appearance;
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
    widget.appearance?.addListener(_changed);
    s.checkKokoro();
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    s.removeListener(_changed);
    widget.appearance?.removeListener(_changed);
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
    final c = context.colors;
    final t = context.typography;
    final kokoro = s.kokoroStatus;
    final appearance = widget.appearance;
    final note = t.bodySmall.copyWith(color: c.textSecondary);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: LayoutBuilder(
        builder: (context, box) {
          final gutter = AppSpacing.gutter(box.maxWidth);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpacing.sm,
              gutter,
              AppSpacing.xxxl,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.readingMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (appearance != null)
                        _Section(
                          title: 'Appearance',
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SegmentedButton<ThemeMode>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      icon: Icon(
                                        Icons.brightness_auto_outlined,
                                      ),
                                      label: Text('System'),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      icon: Icon(Icons.light_mode_outlined),
                                      label: Text('Light'),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      icon: Icon(Icons.dark_mode_outlined),
                                      label: Text('Dark'),
                                    ),
                                  ],
                                  selected: {appearance.themeMode},
                                  onSelectionChanged: (v) =>
                                      appearance.themeMode = v.single,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'Colour',
                                  style: t.label.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    for (final p in AppPalette.values)
                                      _Swatch(
                                        palette: p,
                                        selected: p == appearance.palette,
                                        onTap: () => appearance.palette = p,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      _Section(
                        title: 'Voice',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: ReadModePicker(settings: s),
                        ),
                      ),
                      _Section(
                        title: 'Kokoro',
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Your own Kokoro voice server, the one Synapse reads aloud with. No provider charges.',
                                style: note,
                              ),
                              if (kIsWeb) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'In a browser, Kokoro also needs the server to allow CORS. The Android app doesn’t.',
                                  style: note,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: kokoro.pill,
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        kokoro.state == KokoroState.checking
                                        ? null
                                        : () => s.checkKokoro(
                                            maxAge: Duration.zero,
                                          ),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Check now'),
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
                                  prefixIcon: Icon(Icons.dns_outlined),
                                ),
                                onChanged: (v) => s.kokoroUrl = v,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: _token,
                                obscureText: true,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  labelText: 'Kokoro token',
                                  prefixIcon: Icon(Icons.key_rounded),
                                ),
                                onChanged: (v) => s.kokoroToken = v,
                                onSubmitted: (_) =>
                                    s.checkKokoro(maxAge: Duration.zero),
                              ),
                              if (VoiceSettings.canRemember)
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Remember token on this device',
                                  ),
                                  subtitle: const Text(
                                    'Kept in Android’s encrypted storage. Off: forgotten when you close Voxen.',
                                  ),
                                  value: s.rememberToken,
                                  onChanged: (v) => s.rememberToken = v,
                                ),
                              const SizedBox(height: AppSpacing.md),
                              if (s.kokoroVoices case final voices?
                                  when voices.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  key: ValueKey(voices),
                                  initialValue: voices.contains(s.kokoroVoice)
                                      ? s.kokoroVoice
                                      : null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Kokoro voice',
                                    prefixIcon: Icon(
                                      Icons.record_voice_over_outlined,
                                    ),
                                  ),
                                  items: [
                                    for (final v in voices)
                                      DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                  ],
                                  onChanged: (v) => s.kokoroVoice = v!,
                                )
                              else
                                InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Kokoro voice',
                                    prefixIcon: Icon(
                                      Icons.record_voice_over_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    '${s.kokoroVoice} · more appear once Kokoro is available',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _Section(
                        title: 'Other API',
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: s.mode == ReadMode.api,
                            shape: const RoundedRectangleBorder(),
                            leading: const Icon(Icons.cloud_outlined),
                            title: const Text('OpenAI or your own endpoint'),
                            subtitle: const Text('Makes an MP3 you can export'),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            children: [
                              Text(
                                'Your text goes to the endpoint below and provider charges may apply. The key stays in memory only.',
                                style: note,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              DropdownButtonFormField<SpeechPreset>(
                                initialValue: s.apiPreset,
                                decoration: const InputDecoration(
                                  labelText: 'Provider',
                                ),
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
                              _field(
                                _model,
                                'Model',
                                (v) => s.updateApi(model: v),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _field(
                                _voice,
                                'Voice',
                                (v) => s.updateApi(voice: v),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: s.apiKey.isEmpty
                                      ? null
                                      : () {
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
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Voxen · a Brew app',
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.typography.label.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.lgAll,
              side: BorderSide(color: c.divider),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// One colour theme: its canvas with the accent on top, ticked when chosen.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = context.colors;
    final p = AppColors.of(palette, Theme.of(context).brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} colour',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.fast),
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: p.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? current.text : current.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.accentStrong,
                      shape: BoxShape.circle,
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded, size: 18, color: p.onAccent)
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  palette.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: selected ? current.text : current.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
