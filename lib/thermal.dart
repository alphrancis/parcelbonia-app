import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Colour for the components hub temperature level.
Color hubColor(BuildContext context, String level) {
  final pb = context.pb;
  return switch (level) {
    'hot' => pb.modeSleep,
    'warm' => pb.modeMaintenance,
    'ok' => pb.accent,
    _ => pb.muted,
  };
}

/// Components hub card: RTC temperature, a gauge with the fan threshold
/// marked on it, and the state of the intake and exhaust fans.
/// With [editable] it also lets the user change the threshold.
class ThermalCard extends StatelessWidget {
  final bool editable;
  const ThermalCard({super.key, this.editable = false});

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final c = hubColor(context, s.hubLevel);
    final t = s.hubTemp;
    final reading = s.live['temperature'];

    return PCard(
      padding: const EdgeInsets.all(20),
      glow: s.hubLevel == 'none' ? null : c,
      glowAt: Alignment.topRight,
      glowOpacity: .12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header
          Row(
            children: [
              StateIcon('thermo', color: c, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Components hub', style: display(16, spacing: -.02)),
                    const SizedBox(height: 4),
                    Muted('RTC temperature sensor', size: 11, maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusPill(s.hubStatus, color: c),
            ],
          ),
          const SizedBox(height: 20),

          // reading + threshold
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: t == null ? '—' : t.toStringAsFixed(1), style: display(44, spacing: -.05)),
                        TextSpan(
                          text: ' °C',
                          style: body(16, color: pb.muted, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'FANS ON AT',
                    style: body(9.5, color: pb.muted, spacing: 1, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('${s.fanThreshold.toStringAsFixed(1)} °C', style: display(18, spacing: -.02)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          HubGauge(value: t, threshold: s.fanThreshold, color: c),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Muted(
                  s.asleep
                      ? 'No data while asleep'
                      : (reading == null || reading.ts == 0
                            ? 'Awaiting first reading'
                            : 'Updated ${relative(reading.ts)}'),
                  size: 10.5,
                  maxLines: 1,
                ),
              ),
              Muted('Off below ${(s.fanThreshold - s.fanHysteresis).toStringAsFixed(1)} °C', size: 10.5),
            ],
          ),
          const SizedBox(height: 16),

          // fans
          Row(
            children: [
              // Both fans share one relay, so they always show the same state.
              for (final (i, name) in const ['Intake fan', 'Exhaust fan'].indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: FanTile(name)),
              ],
            ],
          ),

          if (editable) ...[
            const SizedBox(height: 20),
            Divider(height: 1, thickness: 1, color: pb.line),
            const SizedBox(height: 20),
            const ThresholdEditor(),
          ],
        ],
      ),
    );
  }
}

/// Capsule label with a coloured dot.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill(this.label, {super.key, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: PB.tint(color, .14), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: body(11, color: color, weight: FontWeight.w600, height: 1),
        ),
      ],
    ),
  );
}

/// 0 → [hubGaugeMax] °C bar: filled to the current reading, with a tick at
/// the fan threshold.
class HubGauge extends StatelessWidget {
  final double? value;
  final double threshold;
  final Color color;
  const HubGauge({super.key, required this.value, required this.threshold, required this.color});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final fill = ((value ?? 0) / hubGaugeMax).clamp(0.0, 1.0);
        final mark = (threshold / hubGaugeMax).clamp(0.0, 1.0) * w;
        return SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(color: PB.tint(pb.text, .08), borderRadius: BorderRadius.circular(4)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                height: 8,
                width: w * fill,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [PB.tint(color, .55), color]),
                  boxShadow: [BoxShadow(color: PB.tint(color, .45), blurRadius: 8)],
                ),
              ),
              Positioned(
                left: (mark - 1.5).clamp(0.0, w - 3),
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(color: pb.text, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One fan with its relay state; the icon spins while the fan runs.
class FanTile extends StatefulWidget {
  final String name;
  const FanTile(this.name, {super.key});
  @override
  State<FanTile> createState() => _FanTileState();
}

class _FanTileState extends State<FanTile> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final on = !s.asleep && s.fansOn;
    if (on && !_spin.isAnimating) _spin.repeat();
    if (!on && _spin.isAnimating) _spin.stop();
    final c = on ? pb.accent : pb.muted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PB.tint(pb.text, .05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: PB.tint(c, .14), shape: BoxShape.circle),
            child: RotationTransition(
              turns: _spin,
              child: PIcon('fan', size: 18, color: c),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  s.actuatorText(actuators.firstWhere((a) => a.isFan)),
                  maxLines: 1,
                  style: body(10.5, color: c, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider + steppers for the automatic fan threshold.
class ThresholdEditor extends StatefulWidget {
  const ThresholdEditor({super.key});
  @override
  State<ThresholdEditor> createState() => _ThresholdEditorState();
}

class _ThresholdEditorState extends State<ThresholdEditor> {
  double? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final value = (_draft ?? s.fanThreshold).clamp(fanThresholdMin, fanThresholdMax);
    final dirty = _draft != null && _draft != s.fanThreshold;

    void set(double v) {
      final next = ((v * 2).round() / 2).clamp(fanThresholdMin, fanThresholdMax);
      if (next != value) HapticFeedback.selectionClick();
      setState(() => _draft = next);
    }

    Widget stepper(String icon, double delta, String tip) => Tooltip(
      message: tip,
      child: Glass(
        radius: 20,
        blur: 16,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => set(value + delta),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(child: PIcon(icon, size: 16, color: pb.text)),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Automatic fan threshold', style: body(13, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Muted(
          'Both fans switch on when the hub reaches this temperature and off once it drops '
          '${s.fanHysteresis.toStringAsFixed(0)} °C below it.',
          size: 11,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            stepper('minus', -.5, 'Lower by 0.5 °C'),
            Expanded(
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: value.toStringAsFixed(1), style: display(28, spacing: -.04)),
                      TextSpan(
                        text: ' °C',
                        style: body(13, color: pb.muted, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            stepper('plus', .5, 'Raise by 0.5 °C'),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: pb.accent,
            inactiveTrackColor: PB.tint(pb.text, .1),
            thumbColor: Colors.white,
            overlayColor: PB.tint(pb.accent, .12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 3),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: value,
            min: fanThresholdMin,
            max: fanThresholdMax,
            divisions: ((fanThresholdMax - fanThresholdMin) * 2).round(),
            onChanged: set,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Muted('${fanThresholdMin.toInt()} °C', size: 10.5),
              Muted('${fanThresholdMax.toInt()} °C', size: 10.5),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PButton(
                'Reset',
                onTap: dirty ? () => setState(() => _draft = null) : null,
                expand: true,
                height: 44,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PButton(
                _saving ? 'Saving…' : 'Save threshold',
                primary: true,
                expand: true,
                height: 44,
                onTap: !dirty || _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        final err = await s.setFanThreshold(value);
                        if (!mounted) return;
                        setState(() {
                          _saving = false;
                          if (err == null || err == kQueued) _draft = null;
                        });
                        if (context.mounted) {
                          toast(context, err ?? 'Fans will now start at ${value.toStringAsFixed(1)} °C.');
                        }
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
