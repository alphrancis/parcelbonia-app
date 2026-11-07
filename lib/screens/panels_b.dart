import 'dart:math';

import 'package:flutter/material.dart';

import '../icons.dart';
import '../store.dart';
import '../theme.dart';
import '../totp.dart';
import '../widgets.dart';
import 'panels_a.dart' show exportCsv;

// ================================================================= Deliveries

const deliveryHeadings = ['Delivery ID', 'Received', 'Courier', 'Weight', 'Status'];
List<List<String>> deliveryRows(Store s) => [
      for (final d in s.deliveries) [d.parcelId, dateTime(d.ts), d.courier, d.weight == null ? '—' : '${d.weight!.toStringAsFixed(2)} kg', d.status]
    ];

class DeliveriesPanel extends StatelessWidget {
  const DeliveriesPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final rows = s.deliveries;
    final inBox = rows.where((r) => r.status == 'In box').length;
    final weights = rows.map((r) => r.weight ?? 0).where((w) => w > 0).toList();
    final avg = weights.isEmpty ? null : weights.reduce((a, b) => a + b) / weights.length;
    final done = rows.where((r) => r.status == 'Collected').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeading('Parcel history', 'Deliveries', 'Every parcel received by PB-01, as reported by the device.', actions: [
        PButton('Export', icon: 'file', onTap: () => exportCsv(context, 'Deliveries', deliveryHeadings, deliveryRows(s))),
      ]),
      SummaryStrip([
        ('Total deliveries', '${rows.length}', 'All recorded parcels', null),
        ('Awaiting collection', '$inBox', 'Currently in the box', null),
        ('Average weight', avg == null ? '—' : avg.toStringAsFixed(2), 'From the load cell', ' kg'),
        ('Collection rate', rows.isEmpty ? '—' : '${(done / rows.length * 100).round()}%', 'Collected vs. received', null),
      ]),
      PTable(deliveryHeadings, deliveryRows(s),
          empty: 'No deliveries recorded yet. A row is added when the locker registers a parcel.'),
    ]);
  }
}

// ================================================================= Rider code

class RiderCodePanel extends StatefulWidget {
  const RiderCodePanel({super.key});
  @override
  State<RiderCodePanel> createState() => _RiderCodePanelState();
}

class _RiderCodePanelState extends State<RiderCodePanel> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    // Real TOTP (RFC 6238) from the phone's clock — the Pro Mini computes the
    // same code from its RTC, so no network is needed.
    final seconds = RiderTotp.secondsLeft(s.now);
    final raw = RiderTotp.codeAt(s.now);
    final code = '${raw.substring(0, 3)} ${raw.substring(3)}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeading('Secure parcel access', 'Rider access code',
          'Share a temporary code when a delivery rider arrives and you are away.'),
      SplitPane(
        breakpoint: 820,
        firstFlex: 3,
        secondFlex: 2,
        first: Glass(
        radius: 24,
        child: Column(children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pb.line))),
            child: Row(children: [
              const StateIcon('shield'),
              const SizedBox(width: 11),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PB-01 · Front door', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Time-based code · works offline', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10, color: pb.muted)),
                ]),
              ),
              const LivePill(),
            ]),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
            decoration: BoxDecoration(
              gradient: RadialGradient(center: const Alignment(0, -.1), radius: .75, colors: [pb.accentDim, PB.tint(pb.accentDim, 0)]),
            ),
            child: Column(children: [
              Text('CURRENT RIDER CODE', style: body(10, color: pb.muted, spacing: 1.3)),
              const SizedBox(height: 20),
              FittedBox(child: Text(code, style: display(52, spacing: .09).copyWith(height: 1))),
              const SizedBox(height: 24),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: _Ring(seconds / 30, pb.accent, pb.line),
                    child: Center(child: Text('$seconds', style: display(12, spacing: 0))),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text('This code refreshes automatically\nin $seconds seconds',
                      style: body(10.5, color: pb.muted, height: 1.5)),
                ),
              ]),
              const SizedBox(height: 26),
              PButton(_copied ? 'Code copied' : 'Copy rider code', icon: _copied ? 'shield' : 'card', primary: true, onTap: () async {
                await copyText(raw);
                if (!context.mounted) return;
                setState(() => _copied = true);
                toast(context, 'Rider code copied.');
                Future.delayed(const Duration(milliseconds: 1600), () {
                  if (mounted) setState(() => _copied = false);
                });
              }),
            ]),
          ),
          Container(
            height: 48,
            decoration: BoxDecoration(border: Border(top: BorderSide(color: pb.line))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Pulse(size: 5),
              const SizedBox(width: 9),
              Flexible(
                child: Text('TOTP · HMAC-SHA1 · 6 digits · 30 s',
                    overflow: TextOverflow.ellipsis, style: body(10, color: pb.muted)),
              ),
            ]),
          ),
        ]),
      ),
        second: PCard(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('How it works'),
          Text('Give access without being home.', style: display(22)),
          const SizedBox(height: 20),
          for (final (n, t, d) in [
            ('01', 'Confirm the rider', 'Verify the courier and expected parcel first.'),
            ('02', 'Read out the six-digit code', 'The rider enters it on Parcelbonia\'s keypad.'),
            ('03', 'The box checks it offline', 'PB-01 computes the same code from its own clock, so no Wi-Fi is needed.'),
          ])
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: pb.line))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n, style: display(11, color: pb.accent, spacing: 0)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, style: body(12, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Muted(d, size: 10.5),
                  ]),
                ),
              ]),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pb.accentDim,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PB.mix(pb.accent, .22, pb.line)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PIcon('shield', color: pb.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Never share a code unexpectedly.\n', style: TextStyle(color: pb.text, fontWeight: FontWeight.w600)),
                    const TextSpan(text: 'Codes are temporary and should only be sent to a verified rider at your door.'),
                  ]),
                  style: body(10.5, color: pb.muted, height: 1.55),
                ),
              ),
            ]),
          ),
        ]),
      ),
      ),
      const Note(
          'Codes follow RFC 6238, the Google Authenticator standard. The box also accepts the code just before '
          'and just after the current one, to allow for small clock drift.',
          icon: 'clock'),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: PButton('Copy authenticator link', icon: 'key', onTap: () async {
          await copyText(RiderTotp.uri);
          if (context.mounted) toast(context, 'Link copied. Add it to any authenticator app.');
        }),
      ),
    ]);
  }
}

class _Ring extends CustomPainter {
  final double progress;
  final Color fg, bg;
  _Ring(this.progress, this.fg, this.bg);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(2, 2, s.width - 4, s.height - 4);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    c.drawArc(r, 0, 2 * pi, false, p..color = bg);
    c.drawArc(r, -pi / 2, 2 * pi * progress, false, p..color = fg);
  }

  @override
  bool shouldRepaint(_Ring o) => o.progress != progress || o.fg != fg || o.bg != bg;
}

// ================================================================= Access log

const accessHeadings = ['Date & time', 'Event', 'Person', 'Method', 'Result'];

class AccessLogPanel extends StatelessWidget {
  const AccessLogPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final rows = [for (final r in s.access) [dateTime(r.ts), r.event, r.person, r.method, r.result]];
    final denied = s.access.where((r) => r.result == 'Denied').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeading('Security history', 'Access log', 'Every attempt to open your parcel box, as reported by the device.',
          actions: [PButton('Export', icon: 'file', onTap: () => exportCsv(context, 'Access log', accessHeadings, rows))]),
      Banner2(
        icon: 'shield',
        title: denied > 0 ? '$denied denied attempt${denied == 1 ? '' : 's'} on record' : 'No denied attempts on record',
        detail: denied > 0 ? 'Review the rows marked Denied below.' : 'All recorded access methods were accepted.',
        badge: denied > 0 ? 'Review' : 'Protected',
        tone: denied > 0 ? context.pb.modeMaintenance : null,
      ),
      PTable(accessHeadings, rows,
          accessDots: true, empty: 'No access events recorded yet. The first RFID tap or keypad entry appears here.'),
    ]);
  }
}
