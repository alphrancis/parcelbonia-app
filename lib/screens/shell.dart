import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'panels_a.dart';
import 'panels_b.dart';
import 'panels_c.dart';

const navItems = [
  ('Overview', 'grid'),
  ('Maintenance', 'sliders'),
  ('Sleep', 'moon'),
  ('Data logs', 'list'),
  ('Deliveries', 'package'),
  ('Rider code', 'clock'),
  ('Access log', 'key'),
  ('RFID cards', 'card'),
  ('Settings', 'settings'),
];

Widget panelFor(String name) => switch (name) {
  'Maintenance' => const MaintenancePanel(),
  'Sleep' => const SleepPanel(),
  'Data logs' => const DataLogsPanel(),
  'Deliveries' => const DeliveriesPanel(),
  'Rider code' => const RiderCodePanel(),
  'Access log' => const AccessLogPanel(),
  'RFID cards' => const RfidPanel(),
  'Settings' => const SettingsPanel(),
  _ => const OverviewPanel(),
};

/// Height of the floating tab bar (without its outer margin / safe area).
const _tabBarHeight = 64.0;
const _tabBarMargin = 12.0;

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barSpace = _tabBarHeight + _tabBarMargin + max(safeBottom, _tabBarMargin);

    return PopScope(
      canPop: s.panel == 'Overview',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) s.go('Overview');
      },
      child: Scaffold(
        backgroundColor: pb.ink,
        body: BackdropGroup(
          child: Stack(
            children: [
              Positioned.fill(child: GlassBackdrop(modeTint: modeColor(context, s.mode))),
              Column(
                children: [
                  const _Topbar(),
                  Expanded(
                    child: RefreshIndicator(
                      color: pb.accent,
                      backgroundColor: pb.surfaceRaised,
                      edgeOffset: 0,
                      onRefresh: () async {
                        s.resume();
                        await Future.delayed(const Duration(milliseconds: 800));
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: Tween(begin: .985, end: 1.0).animate(a), child: child),
                        ),
                        child: ListView(
                          key: ValueKey(s.panel),
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: EdgeInsets.fromLTRB(context.gutter, 8, context.gutter, barSpace + 24),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1280),
                                child: panelFor(s.panel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: max(safeBottom, _tabBarMargin),
                child: const Center(child: GlassTabBar()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating liquid-glass tab bar: icons only, with a glass "lens" that
/// slides to the selected tab.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final index = max(0, navItems.indexWhere((n) => n.$1 == s.panel));
    final width = min(context.screenW - _tabBarMargin * 2, 600.0);
    const pad = 6.0;
    final itemW = (width - pad * 2) / navItems.length;
    final iconSize = itemW < 40 ? 20.0 : 22.0;

    return SizedBox(
      width: width,
      child: Glass(
        radius: _tabBarHeight / 2,
        blur: 30,
        elevated: true,
        padding: const EdgeInsets.all(pad),
        child: SizedBox(
          height: _tabBarHeight - pad * 2,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                left: index * itemW,
                width: itemW,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [PB.tint(pb.accent, pb.isDark ? .30 : .22), PB.tint(pb.accent, pb.isDark ? .14 : .10)],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: pb.isDark ? .22 : .7), width: .8),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (final (i, (name, icon)) in navItems.indexed)
                      SizedBox(
                        width: itemW,
                        child: Semantics(
                          button: true,
                          selected: i == index,
                          label: name,
                          child: Tooltip(
                            message: name,
                            preferBelow: false,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (s.panel == name) return;
                                HapticFeedback.selectionClick();
                                s.go(name);
                              },
                              child: Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutBack,
                                  scale: i == index ? 1.12 : 1,
                                  child: PIcon(
                                    icon,
                                    size: iconSize,
                                    color: i == index ? pb.accent : PB.tint(pb.text, .72),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large-title header: greeting/panel title, glass action buttons and the
/// mode segmented control.
class _Topbar extends StatelessWidget {
  const _Topbar();

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final title = switch (s.panel) {
      'Overview' => 'Good day, ${s.firstName}.',
      'Sleep' => 'Sleep control',
      'Rider code' => 'Rider access code',
      final p => p,
    };

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, c) {
          final oneRow = c.maxWidth >= 860;
          final g = context.gutter;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pulse(color: s.link == 'live' ? modeColor(context, s.mode) : pb.muted, size: 6),
                  const SizedBox(width: 8),
                  Text(
                    'CONTROL CENTER',
                    style: body(10, color: pb.muted, spacing: 1.3, weight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  title,
                  key: ValueKey(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(c.maxWidth < Bp.compact ? 24 : 30, spacing: -.04),
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleGlassButton(
                icon: s.dark ? 'sun' : 'moon',
                tip: 'Switch to ${s.dark ? 'light' : 'dark'} mode',
                onTap: s.toggleTheme,
              ),
              const SizedBox(width: 8),
              _UnlockButton(iconOnly: c.maxWidth < 440),
            ],
          );

          if (oneRow) {
            return Padding(
              padding: EdgeInsets.fromLTRB(g, 14, g, 14),
              child: Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 16),
                  const SizedBox(width: 400, child: ModeSwitch()),
                  const SizedBox(width: 16),
                  actions,
                ],
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.fromLTRB(g, 10, g, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
                const SizedBox(height: 14),
                const ModeSwitch(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CircleGlassButton extends StatelessWidget {
  final String icon, tip;
  final VoidCallback onTap;
  const _CircleGlassButton({required this.icon, required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Tooltip(
      message: tip,
      child: Glass(
        radius: 22,
        blur: 18,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: PIcon(icon, size: 19, color: pb.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockButton extends StatelessWidget {
  final bool iconOnly;
  const _UnlockButton({required this.iconOnly});
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final label = s.asleep ? 'Asleep' : (s.unlocking ? 'Unlocking…' : 'Unlock remotely');
    final onTap = s.asleep || s.unlocking ? null : () => act(context, s.unlock(), 'Unlock command sent to PB-01.');
    if (!iconOnly) return PButton(label, icon: 'unlock', primary: true, onTap: onTap, height: 44);
    final pb = context.pb;
    return Tooltip(
      message: s.asleep ? 'Wake the microcontroller first' : 'Unlock remotely',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? .5 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(pb.accent, Colors.white, .22)!, pb.accent],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .35), width: .8),
            boxShadow: [BoxShadow(color: PB.tint(pb.accent, .4), blurRadius: 16, offset: const Offset(0, 5))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: s.unlocking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const PIcon('unlock', size: 19, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mode segmented control — a glass track with a lens that slides to the
/// active mode and takes on its colour.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final now = modeColor(context, s.mode);
    return Glass(
      radius: 22,
      blur: 20,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, c) {
          final showLabels = c.maxWidth >= 240;
          final w = c.maxWidth / Mode.values.length;
          return SizedBox(
            height: 36,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  left: s.mode.index * w,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [PB.tint(now, pb.isDark ? .34 : .24), PB.tint(now, pb.isDark ? .16 : .12)],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: pb.isDark ? .22 : .7), width: .8),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final m in Mode.values)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: m == s.mode,
                            label: '${m.label} mode',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (m == s.mode) return;
                                HapticFeedback.selectionClick();
                                act(context, s.setMode(m), 'Mode set to ${m.label}.');
                              },
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      PIcon(m.icon, size: 15, color: m == s.mode ? modeColor(context, m) : pb.muted),
                                      if (showLabels) ...[
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            m.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textHeightBehavior: const TextHeightBehavior(
                                              applyHeightToFirstAscent: false,
                                              applyHeightToLastDescent: false,
                                            ),
                                            style: body(
                                              12.5,
                                              height: 1,
                                              color: m == s.mode ? modeColor(context, m) : pb.muted,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
