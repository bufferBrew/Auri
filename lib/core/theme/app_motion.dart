import 'package:flutter/material.dart';

/// The named motion system. Every animation in VoiceBrew references one of
/// these — no magic millisecond literals in the UI.
///
/// This app animates very little on purpose. The one motion that carries
/// meaning is the chapter transition ([chapterTurn]): it tells the reader a
/// page boundary was crossed and in which direction. Everything else is
/// feedback, not decoration.
abstract final class AppMotion {
  static const Duration instant = Duration.zero;

  /// Press, toggle, hover — must never feel laggy.
  static const Duration fast = Duration(milliseconds: 150);

  /// Entrances, state changes, cross-fades.
  static const Duration medium = Duration(milliseconds: 260);

  /// The vertical chapter turn in the reader.
  static const Duration chapterTurn = Duration(milliseconds: 340);

  /// Larger surfaces settling in.
  static const Duration slow = Duration(milliseconds: 480);

  /// Things arriving on screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Things leaving.
  static const Curve exit = Curves.easeInCubic;

  /// Two-way transitions.
  static const Curve transition = Curves.easeInOutCubic;

  /// Emphasised deceleration for large surfaces — the chapter turn.
  static const Curve emphasised = Cubic(0.2, 0, 0, 1);

  /// True when the platform asks for reduced motion, or when a screen reader
  /// is driving navigation. Any non-essential animation must short-circuit.
  static bool reduced(BuildContext context) {
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return media.disableAnimations || media.accessibleNavigation;
  }

  /// [duration], or zero when the user asked for reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
