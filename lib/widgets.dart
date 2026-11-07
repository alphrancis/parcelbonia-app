import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'responsive.dart';

export 'responsive.dart';
import 'store.dart';
import 'theme.dart';

// ------------------------------------------------------------ store access

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child}) : super(notifier: store);
}

extension StoreContext on BuildContext {
  Store get store => dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  Store get storeRead => getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

Color modeColor(BuildContext context, Mode m) {
  final pb = context.pb;
  return [pb.modeAuto, pb.modeMaintenance, pb.modeSleep][m.index];
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2200)));
}

// ------------------------------------------------------------ liquid glass

/// iOS-style "Liquid Glass" material: the content behind is blurred and
/// saturated, a translucent fill lies on top, and a specular rim catches the
/// light along the top-left edge and fades out toward the bottom-right.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? border;
  final double blur;
  final bool elevated;
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.border,
    this.blur = 24,
    this.elevated = false,
  });

  static ColorFilter _saturate(double s) {
    const r = .2126, g = .7152, b = .0722;
    final i = 1 - s;
    return ColorFilter.matrix([
      r * i + s, g * i, b * i, 0, 0, //
      r * i, g * i + s, b * i, 0, 0,
      r * i, g * i, b * i + s, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final dark = pb.isDark;
    final r = BorderRadius.circular(radius);
    var top = Colors.white.withValues(alpha: dark ? .13 : .70);
    var bottom = Colors.white.withValues(alpha: dark ? .045 : .40);
    if (tint != null) {
      top = Color.alphaBlend(tint!.withValues(alpha: tint!.a * (dark ? .22 : .16)), top);
      bottom = Color.alphaBlend(tint!.withValues(alpha: tint!.a * (dark ? .14 : .10)), bottom);
    }

    final glass = ClipRRect(
      borderRadius: r,
      child: BackdropFilter.grouped(
        filter: ImageFilter.compose(
          outer: _saturate(1.7),
          inner: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.mirror),
        ),
        child: CustomPaint(
          foregroundPainter: _GlassRim(radius: radius, dark: dark, border: border),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    if (!elevated) return glass;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: dark ? .45 : .14), blurRadius: 34, offset: const Offset(0, 14)),
      ]),
      child: glass,
    );
  }
}

class _GlassRim extends CustomPainter {
  final double radius;
  final bool dark;
  final Color? border;
  _GlassRim({required this.radius, required this.dark, this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final rr = RRect.fromRectAndRadius(rect.deflate(.6), Radius.circular(radius));
    // Inner sheen along the top edge.
    final sheenRect = Rect.fromLTWH(0, 0, size.width, (size.height * .45).clamp(0, 60).toDouble());
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawRect(
        sheenRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: dark ? .07 : .30), Colors.white.withValues(alpha: 0)],
          ).createShader(sheenRect));
    canvas.restore();
    // Specular edge: bright top-left, nearly gone mid-way, soft bounce bottom-right.
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: dark ? .55 : .95),
              Colors.white.withValues(alpha: dark ? .10 : .35),
              Colors.white.withValues(alpha: dark ? .04 : .25),
              Colors.white.withValues(alpha: dark ? .28 : .80),
            ],
            stops: const [0, .35, .65, 1],
          ).createShader(rect));
    if (border != null) {
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = border!);
    } else if (!dark) {
      // Light mode needs a faint outer line so white glass reads on pale backdrops.
      canvas.drawRRect(
          outer,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6
            ..color = Colors.black.withValues(alpha: .06));
    }
  }

  @override
  bool shouldRepaint(_GlassRim o) => o.radius != radius || o.dark != dark || o.border != border;
}

/// The colourful ambient backdrop the glass refracts: slow-drifting soft
/// colour fields, one of them tinted by the live device mode.
class GlassBackdrop extends StatefulWidget {
  final Color? modeTint;
  const GlassBackdrop({super.key, this.modeTint});
  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final dark = pb.isDark;
    final mode = widget.modeTint ?? pb.accent;
    final blobs = <(Color, double, double, double, double)>[
      // colour, base x, base y, size (x shortest side), phase
      (mode, -.75, -.85, 1.25, 0),
      (const Color(0xFF0A84FF), .95, -.25, 1.1, .25),
      (const Color(0xFFBF5AF2), -.6, .55, 1.15, .5),
      (const Color(0xFF64D2FF), .8, .95, 1.0, .75),
    ];
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark ? const [Color(0xFF0B0E14), Color(0xFF05060A)] : const [Color(0xFFF4F7FB), Color(0xFFE6EBF3)],
          ),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final shortest = c.biggest.shortestSide;
          return AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Stack(clipBehavior: Clip.hardEdge, children: [
              for (final (color, x, y, k, phase) in blobs)
                Builder(builder: (_) {
                  final t = (_c.value + phase) * 2 * pi;
                  final d = shortest * k;
                  final cx = (x + .12 * sin(t)) * c.maxWidth / 2 + c.maxWidth / 2;
                  final cy = (y + .10 * cos(t * 1.3)) * c.maxHeight / 2 + c.maxHeight / 2;
                  return Positioned(
                    left: cx - d / 2,
                    top: cy - d / 2,
                    width: d,
                    height: d,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          color.withValues(alpha: dark ? .34 : .30),
                          color.withValues(alpha: .10),
                          color.withValues(alpha: 0),
                        ], stops: const [0, .45, 1]),
                      ),
                    ),
                  );
                }),
            ]),
          );
        }),
      ),
    );
  }
}

// ------------------------------------------------------------- primitives

/// Card surface - a liquid-glass pane with an optional coloured glow.
class PCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? border, background, glow;
  final Alignment glowAt;
  final double glowOpacity;
  const PCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.border,
    this.background,
    this.glow,
    this.glowAt = Alignment.bottomRight,
    this.glowOpacity = .07,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 24,
      border: border,
      tint: background != null && background!.a > 0 && background != context.pb.surface ? background : null,
      child: Stack(children: [
        if (glow != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: glowAt,
                child: Transform.translate(
                  offset: Offset(glowAt.x * 55, glowAt.y * 65),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                          colors: [glow!.withValues(alpha: (glowOpacity * 2.2).clamp(0, 1)), glow!.withValues(alpha: 0)]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: body(10, color: color ?? context.pb.accent, weight: FontWeight.w600, spacing: 1.3)),
      );
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign? align;
  final int? maxLines;
  const Muted(this.text, {super.key, this.size = 11, this.align, this.maxLines});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: body(size, color: context.pb.muted, height: 1.5));
}

/// `.page-heading`
class PageHeading extends StatelessWidget {
  final String eyebrow, title, description;
  final List<Widget> actions;
  const PageHeading(this.eyebrow, this.title, this.description, {super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= Bp.expanded;
      final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Eyebrow(eyebrow),
        const SizedBox(height: 2),
        Muted(description, size: 12.5),
      ]);
      final acts = Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: wide ? WrapAlignment.end : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: wide && actions.isNotEmpty
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: text),
                const SizedBox(width: 20),
                Flexible(child: acts),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                text,
                if (actions.isNotEmpty) ...[const SizedBox(height: 16), acts],
              ]),
      );
    });
  }
}

/// `.section-head`
class SectionHead extends StatelessWidget {
  final String eyebrow, title;
  final Widget? trailing;
  const SectionHead(this.eyebrow, this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(eyebrow),
            Text(title, style: display(18, spacing: -.025)),
          ]),
        ),
        ?trailing,
      ]);
}

/// `.live-head` — eyebrow + title, with a muted note under it on phones.
class LiveHead extends StatelessWidget {
  final String eyebrow, title;
  final String? note;
  const LiveHead(this.eyebrow, this.title, {super.key, this.note});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(eyebrow),
          Text(title, style: display(18, spacing: -.025)),
          if (note != null) ...[const SizedBox(height: 4), Muted(note!, size: 11)],
        ]),
      );
}

/// `.primary-action` / `.outline-action` / `.unlock-button`
class PButton extends StatelessWidget {
  final String label;
  final String? icon;
  final bool primary, expand, danger;
  final VoidCallback? onTap;
  final double height;
  const PButton(this.label,
      {super.key,
      this.icon,
      this.primary = false,
      this.expand = false,
      this.danger = false,
      this.onTap,
      this.height = 44});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final enabled = onTap != null;
    final fg = primary ? Colors.white : (danger ? pb.danger : pb.text);
    final r = height / 2;
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r),
      splashColor: PB.tint(primary ? Colors.white : pb.accent, .18),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[PIcon(icon!, size: 15, color: fg), const SizedBox(width: 8)],
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis, style: body(13, color: fg, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    final Widget btn;
    if (primary) {
      // Tinted glass: solid accent with a specular gradient highlight.
      btn = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(pb.accent, Colors.white, .22)!, pb.accent],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .35), width: .8),
          boxShadow: [BoxShadow(color: PB.tint(pb.accent, .35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Material(type: MaterialType.transparency, child: content),
      );
    } else {
      btn = Glass(
        radius: r,
        blur: 18,
        tint: danger ? pb.danger : null,
        border: danger ? PB.tint(pb.danger, .35) : null,
        child: Material(type: MaterialType.transparency, child: content),
      );
    }
    return AnimatedOpacity(duration: const Duration(milliseconds: 150), opacity: enabled ? 1 : .5, child: btn);
  }
}

/// Small text link used by `.section-head button` ("View access log →").
class TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const TextLink(this.label, {super.key, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: body(11, color: color ?? context.pb.muted, weight: FontWeight.w500)),
            const SizedBox(width: 6),
            PIcon('arrow', size: 14, color: color ?? context.pb.muted),
          ]),
        ),
      );
}

/// `.state-icon` — tinted rounded square with an icon.
class StateIcon extends StatelessWidget {
  final String icon;
  final Color? color;
  final double size;
  const StateIcon(this.icon, {super.key, this.color, this.size = 32});
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pb.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: PB.tint(c, .13), borderRadius: BorderRadius.circular(size * .22)),
      alignment: Alignment.center,
      child: PIcon(icon, size: size * .52, color: c),
    );
  }
}

/// `.pulse` — glowing dot.
class Pulse extends StatelessWidget {
  final Color? color;
  final double size;
  const Pulse({super.key, this.color, this.size = 7});
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pb.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [
        BoxShadow(color: PB.tint(c, .14), spreadRadius: size * .55),
        BoxShadow(color: c, blurRadius: 8),
      ]),
    );
  }
}

/// `.live-pill`
class LivePill extends StatelessWidget {
  final bool off;
  final String? label;
  const LivePill({super.key, this.off = false, this.label});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final c = off ? pb.muted : pb.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: off ? PB.tint(pb.muted, .14) : pb.accentDim,borderRadius: BorderRadius.circular(15)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: c, boxShadow: off ? null : [BoxShadow(color: c, blurRadius: 5)])),
        const SizedBox(width: 6),
        Text(label ?? (off ? 'Asleep' : 'Live'), style: body(9.5, color: c, weight: FontWeight.w600)),
      ]),
    );
  }
}

/// `.db-note` — Realtime Database link status chip.
class DbNote extends StatelessWidget {
  const DbNote({super.key});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final s = context.store;
    final live = s.link == 'live';
    final bad = s.link == 'error' || s.link == 'signed-out';
    final c = live ? pb.accent : (bad ? pb.danger : pb.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: live ? pb.accentDim : (bad ? PB.tint(pb.danger, .08) : Colors.transparent),
        border: Border.all(color: live || bad ? PB.mix(c, .28, pb.line) : pb.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (s.link == 'connecting')
          SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: c))
        else
          PIcon('activity', size: 13, color: c),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            s.connectionText(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: body(9.5, color: c, weight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// `.switch` — the settings / relay toggle.
class PSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const PSwitch({super.key, required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Opacity(
      opacity: onChanged == null ? .5 : 1,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 50,
          height: 30,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: value ? pb.accent : PB.tint(pb.muted, .32),
            borderRadius: BorderRadius.circular(15),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 6, offset: const Offset(0, 2)),
                ])),
          ),
        ),
      ),
    );
  }
}

/// `.toggle` — the small read-only lock indicator.
class LockToggle extends StatelessWidget {
  final bool on;
  const LockToggle({super.key, required this.on});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 30,
      height: 17,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: on ? pb.danger : pb.accent, borderRadius: BorderRadius.circular(12)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 250),
        alignment: on ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(width: 11, height: 11, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      ),
    );
  }
}

// ------------------------------------------------------------------ brand

class _ShieldClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .5, 0)
    ..lineTo(s.width * .95, s.height * .2)
    ..lineTo(s.width * .88, s.height * .77)
    ..lineTo(s.width * .5, s.height)
    ..lineTo(s.width * .12, s.height * .77)
    ..lineTo(s.width * .05, s.height * .2)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

/// `.brand-mark` — the green shield with "PB".
class BrandMark extends StatelessWidget {
  final double width;
  const BrandMark({super.key, this.width = 31});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final h = width * 35 / 31;
    return ClipPath(
      clipper: _ShieldClip(),
      child: Container(
        width: width,
        height: h,
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF37413B), Color(0xFF181D1A)])),
        padding: const EdgeInsets.all(3),
        child: ClipPath(
          clipper: _ShieldClip(),
          child: Container(
            color: pb.accent.withValues(alpha: .42),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(border: Border.all(color: pb.paper, width: 1)),
              child: Text('PB', style: display(width * .26, color: pb.paper, weight: FontWeight.w700, spacing: 0)),
            ),
          ),
        ),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  final double size;
  final Color? color;
  const Brand({super.key, this.size = 16, this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        BrandMark(width: size * 1.95),
        SizedBox(width: size * .7),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Parcelbonia', style: display(size, color: color, spacing: -.02)),
          ),
        ),
      ]);
}

// --------------------------------------------------------------- inputs

/// Recessed fill for text inputs on glass.
Color fieldFill(PB pb) => pb.isDark ? Colors.black.withValues(alpha: .28) : Colors.white.withValues(alpha: .55);

class PField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final int? maxLength;
  final bool enabled;
  final TextInputType? keyboard;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final double height;
  const PField(this.controller,
      {super.key,
      this.hint,
      this.obscure = false,
      this.maxLength,
      this.enabled = true,
      this.keyboard,
      this.onSubmitted,
      this.suffix,
      this.height = 44});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboard,
        onSubmitted: onSubmitted,
        inputFormatters: maxLength == null ? null : [LengthLimitingTextInputFormatter(maxLength)],
        style: body(12.5, color: pb.text),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: fieldFill(pb),
          hintText: hint,
          hintStyle: body(12, color: pb.muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          enabledBorder: b(pb.line),
          disabledBorder: b(pb.line),
          focusedBorder: b(pb.accent),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class PSelect<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  const PSelect({super.key, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: fieldFill(pb), borderRadius: BorderRadius.circular(14), border: Border.all(color: pb.line)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: pb.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: pb.muted, size: 18),
          style: body(12.5, color: pb.text),
          items: [
            for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- composites

/// `.live-grid` of `.live-tile`s — one per sensor.
class SensorTiles extends StatelessWidget {
  const SensorTiles({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    return RGrid(minItem: 140, children: [
        for (final sensor in tileSensors)
          AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: s.asleep ? .55 : 1,
              child: PCard(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(sensor.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(9.5, color: pb.muted, spacing: .9)),
                    ),
                    PIcon(sensor.icon, size: 16, color: pb.muted),
                  ]),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(s.sensorValue(sensor), style: display(24, spacing: -.04)),
                  ),
                  const SizedBox(height: 8),
                  Text(s.sensorTime(sensor),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: body(9.5, color: pb.muted)),
                ]),
              ),
            ),
      ]);
  }
}

/// `.io-chip` — one input peripheral or output device.
class IoChip extends StatelessWidget {
  final String label, value;
  final String? icon, time;
  final bool? dotOn;
  const IoChip({super.key, required this.label, required this.value, this.icon, this.time, this.dotOn});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        if (icon != null)
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: PB.tint(pb.text, .07), borderRadius: BorderRadius.circular(9)),
            child: PIcon(icon!, size: 15, color: pb.muted),
          )
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotOn == true ? pb.accent : PB.tint(pb.muted, .45),
              boxShadow: dotOn == true ? [BoxShadow(color: pb.accent, blurRadius: 8)] : null,
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: body(9, color: pb.muted, spacing: .8)),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, weight: FontWeight.w600)),
          ]),
        ),
        if (time != null) Text(time!, style: body(8.5, color: pb.muted)),
      ]),
    );
  }
}

List<Widget> inputChips(Store s) => [
      IoChip(
          label: 'RFID module', value: s.rfidText(), icon: 'card', time: s.rfidTs == 0 ? null : relative(s.rfidTs)),
      IoChip(
          label: '4x4 keypad',
          value: s.keypadText(),
          icon: 'key',
          time: s.keypadTs == 0 ? null : relative(s.keypadTs)),
    ];

/// `.io-strip` — inputs then outputs.
class DeviceChips extends StatelessWidget {
  const DeviceChips({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final chips = [
      ...inputChips(s),
      for (final a in actuators.where((a) => !a.isFan))
        IoChip(label: a.name, value: s.actuatorText(a), dotOn: a.relay ? (s.relays[a.id] ?? false) : s.lcdMessage.isNotEmpty),
    ];
    return RGrid(minItem: 170, maxCols: 5, children: chips);
  }
}

/// `.rec-list`
class RecList extends StatelessWidget {
  const RecList({super.key});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final recs = context.store.recommendations();
    return Column(children: [
      for (var i = 0; i < recs.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: pb.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Builder(builder: (_) {
              final r = recs[i];
              final c = r.level == 'ok' ? pb.accent : (r.level == 'info' ? pb.muted : pb.danger);
              final a = r.level == 'alert' ? .18 : (r.level == 'warn' ? .1 : .14);
              return Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: r.level == 'ok' ? pb.accentDim : PB.tint(c, a), borderRadius: BorderRadius.circular(10)),
                child: PIcon(r.icon, size: 16, color: c),
              );
            }),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recs[i].title,
                    style: body(12.5,
                        weight: FontWeight.w600, color: recs[i].level == 'alert' ? pb.danger : pb.text)),
                const SizedBox(height: 4),
                Muted(recs[i].detail, size: 11),
              ]),
            ),
          ]),
        ),
    ]);
  }
}

/// `.summary-strip` — 4 stats, 2×2 on phones.
class SummaryStrip extends StatelessWidget {
  final List<(String, String, String, String?)> items; // label, value, note, unit
  const SummaryStrip(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    Widget cell(int i) {
      final (label, value, note, unit) = items[i];
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: body(10, color: pb.muted)),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: value, style: display(24)),
              if (unit != null) TextSpan(text: unit, style: body(11, color: pb.muted)),
            ])),
          ),
          const SizedBox(height: 8),
          Text(note, maxLines: 2, style: body(10.5, color: pb.muted)),
        ]),
      );
    }

    final line = BorderSide(color: pb.line);
    const box = BoxDecoration();
    return LayoutBuilder(builder: (context, c) {
      // One row of four on tablets and up, 2×2 on phones.
      if (c.maxWidth >= Bp.expanded - 100) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Glass(child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: i < 3 ? Border(right: line) : null),
                    child: cell(i),
                  ),
                ),
            ]),
          )),
        );
      }
      return _grid(box, line, cell);
    });
  }

  Widget _grid(BoxDecoration box, BorderSide line, Widget Function(int) cell) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(child: Column(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: DecoratedBox(decoration: BoxDecoration(border: Border(right: line)), child: cell(0))),
            Expanded(child: cell(1)),
          ]),
        ),
        Divider(height: 1, thickness: 1, color: line.color),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: DecoratedBox(decoration: BoxDecoration(border: Border(right: line)), child: cell(2))),
            Expanded(child: cell(3)),
          ]),
        ),
      ])),
    );
  }
}

/// `.table-card` / `.data-table` — scrolls sideways on phones like the website.
class PTable extends StatelessWidget {
  final List<String> headings;
  final List<List<String>> rows;
  final String empty;
  final bool accessDots;
  final bool statusLast;
  const PTable(this.headings, this.rows,
      {super.key, required this.empty, this.accessDots = false, this.statusLast = true});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    if (rows.isEmpty) {
      return PCard(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Center(child: Muted(empty, align: TextAlign.center)),
      );
    }
    var colW = 132.0;
    Widget cell(String text, int col, List<String> row) {
      final last = statusLast && col == row.length - 1;
      if (last) {
        final denied = text == 'Denied';
        final inBox = text == 'In box' || text == 'In progress';
        final c = denied ? pb.danger : (inBox ? pb.accent : pb.muted);
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: inBox ? pb.accentDim : PB.tint(c, denied ? .1 : .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text, style: body(10.5, color: denied || inBox ? c : pb.text, weight: FontWeight.w500)),
          ),
        );
      }
      return Row(children: [
        if (accessDots && col == 0) ...[
          Builder(builder: (_) {
            final bad = row.last == 'Denied';
            final c = bad ? pb.danger : pb.accent;
            return Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c, blurRadius: 7)]),
            );
          }),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: body(11, color: col < 2 ? pb.text : pb.muted, weight: col == 0 ? FontWeight.w500 : FontWeight.w400)),
        ),
      ]);
    }

    return LayoutBuilder(builder: (context, c) {
      // Columns stretch to fill wide screens; phones scroll sideways.
      colW = ((c.maxWidth - 40) / headings.length).clamp(120.0, 260.0);
      return Glass(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 44,
            color: PB.tint(pb.text, .04),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              for (final h in headings)
                SizedBox(
                    width: colW,
                    child: Text(h.toUpperCase(), style: body(9, color: pb.muted, spacing: .7, weight: FontWeight.w500))),
            ]),
          ),
          for (final row in rows)
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: pb.line))),
              child: Row(children: [
                for (var j = 0; j < row.length; j++)
                  SizedBox(width: colW, child: Padding(padding: const EdgeInsets.only(right: 10), child: cell(row[j], j, row))),
              ]),
            ),
        ]),
      ),
    );
    });
  }
}

/// `.security-banner`
class Banner2 extends StatelessWidget {
  final String icon, title, detail, badge;
  final Color? tone;
  const Banner2({super.key, required this.icon, required this.title, required this.detail, required this.badge, this.tone});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final c = tone ?? pb.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(
      tint: c,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        StateIcon(icon, color: c),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(12.5, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Muted(detail, size: 10.5),
          ]),
        ),
        const SizedBox(width: 8),
        Text(badge, style: body(10.5, color: c, weight: FontWeight.w600)),
      ]),
    ));
  }
}

/// `.prototype-note` / `.helper-note`
class Note extends StatelessWidget {
  final String text;
  final String? icon;
  const Note(this.text, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[PIcon(icon!, size: 15, color: context.pb.muted), const SizedBox(width: 8)],
          Expanded(child: Muted(text, size: 11)),
        ]),
      );
}

/// Standard vertical gap between stacked cards.
const gap14 = SizedBox(height: 16);

Future<void> copyText(String text) => Clipboard.setData(ClipboardData(text: text));

/// Runs a database action and shows the result as a toast.
Future<void> act(BuildContext context, Future<String?> action, String success) async {
  final err = await action;
  if (context.mounted) toast(context, err ?? success);
}
