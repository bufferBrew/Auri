import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'appearance_settings.dart';
import 'features/read_aloud/data/incoming_text.dart';
import 'on_device/local_kokoro.dart';
import 'on_device/local_models.dart';
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ReadModePicker(settings: s),
                              if (LocalModels.supported &&
                                  s.mode == ReadMode.auto)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.sm,
                                    AppSpacing.lg,
                                    AppSpacing.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Automatic tries first',
                                        style: t.label.copyWith(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      SegmentedButton<bool>(
                                        showSelectedIcon: false,
                                        segments: const [
                                          ButtonSegment(
                                            value: false,
                                            icon: Icon(Icons.dns_outlined),
                                            label: Text('Your Mac'),
                                          ),
                                          ButtonSegment(
                                            value: true,
                                            icon: Icon(Icons.memory_rounded),
                                            label: Text('This phone'),
                                          ),
                                        ],
                                        selected: {s.phoneFirst},
                                        onSelectionChanged: (v) =>
                                            s.phoneFirst = v.single,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        s.phoneFirst
                                            ? 'This phone, then the Kokoro server, then the device voice.'
                                            : 'The Kokoro server, then this phone, then the device voice.',
                                        style: note,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (IncomingText.supported)
                        _Section(
                          title: 'Read aloud in other apps',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.xs,
                                    AppSpacing.lg,
                                    AppSpacing.xs,
                                  ),
                                  child: Text(
                                    'Select text in any app and tap “Voxen · Read aloud” (often under ⋮). Voxen reads it without opening; the notification shows the voice, with Stop and Device voice.',
                                    style: note,
                                  ),
                                ),
                                SelectionVoicePicker(settings: s),
                              ],
                            ),
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
                              if (s.voiceChoices case final voices?
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
                      if (LocalModels.supported)
                        _Section(
                          title: 'Voice models on this phone',
                          child: _PhoneModels(local: s.local),
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

/// The downloadable on-device models. Nothing downloads without a tap and a
/// confirmation that names the size.
class _PhoneModels extends StatelessWidget {
  const _PhoneModels({required this.local});
  final LocalModels local;

  Future<void> _confirmDownload(BuildContext context, LocalModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Download ${m.label}?'),
        content: Text(
          'This downloads ${m.downloadMb} MB from sherpa-onnx on GitHub and '
          'uses ${m.diskMb} MB on the phone. Use Wi-Fi if your data is '
          'limited. You can delete it here any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text('Download ${m.downloadMb} MB'),
          ),
        ],
      ),
    );
    if (ok == true) await local.download(m);
  }

  Future<void> _confirmDelete(BuildContext context, LocalModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${m.label}?'),
        content: Text('Frees ${m.diskMb} MB. You can download it again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await local.delete(m);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;
    final note = t.bodySmall.copyWith(color: c.textSecondary);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kokoro running on the phone itself: no Mac, no connection, and '
            'your text never leaves the phone. Same voices as the server. '
            'Nothing downloads until you choose a model.',
            style: note,
          ),
          for (final m in LocalModel.values) ...[
            const SizedBox(height: AppSpacing.lg),
            _modelRow(context, m, note),
          ],
        ],
      ),
    );
  }

  Widget _modelRow(BuildContext context, LocalModel m, TextStyle note) {
    final t = context.typography;
    final st = local.stateOf(m);
    final busyHere =
        st.phase == LocalModelPhase.downloading ||
        st.phase == LocalModelPhase.unpacking;
    final StatusPill pill = switch (st.phase) {
      LocalModelPhase.ready => const StatusPill(
        label: 'On this phone',
        icon: Icons.check_circle_rounded,
        tone: Tone.good,
      ),
      LocalModelPhase.downloading => StatusPill(
        label: st.progress == null
            ? 'Downloading'
            : 'Downloading ${(st.progress! * 100).round()}%',
        icon: Icons.download_rounded,
        busy: true,
      ),
      LocalModelPhase.unpacking => const StatusPill(
        label: 'Unpacking',
        icon: Icons.unarchive_outlined,
        busy: true,
      ),
      LocalModelPhase.failed => StatusPill(
        label: st.error ?? 'Download failed',
        icon: Icons.error_outline_rounded,
        tone: Tone.bad,
      ),
      LocalModelPhase.absent => StatusPill(
        label: '${m.downloadMb} MB download',
        icon: Icons.download_for_offline_outlined,
      ),
    };
    final Widget action = switch (st.phase) {
      LocalModelPhase.ready => TextButton.icon(
        onPressed: () => _confirmDelete(context, m),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Delete'),
      ),
      LocalModelPhase.downloading => TextButton(
        onPressed: local.cancel,
        child: const Text('Cancel'),
      ),
      LocalModelPhase.unpacking => const SizedBox.shrink(),
      _ => OutlinedButton.icon(
        onPressed: local.busy ? null : () => _confirmDownload(context, m),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text(
          st.phase == LocalModelPhase.failed ? 'Try again' : 'Download',
        ),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(m.label, style: t.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text('${m.detail} ${m.diskMb} MB on the phone.', style: note),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(liveRegion: true, child: pill),
            action,
          ],
        ),
        if (busyHere) ...[
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: st.phase == LocalModelPhase.downloading ? st.progress : null,
          ),
        ],
      ],
    );
  }
}
