import 'package:flutter/material.dart';

/// 4px-base spacing scale. Every gap, pad and inset comes from here — no
/// ad-hoc `SizedBox(height: 13)` anywhere in the app.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter, widening with the viewport.
  static double gutter(double width) {
    if (width >= AppBreakpoints.expanded) return xxl;
    if (width >= AppBreakpoints.medium) return xl;
    return lg;
  }

  /// Minimum hit target. 48dp is the Material floor and comfortably clears
  /// the 44pt iOS and 24px WCAG 2.2 minimums.
  static const double minTapTarget = 48;
}

/// Corner radii.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));

  /// Fully rounded pill — chips, small buttons, the voiceover control.
  static const StadiumBorder pill = StadiumBorder();

  /// The same pill shape for containers that take a [BorderRadius] rather
  /// than a [ShapeBorder].
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(999));
}

/// Layout breakpoints and the responsive rules built on them.
abstract final class AppBreakpoints {
  /// Below this: phones, one column.
  static const double compact = 600;

  /// Tablet / small laptop.
  static const double medium = 1000;

  /// Desktop.
  static const double expanded = 1400;

  /// Widest a general content column may get.
  static const double contentMaxWidth = 1040;

  /// Widest the reader's text column may get. Long full-width measures are
  /// unreadable, and this is a reading app before it is anything else — 720px
  /// at the 17px reading size lands around 75 characters per line.
  static const double readingMaxWidth = 720;

  /// Course grid columns: 1 / 2 / 3 as the viewport grows.
  static int gridColumns(double width) {
    if (width >= medium) return 3;
    if (width >= compact) return 2;
    return 1;
  }

  static bool isCompact(double width) => width < compact;
}

/// Centres and width-caps its child so wide viewports keep a readable measure.
///
/// Uses `Align(heightFactor: 1)` rather than [Center]: a plain [Center] expands
/// to the tallest allowed size, which silently swallows the viewport when this
/// wraps a height-loose slot.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
