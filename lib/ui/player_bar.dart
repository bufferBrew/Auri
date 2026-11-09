import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// What is reading, and where its voice comes from.
@immutable
class VoiceSource {
  const VoiceSource(this.icon, this.title, this.origin);
  final IconData icon;
  final String title;
  final String origin;
}

@immutable
class PlayerAction {
  const PlayerAction(this.label, this.icon, this.onPressed);
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

const playbackSpeeds = <double>[0.75, 1, 1.25, 1.5, 1.75, 2];

String speedLabel(double speed) {
  final text = speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  return '$text×';
}

/// The bottom bar: voice and its source on the left (tap to change), then
/// speed, the main play control and a menu for everything else.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.source,
    required this.subtitle,
    required this.progress,
    required this.playing,
    required this.busy,
    required this.playTooltip,
    required this.onPlay,
    required this.onPause,
    required this.speed,
    required this.onSpeed,
    required this.onVoiceTap,
    required this.actions,
  });

  final VoiceSource source;
  final String subtitle;

  /// 0–1, or null for "working on it".
  final double? progress;
  final bool playing;
  final bool busy;
  final String playTooltip;
  final VoidCallback? onPlay;
  final VoidCallback onPause;
  final double speed;
  final ValueChanged<double> onSpeed;
  final VoidCallback onVoiceTap;
  final List<PlayerAction> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;
    final stop = playing || busy;
    return Material(
      color: c.surfaceElevated,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Reading progress',
              child: LinearProgressIndicator(
                value: busy && !playing ? null : progress,
                minHeight: 3,
                backgroundColor: c.divider,
              ),
            ),
            ConstrainedBox(
              // Lines the controls up with the text column on wide screens.
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.readingMaxWidth + 2 * AppSpacing.xxl,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label:
                            'Voice: ${source.title}. ${source.origin}. Change voice',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: onVoiceTap,
                          borderRadius: AppRadius.mdAll,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.accentSubtle,
                                    borderRadius: AppRadius.smAll,
                                  ),
                                  child: SizedBox.square(
                                    dimension: 40,
                                    child: Icon(
                                      source.icon,
                                      color: c.accentStrong,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        source.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.titleSmall,
                                      ),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.bodySmall.copyWith(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    MenuAnchor(
                      menuChildren: [
                        for (final s in playbackSpeeds)
                          MenuItemButton(
                            onPressed: () => onSpeed(s),
                            leadingIcon: Icon(
                              s == speed ? Icons.check_rounded : null,
                              size: 18,
                            ),
                            child: Text(speedLabel(s)),
                          ),
                      ],
                      builder: (context, menu, _) => Tooltip(
                        message: 'Playback speed',
                        child: TextButton(
                          onPressed: () =>
                              menu.isOpen ? menu.close() : menu.open(),
                          style: TextButton.styleFrom(
                            foregroundColor: c.text,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                          child: Text(speedLabel(speed)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton.filled(
                      tooltip: stop
                          ? (busy && !playing ? 'Cancel' : 'Pause')
                          : playTooltip,
                      iconSize: 30,
                      // Explicit: the theme's grey icon colour would otherwise
                      // win over the filled variant's on-accent ink.
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(56),
                        backgroundColor: c.accentStrong,
                        foregroundColor: c.onAccent,
                        disabledBackgroundColor: c.surfaceMuted,
                        disabledForegroundColor: c.textTertiary,
                      ),
                      onPressed: stop ? onPause : onPlay,
                      icon: busy && !playing
                          ? SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: c.onAccent,
                              ),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    MenuAnchor(
                      menuChildren: [
                        for (final a in actions)
                          MenuItemButton(
                            onPressed: a.onPressed,
                            leadingIcon: Icon(a.icon, size: 20),
                            child: Text(a.label),
                          ),
                      ],
                      builder: (context, menu, _) => IconButton(
                        tooltip: 'More',
                        onPressed: () =>
                            menu.isOpen ? menu.close() : menu.open(),
                        icon: const Icon(Icons.more_vert_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A problem worth reading: an error, or a warning such as "Kokoro is
/// offline". The icon and words carry the kind, not just the colour.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    required this.error,
    required this.onDismiss,
  });

  final String message;
  final bool error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = error ? c.dangerText : c.warningText;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Color.alphaBlend(ink.withValues(alpha: 0.12), c.surface),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: ink.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
              color: ink,
              semanticLabel: error ? 'Error' : 'Warning',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  message,
                  style: context.typography.bodySmall.copyWith(color: c.text),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
