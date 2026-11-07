import 'dart:math';

import 'package:flutter/material.dart';

import '../icons.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ================================================================= RFID cards

class RfidPanel extends StatefulWidget {
  const RfidPanel({super.key});
  @override
  State<RfidPanel> createState() => _RfidPanelState();
}

class _RfidPanelState extends State<RfidPanel> {
  String? _editing;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(Store s) async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final uid = _editing!;
    setState(() => _editing = null);
    await act(context, s.renameCard(uid, n), 'RFID card name saved.');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    const colors = ['green-card', 'dark-card', 'paper-card'];

    Widget cardTile(int index, RfidCard card) {
      final short = card.uid.length >= 4 ? card.uid.substring(card.uid.length - 4).toUpperCase() : card.uid;
      return Glass(
        radius: 24,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _CardVisual(color: card.color ?? colors[index % 3], short: short, active: card.active),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 16, 6, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_editing == card.uid)
                Row(children: [
                  Expanded(child: PField(_name, maxLength: 24, onSubmitted: (_) => _save(s))),
                  const SizedBox(width: 7),
                  PButton('Save', primary: true, onTap: () => _save(s)),
                ])
              else
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(card.name.isEmpty ? 'Unnamed card' : card.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(card.owner, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10.5, color: pb.muted)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () {
                      _name.text = card.name;
                      setState(() => _editing = card.uid);
                    },
                    child: Text('Rename', style: body(11.5, color: pb.accent, weight: FontWeight.w600)),
                  ),
                ]),
              Divider(color: pb.line, height: 24),
              Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: card.active ? pb.accent : pb.muted),
                ),
                const SizedBox(width: 7),
                Expanded(child: Text(card.active ? 'Active' : 'Disabled', style: body(11, color: pb.muted))),
                TextButton(
                  onPressed: () => act(context, s.toggleCard(card.uid), card.active ? 'Card disabled.' : 'Card enabled.'),
                  child: Text(card.active ? 'Disable' : 'Enable', style: body(11.5, weight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await confirm(context, 'Remove this card?', 'The reader will stop accepting ···$short.', 'Remove');
                    if (ok && context.mounted) await act(context, s.deleteCard(card.uid), 'Card removed.');
                  },
                  child: Text('Remove', style: body(11.5, color: pb.danger, weight: FontWeight.w600)),
                ),
              ]),
              Text('UID ${card.uid}${card.addedAt > 0 ? ' · added ${dateTime(card.addedAt)}' : ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: body(9.5, color: pb.muted)),
            ]),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeading('Access management', 'RFID cards', 'Cards the reader will accept, stored in the database as cards/<uid>.',
          actions: [
            PButton('+ Enroll a card',
                primary: true,
                onTap: () => act(context, s.enrollCard(), 'Reader in learn mode — tap the new card on PB-01.')),
          ]),
      if (s.cards.isEmpty)
        const PCard(
          padding: EdgeInsets.all(24),
          child: Muted(
              'No cards enrolled yet. Press Enroll a card, then tap the card on the reader — the ESP writes the UID it sees and it appears here.',
              align: TextAlign.center),
        )
      else
        RGrid(minItem: 270, maxCols: 3, spacing: 12, children: [
          for (final (i, c) in s.cards.indexed) cardTile(i, c),
        ]),
      const Note('Disabling a card keeps the UID on file but tells the reader to refuse it.', icon: 'card'),
    ]);
  }
}

class _CardVisual extends StatelessWidget {
  final String color, short;
  final bool active;
  const _CardVisual({required this.color, required this.short, required this.active});
  @override
  Widget build(BuildContext context) {
    final colors = switch (color) {
      'green-card' => [const Color(0xFF168B43), const Color(0xFF082D18)],
      'dark-card' => [const Color(0xFF2B2B2B), const Color(0xFF0E0E0E)],
      _ => [const Color(0xFF8A8378), const Color(0xFF3E3A34)],
    };
    return AspectRatio(
      aspectRatio: 1.58,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .17), blurRadius: 28, offset: const Offset(0, 18))],
        ),
        child: Stack(children: [
          Positioned(
            right: -110,
            bottom: -125,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .03)),
              alignment: Alignment.center,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .04)),
                alignment: Alignment.center,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .18))),
                ),
              ),
            ),
          ),
          const Positioned(left: 19, top: 19, child: Brand(size: 13, color: Color(0xFFE8E4DE))),
          Positioned(
            right: 22,
            top: 22,
            child: Transform.rotate(angle: pi / 2, child: const PIcon('wifi', size: 22, color: Color(0xCCE8E4DE))),
          ),
          Positioned(
            left: 19,
            bottom: 17,
            child: Text('•••• $short', style: display(13, color: const Color(0xFFE8E4DE), weight: FontWeight.w500, spacing: .15)),
          ),
          if (!active) Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .35))),
        ]),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String message, String action) async {
  final pb = context.pb;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: pb.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: pb.line)),
      title: Text(title, style: display(18)),
      content: Muted(message, size: 12.5),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: body(13, color: pb.muted))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: body(13, color: pb.danger, weight: FontWeight.w600))),
      ],
    ),
  );
  return ok ?? false;
}

// =================================================================== Settings

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final Store s = context.storeRead;
  late final _device = TextEditingController(text: s.deviceName);
  late final _location = TextEditingController(text: s.location);
  late int _lockDelay = [5, 10, 30].contains(s.autoLockSeconds) ? s.autoLockSeconds : 10;
  late final _ssid = TextEditingController(text: s.ssid);
  final _wifiPass = TextEditingController();
  late final _host = TextEditingController(text: s.hostname);
  late final _ip = TextEditingController(text: s.staticIp);
  late final _name = TextEditingController(text: s.accountName);

  @override
  void dispose() {
    for (final c in [_device, _location, _ssid, _wifiPass, _host, _ip, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;

    final box = _Section('Parcel box', note: 'Saved to config/ so the LCD and the logs use the same names.', rows: [
      _Row('Device name', 'Shown across your dashboard', PField(_device)),
      _Row('Location', 'Used for activity records', PField(_location)),
      _Row(
          'Auto-lock delay',
          'After the reed switch reports closed',
          PSelect<int>(
              value: _lockDelay,
              options: const {5: '5 seconds', 10: '10 seconds', 30: '30 seconds'},
              onChanged: (v) => setState(() => _lockDelay = v))),
      _Row(
          'Apply',
          'Writes straight to the database',
          PButton('Save box settings',
              primary: true,
              onTap: () => act(context, s.saveDevice(_device.text.trim(), _location.text.trim(), _lockDelay), 'Box settings saved.')),
          inline: true),
    ]);

    final logging = _Section('Logging & mode', rows: [
      _Row('Log interval', 'How often the device saves readings (3–5 minutes)',
          PSelect<int>(value: s.logIntervalMs, options: logIntervals, onChanged: (v) => act(context, s.setLogInterval(v), 'Log interval saved.'))),
      _Row(
          'Operating mode',
          'Written to mode for the device to read',
          PSelect<Mode>(
              value: s.mode,
              options: {for (final m in Mode.values) m: m.label},
              onChanged: (m) => act(context, s.setMode(m), 'Mode set to ${m.label}.'))),
      const _Row('Data source', 'Live stream from the Realtime Database', Align(alignment: Alignment.centerLeft, child: DbNote())),
    ]);

    final esp = _Section('ESP module',
        icon: 'wifi',
        note: 'Saved to config/wifi. The ESP reads these and reconnects — keep the current network reachable until it confirms.',
        rows: [
          _Row('Wi-Fi SSID', 'Network the ESP-01S joins', PField(_ssid, hint: 'MyNetwork')),
          _Row('Wi-Fi password', 'Stored in the database — keep your rules locked down',
              PField(_wifiPass, hint: '••••••••', obscure: true)),
          _Row('Hostname', 'mDNS name on your network', PField(_host, hint: 'parcelbonia-esp')),
          _Row('Static IP', 'Optional — leave blank for DHCP',
              PField(_ip, hint: '192.168.1.50', keyboard: const TextInputType.numberWithOptions(decimal: true))),
          _Row(
              'Apply changes',
              'Queues a reconnect command for the ESP',
              PButton('Save Wi-Fi settings', primary: true, onTap: () {
                if (_ssid.text.trim().isEmpty) return toast(context, 'Enter the Wi-Fi SSID first.');
                act(context, s.saveWifi(_ssid.text.trim(), _wifiPass.text, _host.text.trim(), _ip.text.trim()),
                    'Wi-Fi settings saved — the ESP will reconnect.');
                _wifiPass.clear();
              }),
              inline: true),
        ]);

    final notifs = _Section('Notifications', rows: [
      for (final (i, (n, d)) in [
        ('Delivery received', 'Alert when the IR sensor detects a parcel'),
        ('Security alerts', 'Failed keypad codes and reed-switch tampering'),
        ('Weekly summary', 'Delivery activity every Monday'),
      ].indexed)
        _Row(n, d, PSwitch(value: s.notifications[i], onChanged: (_) => act(context, s.toggleNotification(i), 'Preference saved.')),
            inline: true),
    ]);

    final account = _Section('Profile',
        note: 'Your display name is saved to account/profile so the device can read it.',
        rows: [
          _Row('Display name', 'Shown on the dashboard greeting', PField(_name, maxLength: 40)),
          _Row(
              'Save name',
              s.accountUpdatedAt == 0 ? 'Change it any time' : 'Last changed ${dateTime(s.accountUpdatedAt)}',
              PButton('Update name', primary: true, onTap: () {
                if (_name.text.trim().isEmpty) return;
                act(context, s.updateName(_name.text.trim()), 'Name updated.');
              }),
              inline: true),
        ],
        footer: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PB.tint(pb.danger, .05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PB.mix(pb.danger, .28, pb.line)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Reset device', style: body(12.5, weight: FontWeight.w600, color: pb.danger)),
                const SizedBox(height: 4),
                const Muted('Clear the access log, deliveries, data logs and sleep log', size: 10.5),
              ]),
              PButton('Reset PB-01', danger: true, onTap: () async {
                final ok = await confirm(context, 'Reset PB-01?',
                    'Clears the access log, delivery history, data logs and sleep log from the database. Cards and settings are kept.',
                    'Reset');
                if (ok && context.mounted) await act(context, s.resetDevice(), 'Device history cleared.');
              }),
            ],
          ),
        ));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeading('Device preferences', 'Settings', 'Configure your parcel box, logging, the ESP module, and your profile.'),
      SplitPane(breakpoint: 980, first: box, second: logging),
      gap14,
      SplitPane(breakpoint: 980, first: esp, second: notifs),
      gap14,
      account,
    ]);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? note, icon;
  final List<Widget> rows;
  final Widget? footer;
  const _Section(this.title, {required this.rows, this.note, this.icon, this.footer});
  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return PCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (icon != null) ...[PIcon(icon!, size: 15, color: pb.text), const SizedBox(width: 8)],
          Flexible(child: Text(title, style: display(15, spacing: -.02))),
        ]),
        if (note != null) ...[const SizedBox(height: 8), Muted(note!, size: 10.5)],
        const SizedBox(height: 12),
        ...rows,
        ?footer,
      ]),
    );
  }
}

/// `.setting-row` — label beside the control when there is room, stacked on
/// narrow phones. [inline] keeps small controls (switches, buttons) beside the label.
class _Row extends StatelessWidget {
  final String title, hint;
  final Widget control;
  final bool inline;
  const _Row(this.title, this.hint, this.control, {this.inline = false});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final label = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: body(12.5, weight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(hint, style: body(10.5, color: pb.muted)),
    ]);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: pb.line))),
      child: LayoutBuilder(builder: (context, c) {
        if (inline && c.maxWidth >= 300) {
          return Row(children: [Expanded(child: label), const SizedBox(width: 14), Flexible(child: control)]);
        }
        if (c.maxWidth >= 480) {
          return Row(children: [
            Expanded(child: label),
            const SizedBox(width: 18),
            SizedBox(width: (c.maxWidth * .48).clamp(180.0, 320.0), child: control),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [label, const SizedBox(height: 12), control]);
      }),
    );
  }
}
