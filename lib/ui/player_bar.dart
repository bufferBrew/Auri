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

const playbackSpeeds = <double>[
  0.25,
  0.5,
  0.75,
  1,
  1.25,
  1.5,
  1.75,
  2,
  2.25,
  2.5,
  2.75,
  3,
];

String _clock(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String speedLabel(double speed) {
  final text = speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text×';
}

/// The bottom bar: voice and its source on the left (tap to change), then
/// speed, the main play control and a menu for everything else.
class PlayerBar extends StatefulWidget {
  const PlayerBar({
    super.key,
    required this.source,
    required this.subtitle,
    required this.progress,
    this.onSeek,
    this.total,
    this.elapsed = Duration.zero,
    this.estimated = false,
    this.onParagraphs,
    this.paragraphLabel,
    this.onPrevious,
    this.onNext,
    this.onBack,
    this.onForward,
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
  final ValueChanged<double>? onSeek;
  final Duration? total;
  final Duration elapsed;
  final bool estimated;
  final VoidCallback? onParagraphs;
  final String? paragraphLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
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
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  double? _drag;

  @override
  void didUpdateWidget(PlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onSeek == null) _drag = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;
    final stop = widget.playing || widget.busy;
    return Material(
      color: c.surfaceElevated,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onSeek == null)
              LinearProgressIndicator(
                value: widget.busy && !widget.playing ? null : widget.progress,
                minHeight: 3,
                backgroundColor: c.divider,
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.readingMaxWidth,
                ),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Playback position',
                      child: Slider(
                        value: _drag ?? widget.progress ?? 0,
                        semanticFormatterCallback: (v) => widget.total == null
                            ? '${(v * 100).round()}% through text'
                            : _clock(widget.total! * v),
                        onChanged: (v) => setState(() => _drag = v),
                        onChangeEnd: (v) {
                          setState(() => _drag = null);
                          widget.onSeek?.call(v);
                        },
                      ),
                    ),
                    if (widget.total case final total?)
                      Text(
                        '${_clock(_drag == null ? widget.elapsed : total * _drag!)}'
                        ' / ${widget.estimated ? '~' : ''}${_clock(total)}',
                        style: t.bodySmall,
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous or restart paragraph (Shift+P)',
                          onPressed: widget.onPrevious,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        if (widget.onBack != null)
                          IconButton(
                            tooltip: 'Back 10 seconds (J)',
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.replay_10_rounded),
                          ),
                        TextButton(
                          onPressed: widget.onParagraphs,
                          child: Text(
                            widget.paragraphLabel ?? 'Paragraphs',
                            semanticsLabel: 'Show all paragraphs',
                          ),
                        ),
                        if (widget.onForward != null)
                          IconButton(
                            tooltip: 'Forward 10 seconds (L)',
                            onPressed: widget.onForward,
                            icon: const Icon(Icons.forward_10_rounded),
                          ),
                        IconButton(
                          tooltip: 'Next paragraph (Shift+N)',
                          onPressed: widget.onNext,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ],
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
                            'Voice: ${widget.source.title}. ${widget.source.origin}. Change voice',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: widget.onVoiceTap,
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
                                      widget.source.icon,
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
                                        widget.source.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.titleSmall,
                                      ),
                                      Text(
                                        widget.subtitle,
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
                            onPressed: () => widget.onSpeed(s),
                            leadingIcon: Icon(
                              s == widget.speed ? Icons.check_rounded : null,
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
                          child: Text(speedLabel(widget.speed)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton.filled(
                      tooltip: stop
                          ? (widget.busy && !widget.playing
                                ? 'Cancel'
                                : 'Pause')
                          : widget.playTooltip,
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
                      onPressed: stop ? widget.onPause : widget.onPlay,
                      icon: widget.busy && !widget.playing
                          ? SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: c.onAccent,
                              ),
                            )
                          : Icon(
                              widget.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    MenuAnchor(
                      menuChildren: [
                        for (final a in widget.actions)
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
