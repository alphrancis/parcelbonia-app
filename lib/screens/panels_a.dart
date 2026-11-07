import 'package:flutter/material.dart';

import '../icons.dart';
import '../store.dart';
import '../thermal.dart';
import '../theme.dart';
import '../widgets.dart';

// =================================================================== Overview

class OverviewPanel extends StatelessWidget {
  const OverviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final mc = modeColor(context, s.mode);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // .mode-strip
      PCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: PB.mix(mc, .26, pb.line),
        glow: mc,
        glowAt: Alignment.topRight,
        glowOpacity: .1,
        child: LayoutBuilder(builder: (context, c) {
          final info = Row(children: [
            StateIcon(s.mode.icon, color: mc, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Operating mode'),
                Text(s.mode.label, style: display(15)),
                const SizedBox(height: 4),
                Muted(s.mode.blurb, size: 10.5),
              ]),
            ),
          ]);
          if (c.maxWidth >= Bp.medium) {
            return Row(children: [Expanded(child: info), const SizedBox(width: 12), const Flexible(child: DbNote())]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 12), const DbNote()]);
        }),
      ),
      LiveHead('Live dashboard', 'Current readings', note: s.heartbeatLine()),
      const SensorTiles(),
      const SizedBox(height: 12),
      const DeviceChips(),
      const LiveHead('Cooling', 'Components hub', note: 'Fans switch on automatically at the threshold set in Maintenance.'),
      const ThermalCard(),
      gap14,
      SplitPane(
        firstFlex: 145,
        secondFlex: 80,
        breakpoint: 860,
        first: const _AdviceCard(),
        second: const _LockerCard(),
      ),
    ]);
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard();
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    return PCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      glow: pb.accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHead('Advice', 'Recommendations', trailing: TextLink('Maintenance', onTap: () => s.go('Maintenance'))),
        const SizedBox(height: 12),
        const RecList(),
        Divider(color: pb.line, height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${s.logs.length}', style: display(30)),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Latest log rows\nrows retained', style: body(10.5, color: pb.muted, height: 1.4)),
            ),
          ),
          TextLink('Data logs', onTap: () => s.go('Data logs')),
        ]),
        const SizedBox(height: 8),
        if (s.logs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Muted('Nothing logged yet — the first row lands at the next log interval.'),
          ),
        for (final row in s.logs.take(4))
          Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: pb.line))),
            child: Row(children: [
              Container(
                width: 33,
                height: 33,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: PB.tint(pb.text, .06), borderRadius: BorderRadius.circular(14)),
                child: PIcon('list', size: 16, color: pb.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(dateTime(row.ts), style: body(12, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Muted(
                      row.values.isEmpty && row.event != null
                          ? row.event!
                          : sensors.take(3).map((x) => '${x.name}: ${x.format(row.values[x.id])}').join(' · '),
                      size: 10,
                      maxLines: 2),
                ]),
              ),
              const SizedBox(width: 8),
              Text(relative(row.ts), style: body(10, color: pb.muted)),
            ]),
          ),
      ]),
    );
  }
}

class _LockerCard extends StatelessWidget {
  const _LockerCard();
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    return PCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead('Device PB-01', 'Parcel box', trailing: LivePill(off: s.asleep || s.link != 'live')),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: (c.maxWidth * .85).clamp(240.0, 310.0),
            child: FittedBox(child: SizedBox(width: 300, height: 290, child: _LockerStage(open: s.lockOpen, asleep: s.asleep))),
          ),
        ),
        // .locker-state
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PB.tint(pb.text, .05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pb.line),
          ),
          child: Row(children: [
            StateIcon(s.asleep ? 'moon' : 'shield', color: s.asleep ? pb.muted : null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CURRENT STATUS', style: body(8.5, color: pb.muted, spacing: .7)),
                const SizedBox(height: 3),
                Text(s.lockerStatus(), style: body(12.5, weight: FontWeight.w600)),
              ]),
            ),
            LockToggle(on: s.lockOpen),
          ]),
        ),
        const SizedBox(height: 12),
        // .sensor-grid
        Container(
          decoration: BoxDecoration(border: Border.all(color: pb.line), borderRadius: BorderRadius.circular(14)),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (i, (l, v)) in [
                ('Mode', s.mode.label),
                ('MCU', s.awake ? 'Awake' : 'Asleep'),
                ('Changed', s.powerChangedAt == 0 ? '—' : relative(s.powerChangedAt)),
              ].indexed)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: i < 2 ? Border(right: BorderSide(color: pb.line)) : null),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.toUpperCase(), style: body(8.5, color: pb.muted, spacing: .7)),
                      const SizedBox(height: 4),
                      Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, weight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// `.locker-stage` — concentric rings with the PB-01 box drawn on top.
class _LockerStage extends StatelessWidget {
  final bool open, asleep;
  const _LockerStage({required this.open, required this.asleep});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final green = pb.accent;
    const dim = Color(0xFF2B3B30);
    return Stack(alignment: Alignment.center, children: [
      for (final (d, a) in [(350.0, .2), (280.0, .55)])
        Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: PB.tint(pb.line, a * .55))),
      Container(width: 210, height: 210, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pb.line))),
      Positioned(
        bottom: 26,
        child: Container(
          width: 160,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 22, spreadRadius: 2)],
          ),
        ),
      ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 158,
        height: 213,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF333B37)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0, .7],
            colors: [Color(0xFF1E2320), Color(0xFF0C0E0D)],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 30, offset: const Offset(12, 18)),
            if (open) BoxShadow(color: green.withValues(alpha: .22), blurRadius: 25),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: asleep ? const Color(0xFF555555) : (open ? pb.danger : green),
                boxShadow: asleep ? null : [BoxShadow(color: open ? pb.danger : green, blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
            decoration: BoxDecoration(
              color: asleep ? const Color(0xFF0A0B0A) : const Color(0xFF021A0A),
              border: Border.all(color: const Color(0xFF073315)),
            ),
            child: Column(children: [
              Text('PARCELBONIA', style: display(9, color: asleep ? dim : green, spacing: .05)),
              const SizedBox(height: 3),
              Text(asleep ? 'SLEEPING' : (open ? 'ACCESS GRANTED' : 'READY'),
                  style: display(5.5, color: (asleep ? dim : green).withValues(alpha: .6), spacing: .13)),
            ]),
          ),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF2A322E)), borderRadius: BorderRadius.circular(4)),
              child: Stack(alignment: Alignment.center, children: [
                for (final d in [26.0, 18.0, 10.0])
                  Container(
                      width: d,
                      height: d,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: green.withValues(alpha: .35)))),
              ]),
            ),
            const Spacer(),
            SizedBox(
              width: 46,
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (var i = 0; i < 12; i++)
                  Container(
                      width: 12,
                      height: 8,
                      decoration: BoxDecoration(color: const Color(0xFF2A322E), borderRadius: BorderRadius.circular(1.5))),
              ]),
            ),
          ]),
          const Spacer(),
          Container(height: 1, color: const Color(0xFF2A322E)),
        ]),
      ),
    ]);
  }
}

// ================================================================ Maintenance

class MaintenancePanel extends StatefulWidget {
  const MaintenancePanel({super.key});
  @override
  State<MaintenancePanel> createState() => _MaintenancePanelState();
}

class _MaintenancePanelState extends State<MaintenancePanel> {
  final _lcd = TextEditingController();

  @override
  void dispose() {
    _lcd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final active = s.mode == Mode.maintenance;

    Widget sensorRow(Sensor sensor) => LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 420;
          final check = PButton('Check',
              icon: 'refresh',
              height: 34,
              expand: narrow,
              onTap: active ? () => act(context, s.checkSensor(sensor.id), 'Read requested from ${sensor.name}.') : null);
          final value = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(s.sensorValue(sensor), style: display(15)),
            const SizedBox(height: 3),
            Text(s.sensorTime(sensor), style: body(9, color: pb.muted)),
          ]);
          final head = Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: pb.line), borderRadius: BorderRadius.circular(14)),
              child: PIcon(sensor.icon, size: 16, color: pb.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sensor.name, style: body(12, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(sensor.source, style: body(10, color: pb.muted)),
              ]),
            ),
            value,
            if (!narrow) ...[const SizedBox(width: 12), check],
          ]);
          return Opacity(
            opacity: active ? 1 : .72,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: pb.line))),
              child: narrow
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: 12), check])
                  : head,
            ),
          );
        });

    Widget actuatorCard(Actuator a) => Opacity(
          opacity: active ? 1 : .72,
          child: PCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                StateIcon(a.isFan ? 'fan' : (a.relay ? 'power' : 'list')),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, style: body(12.5, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(a.note, style: body(10, color: pb.muted)),
                  ]),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (a.relay ? s.relays[a.id]! : s.lcdMessage.isNotEmpty) ? pb.accent : PB.tint(pb.muted, .45),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (a.relay)
                Row(children: [
                  PSwitch(
                    value: s.relays[a.id]!,
                    onChanged: active ? (_) => act(context, s.toggleRelay(a.id), '${a.name} command queued.') : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Muted('${a.offLabel} / ${a.onLabel}', size: 11, maxLines: 1)),
                ])
              else
                Row(children: [
                  Expanded(child: PField(_lcd, hint: 'Up to 16 characters', maxLength: 16, enabled: active)),
                  const SizedBox(width: 8),
                  PButton('Send',
                      onTap: active
                          ? () {
                              final msg = _lcd.text.trim();
                              if (msg.isEmpty) return;
                              _lcd.clear();
                              act(context, s.sendLcd(msg), 'Message queued for the LCD.');
                            }
                          : null),
                ]),
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: pb.line))),
                child: Row(children: [
                  Expanded(
                      child: Text(s.actuatorText(a), style: body(11.5, weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                        s.actuatorTs[a.id] == null ? 'No response recorded yet' : 'Responded ${relative(s.actuatorTs[a.id]!)}',
                        textAlign: TextAlign.right,
                        style: body(9.5, color: pb.muted)),
                  ),
                ]),
              ),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeading('I/O test bench', 'Maintenance', 'Check every sensor and drive every output device by hand.', actions: [
        PButton(
          active ? 'Resume auto operation' : 'Enter maintenance mode',
          icon: active ? 'activity' : 'sliders',
          primary: !active,
          onTap: () => act(context, s.setMode(active ? Mode.auto : Mode.maintenance),
              active ? 'Back to Auto.' : 'Maintenance mode on — automatic operation paused.'),
        ),
      ]),
      Banner2(
        icon: active ? 'sliders' : 'shield',
        title: active ? 'Automatic operation is paused' : 'Maintenance mode is off',
        detail: active
            ? 'The locker will not act on its own until you return to Auto.'
            : 'Enter maintenance mode before sending test commands to the hardware.',
        badge: active ? 'Paused' : 'Running',
        tone: active ? pb.modeMaintenance : null,
      ),
      SplitPane(
        breakpoint: 1000,
        firstFlex: 3,
        secondFlex: 2,
        first: PCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHead('Sensor check', 'Read each sensor on request',
                trailing: PButton('Check all',
                    icon: 'refresh',
                    height: 34,
                    onTap: active ? () => act(context, s.checkAll(), 'Read requested from every sensor.') : null)),
            const SizedBox(height: 12),
            for (final sensor in sensors) sensorRow(sensor),
          ]),
        ),
        second: PCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionHead('Input peripherals', 'Reader and keypad'),
            const SizedBox(height: 6),
            const Muted('Trigger the hardware — the last event shows up here.', size: 10.5),
            const SizedBox(height: 12),
            ...inputChips(s).expand((c) => [c, const SizedBox(height: 8)]),
          ]),
        ),
      ),
      const LiveHead('Cooling', 'Components hub',
          note: 'Test the fans below in maintenance mode. The threshold applies to automatic operation and can be changed any time.'),
      const ThermalCard(editable: true),
      const LiveHead('Actuator control', 'Output devices', note: 'Each control queues one command at commands/.'),
      RGrid(minItem: 280, maxCols: 3, spacing: 12, children: [for (final a in actuators) actuatorCard(a)]),
      const Note(
          'The app never writes live/ itself — the ESP switches the relay and writes the real state back, so what you see here is what the hardware did.'),
    ]);
  }
}

// ====================================================================== Sleep

const sleepHeadings = ['Sleep started', 'Woke at', 'Total duration', 'Status'];
List<List<String>> sleepRows(Store s) => [
      for (final r in s.sleepLog)
        [
          dateTime(r.start),
          r.wake != null ? dateTime(r.wake) : 'Still asleep',
          duration((r.wake ?? nowMs) - r.start),
          r.wake != null ? 'Completed' : 'In progress',
        ]
    ];

final logHeadings = ['Date & time', ...sensors.map((s) => s.name)];
List<List<String>> logRows(Store s) => [
      for (final r in s.logs) [dateTime(r.ts), ...sensors.map((x) => x.format(r.values[x.id]))]
    ];

class SleepPanel extends StatelessWidget {
  const SleepPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final asleep = s.asleep;
    final sc = pb.modeSleep;

    final closed = s.sleepLog.where((r) => r.wake != null).toList();
    final total = closed.fold<int>(0, (a, r) => a + r.wake! - r.start);
    final longest = closed.isEmpty ? null : closed.map((r) => r.wake! - r.start).reduce((a, b) => a > b ? a : b);

    final status = Row(children: [
      StateIcon(asleep ? 'moon' : 'sun', color: asleep ? sc : null, size: 40),
      const SizedBox(width: 15),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MICROCONTROLLER STATUS', style: body(8.5, color: pb.muted, spacing: .8)),
          const SizedBox(height: 5),
          Text(asleep ? 'Asleep' : 'Awake', style: display(21, color: asleep ? sc : null)),
          const SizedBox(height: 4),
          Muted(
              s.powerChangedAt == 0
                  ? 'No state change recorded yet'
                  : 'Changed ${relative(s.powerChangedAt)} · ${dateTime(s.powerChangedAt)}',
              size: 10.5),
        ]),
      ),
    ]);
    final sleepBtn = PButton('Sleep command',
        icon: 'moon', expand: true, onTap: asleep ? null : () => act(context, s.sleepCommand(), 'Sleep command sent.'));
    final wakeBtn = PButton('Wake command',
        icon: 'power',
        primary: true,
        expand: true,
        onTap: asleep ? () => act(context, s.wakeCommand(), 'Wake command sent — INT0 pulled low.') : null);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeading('Low power', 'Sleep control', 'Power the Arduino down and wake it through the ESP interrupt.',
          actions: [DbNote()]),
      // .sleep-panel
      PCard(
        padding: const EdgeInsets.all(20),
        border: asleep ? PB.mix(sc, .28, pb.line) : null,
        glow: asleep ? sc : pb.accent,
        glowAt: Alignment.topRight,
        glowOpacity: asleep ? .1 : .08,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth >= 640) {
              return Row(children: [
                Expanded(child: status),
                const SizedBox(width: 20),
                SizedBox(width: 170, child: sleepBtn),
                const SizedBox(width: 8),
                SizedBox(width: 170, child: wakeBtn),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              status,
              const SizedBox(height: 20),
              Row(children: [Expanded(child: sleepBtn), const SizedBox(width: 8), Expanded(child: wakeBtn)]),
            ]);
          }),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PIcon('wifi', size: 14, color: pb.muted),
            const SizedBox(width: 8),
            const Expanded(
              child: Muted(
                  'Only the Arduino sleeps. The ESP-01S stays awake to hold the database connection and pulls the '
                  'Arduino\'s INT0 pin low when a wake command arrives; the RTC keeps timestamps correct for rows '
                  'buffered while it was down.',
                  size: 10),
            ),
          ]),
        ]),
      ),
      gap14,
      SummaryStrip([
        ('Sleep periods', '${s.sleepLog.length}', 'Recorded in the database', null),
        ('Total time asleep', closed.isEmpty ? '—' : duration(total), 'Across completed periods', null),
        ('Longest period', longest == null ? '—' : duration(longest), 'Single sleep span', null),
        ('Most recent', s.sleepLog.isEmpty ? '—' : dateTime(s.sleepLog.first.start), 'Sleep start time', null),
      ]),
      LiveHead('Sleep log', 'Every period, start to wake',
          note: '${s.sleepLog.length} period${s.sleepLog.length == 1 ? '' : 's'} recorded'),
      PTable(sleepHeadings, sleepRows(s), empty: 'No sleep periods recorded yet. Send the sleep command to start one.'),
      LiveHead('Same dashboard as Auto', 'Last known readings',
          note: asleep ? 'Frozen — no live data arrives while the Arduino is powered down.' : 'Live — the Arduino is awake.'),
      const SensorTiles(),
      const SizedBox(height: 12),
      const DeviceChips(),
      gap14,
      const PCard(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHead('Advice', 'Recommendations'),
          SizedBox(height: 12),
          RecList(),
        ]),
      ),
    ]);
  }
}

// ================================================================== Data logs

class DataLogsPanel extends StatelessWidget {
  const DataLogsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final interval = logIntervals[s.logIntervalMs] ?? '3 minutes';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeading('Recorded history', 'Data logs', 'Sensor readings saved to the database every $interval.', actions: [
        const DbNote(),
        PButton('Log now', icon: 'refresh', onTap: () => act(context, s.logNow(), 'Reading logged.')),
        PButton('Export', icon: 'file', onTap: () => exportCsv(context, 'Data log', logHeadings, logRows(s))),
      ]),
      SummaryStrip([
        ('Rows retained', '${s.logs.length}', 'Newest 60 from the database', null),
        ('Log interval', interval.split(' ').first, 'Set in Settings → Logging', ' min'),
        (
          'Last entry',
          s.logs.isEmpty ? '—' : relative(s.logs.first.ts),
          s.logs.isEmpty ? 'Nothing logged yet' : dateTime(s.logs.first.ts),
          null
        ),
        ('Sensors per row', '${sensors.length}', 'From the device config', null),
      ]),
      PTable(logHeadings, logRows(s),
          statusLast: false, empty: 'No readings logged yet. Rows appear at each log interval once the device is publishing.'),
    ]);
  }
}

/// The website exports PDFs; on the phone we copy the table as CSV.
Future<void> exportCsv(BuildContext context, String name, List<String> headings, List<List<String>> rows) async {
  final csv = [headings, ...rows].map((r) => r.map((v) => '"${v.replaceAll('"', '""')}"').join(',')).join('\n');
  await copyText(csv);
  if (context.mounted) toast(context, '$name copied as CSV (${rows.length} rows).');
}
