import 'package:flutter/material.dart';

/// Breakpoints, measured on the width actually available to a widget
/// (so the sidebar is accounted for), not on the whole screen.
abstract final class Bp {
  static const compact = 360.0; // small phones
  static const medium = 600.0; // large phones / small tablets
  static const expanded = 900.0; // tablets, landscape
  static const wide = 1200.0; // desktop
}

extension ScreenSize on BuildContext {
  double get screenW => MediaQuery.sizeOf(this).width;

  /// Page gutter that grows with the screen.
  double get gutter => screenW < Bp.compact ? 16 : (screenW < Bp.medium ? 16 : (screenW < Bp.wide ? 24 : 40));
}

/// Grid that fits as many columns of at least [minItem] as the width allows.
class RGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItem, spacing;
  final int maxCols;
  const RGrid({super.key, required this.children, this.minItem = 160, this.spacing = 12, this.maxCols = 4});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = ((c.maxWidth + spacing) / (minItem + spacing)).floor().clamp(1, maxCols);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [
          for (final child in children) SizedBox(width: w, child: child),
        ]);
      });
}

/// Two panes side by side when there is room, stacked otherwise.
class SplitPane extends StatelessWidget {
  final Widget first, second;
  final double breakpoint, gap;
  final int firstFlex, secondFlex;
  final CrossAxisAlignment align;
  const SplitPane({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = Bp.expanded,
    this.gap = 16,
    this.firstFlex = 1,
    this.secondFlex = 1,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, SizedBox(height: gap), second]);
        }
        return Row(crossAxisAlignment: align, children: [
          Expanded(flex: firstFlex, child: first),
          SizedBox(width: gap),
          Expanded(flex: secondFlex, child: second),
        ]);
      });
}
