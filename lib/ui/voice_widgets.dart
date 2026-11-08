import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../voice_settings.dart';

enum Tone { neutral, good, warning, bad }

/// A small status label. State is always carried by the icon and the words,
/// never by colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.tone = Tone.neutral,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Tone tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = switch (tone) {
      Tone.good => c.successText,
      Tone.warning => c.warningText,
      Tone.bad => c.dangerText,
      Tone.neutral => c.textSecondary,
    };
    final fill = switch (tone) {
      Tone.neutral => c.surfaceMuted,
      _ => ink.withValues(alpha: 0.12),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: AppRadius.pillAll),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xxs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: ink),
              )
            else
              Icon(icon, size: 14, color: ink),
            const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
            Flexible(
              child: Text(
                label,
                style: context.typography.caption.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension KokoroStatusUi on KokoroStatus {
  String get short => switch (state) {
    KokoroState.notSetUp => 'Not set up',
    KokoroState.needsToken => 'Needs token',
    KokoroState.unknown => 'Not checked',
    KokoroState.checking => 'Checking',
    KokoroState.available => 'Available · $voiceCount voices',
    KokoroState.offline => 'Offline',
    KokoroState.rejected => 'Token rejected',
  };

  StatusPill get pill => StatusPill(
    label: short,
    busy: state == KokoroState.checking,
    icon: switch (state) {
      KokoroState.available => Icons.check_circle_rounded,
      KokoroState.offline => Icons.cloud_off_rounded,
      KokoroState.rejected => Icons.key_off_rounded,
      _ => Icons.info_outline_rounded,
    },
    tone: switch (state) {
      KokoroState.available => Tone.good,
      // Unreachable is a warning, not an error: nothing is broken or lost.
      KokoroState.offline => Tone.warning,
      KokoroState.rejected => Tone.bad,
      _ => Tone.neutral,
    },
  );
}

extension ReadModeUi on ReadMode {
  IconData get icon => switch (this) {
    ReadMode.auto => Icons.auto_awesome_rounded,
    ReadMode.kokoro => Icons.graphic_eq_rounded,
    ReadMode.device => Icons.phone_android_rounded,
    ReadMode.api => Icons.cloud_outlined,
  };
}

/// The four reading modes, each with what it uses and whether it can read
/// right now.
class ReadModePicker extends StatelessWidget {
  const ReadModePicker({super.key, required this.settings, this.onPicked});

  final VoiceSettings settings;
  final ValueChanged<ReadMode>? onPicked;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final kokoro = s.kokoroStatus;
    StatusPill pillFor(ReadMode mode) => switch (mode) {
      ReadMode.auto =>
        s.wouldUseKokoro
            ? const StatusPill(
                label: 'Using Kokoro',
                icon: Icons.graphic_eq_rounded,
                tone: Tone.good,
              )
            : const StatusPill(
                label: 'Using this device',
                icon: Icons.phone_android_rounded,
              ),
      ReadMode.kokoro => kokoro.pill,
      ReadMode.device => const StatusPill(
        label: 'Available',
        icon: Icons.check_circle_rounded,
        tone: Tone.good,
      ),
      ReadMode.api =>
        s.apiKey.isEmpty
            ? const StatusPill(label: 'Needs a key', icon: Icons.key_rounded)
            : const StatusPill(
                label: 'Key entered',
                icon: Icons.check_circle_rounded,
                tone: Tone.good,
              ),
    };
    String detail(ReadMode mode) => switch (mode) {
      ReadMode.auto => 'Kokoro when it answers, otherwise this device.',
      ReadMode.kokoro =>
        s.kokoroHost.isEmpty
            ? 'Your own Kokoro voice server.'
            : 'Your Kokoro server, ${s.kokoroHost}.',
      ReadMode.device =>
        'The ${s.deviceVoice ?? 'system'} voice. Works offline.',
      ReadMode.api => 'OpenAI or your own endpoint, as an MP3.',
    };
    return RadioGroup<ReadMode>(
      groupValue: s.mode,
      onChanged: (m) {
        s.mode = m!;
        onPicked?.call(m);
      },
      child: Column(
        children: [
          for (final mode in ReadMode.values)
            RadioListTile<ReadMode>(
              value: mode,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              secondary: Icon(mode.icon),
              title: Text(mode.label),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail(mode)),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                    pillFor(mode),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
