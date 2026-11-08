import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// Animated splash: the app icon scales in over pulsing rings while the
/// saved session is restored and the first database snapshot arrives.
class SplashScreen extends StatefulWidget {
  final Future<void> Function() boot;
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.boot, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  String _status = 'Starting up…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final minTime = Future.delayed(const Duration(milliseconds: 1900));
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _status = 'Connecting to PB-01…');
    });
    await widget.boot();
    if (mounted) setState(() => _status = 'Syncing live data…');
    await minTime;
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final mark = (shortest * .2).clamp(64.0, 112.0);
    final logo = (shortest * .66).clamp(180.0, 264.0);

    final markIn = CurvedAnimation(parent: _intro, curve: const Interval(0, .55, curve: Curves.easeOutBack));
    final wordIn = CurvedAnimation(parent: _intro, curve: const Interval(.35, .8, curve: Curves.easeOutCubic));
    final footIn = CurvedAnimation(parent: _intro, curve: const Interval(.6, 1, curve: Curves.easeOut));

    return Scaffold(
      backgroundColor: pb.ink,
      body: Stack(children: [
        const Positioned.fill(child: GlassBackdrop()),
        // soft green glow
        Center(
          child: Container(
            width: mark * 4,
            height: mark * 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [PB.tint(pb.accent, .13), PB.tint(pb.accent, 0)]),
            ),
          ),
        ),
        // expanding rings
        Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Stack(alignment: Alignment.center, children: [
              for (var i = 0; i < 3; i++)
                Builder(builder: (_) {
                  final t = (_pulse.value + i / 3) % 1;
                  final d = mark * (1.3 + t * 2.4);
                  return Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: PB.tint(pb.accent, (1 - t) * .35), width: 1.2),
                    ),
                  );
                }),
            ]),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: markIn,
              builder: (_, child) => Opacity(
                opacity: markIn.value.clamp(0, 1),
                child: Transform.scale(scale: .6 + .4 * markIn.value, child: child),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(logo * .225),
                  boxShadow: [BoxShadow(color: PB.tint(pb.accent, .25), blurRadius: 40, spreadRadius: 2)],
                ),
                child: Image.asset('assets/icon/app_icon_rounded.png', width: logo, height: logo, filterQuality: FilterQuality.high),
              ),
            ),
            SizedBox(height: mark * .35),
            FadeTransition(
              opacity: wordIn,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(wordIn),
                child: Column(children: [
                  Text('Parcelbonia', style: display(mark * .34, spacing: -.03)),
                  const SizedBox(height: 6),
                  Text('SMART PARCEL RECEIVER', style: body(10, color: pb.muted, spacing: 2.4, weight: FontWeight.w500)),
                ]),
              ),
            ),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: max(32, MediaQuery.paddingOf(context).bottom + 24),
          child: FadeTransition(
            opacity: footIn,
            child: Column(children: [
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(minHeight: 4, color: pb.accent, backgroundColor: pb.line),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(_status, key: ValueKey(_status), style: body(11, color: pb.muted)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
