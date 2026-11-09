import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../on_device/local_kokoro.dart';
import '../on_device/local_models.dart';
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
    ReadMode.kokoro => Icons.dns_outlined,
    ReadMode.phone => Icons.memory_rounded,
    ReadMode.device => Icons.phone_android_rounded,
    ReadMode.api => Icons.cloud_outlined,
  };
}

/// The on-device model's status, as a pill.
StatusPill localModelPill(LocalModels local) {
  final installed = local.installed;
  if (installed != null) {
    return StatusPill(
      label: 'Ready · ${installed == LocalModel.full ? 'full' : 'compact'}',
      icon: Icons.check_circle_rounded,
      tone: Tone.good,
    );
  }
  for (final m in LocalModel.values) {
    final st = local.stateOf(m);
    switch (st.phase) {
      case LocalModelPhase.downloading:
        final p = st.progress;
        return StatusPill(
          label: p == null
              ? 'Downloading'
              : 'Downloading ${(p * 100).round()}%',
          icon: Icons.download_rounded,
          busy: true,
        );
      case LocalModelPhase.unpacking:
        return const StatusPill(
          label: 'Unpacking',
          icon: Icons.unarchive_outlined,
          busy: true,
        );
      case LocalModelPhase.failed:
        return const StatusPill(
          label: 'Download failed',
          icon: Icons.error_outline_rounded,
          tone: Tone.bad,
        );
      case LocalModelPhase.absent || LocalModelPhase.ready:
        break;
    }
  }
  return const StatusPill(
    label: 'Not downloaded',
    icon: Icons.download_for_offline_outlined,
  );
}

/// The reading modes, each with what it uses and whether it can read
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
      ReadMode.auto => switch (s.nextEngine) {
        Engine.phone => const StatusPill(
          label: 'Using Kokoro on this phone',
          icon: Icons.memory_rounded,
          tone: Tone.good,
        ),
        Engine.server => const StatusPill(
          label: 'Using the Kokoro server',
          icon: Icons.dns_outlined,
          tone: Tone.good,
        ),
        _ => const StatusPill(
          label: 'Using this device',
          icon: Icons.phone_android_rounded,
        ),
      },
      ReadMode.kokoro => kokoro.pill,
      ReadMode.phone => localModelPill(s.local),
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
      ReadMode.auto =>
        'Kokoro on this phone, then the Kokoro server, then the device voice.',
      ReadMode.kokoro =>
        s.kokoroHost.isEmpty
            ? 'Your own Kokoro voice server.'
            : 'Your Kokoro server, ${s.kokoroHost}.',
      ReadMode.phone =>
        s.local.installed == null
            ? 'Runs offline on the phone. Download a model in Settings first.'
            : 'Runs offline on the phone; your text never leaves it.',
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
            if (mode != ReadMode.phone || LocalModels.supported)
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
