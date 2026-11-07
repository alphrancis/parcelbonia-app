import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parcelbonia_app/screens/shell.dart';
import 'package:parcelbonia_app/store.dart';
import 'package:parcelbonia_app/theme.dart';
import 'package:parcelbonia_app/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every page at phone, tablet and desktop sizes and fails on any
/// overflow or layout exception.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  const sizes = {
    'small phone': Size(320, 640),
    'phone': Size(390, 844),
    'phone landscape': Size(844, 390),
    'tablet': Size(820, 1180),
    'desktop': Size(1440, 900),
  };

  for (final dark in [true, false]) {
    for (final entry in sizes.entries) {
      testWidgets('all pages lay out on ${entry.key} (${dark ? 'dark' : 'light'})', (tester) async {
        SharedPreferences.setMockInitialValues({'parcelbonia-theme': dark ? 'dark' : 'light'});
        final store = Store(await SharedPreferences.getInstance())
          ..phase = Phase.ready
          ..link = 'live'
          ..accountName = 'Rene Santos'
          ..email = 'rene@parcelbonia.com';
        _fill(store);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(StoreScope(
          store: store,
          child: MaterialApp(theme: buildTheme(dark), home: const Shell()),
        ));

        for (final (name, _) in navItems) {
          store.go(name);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          final ex = tester.takeException();
          // Name the offending widget so failures are easy to track down.
          if (ex is FlutterError) {
            for (final d in ex.diagnostics) {
              final text = d.toStringDeep();
              if (text.contains('creator:') || text.contains('RenderFlex#')) debugPrint(text);
            }
          }
          expect(ex, isNull, reason: '$name on ${entry.key}');
        }
        store.dispose();
      });
    }
  }
}

void _fill(Store s) {
  final t = nowMs;
  s.live
    ..['presence'] = Reading(1, t)
    ..['weight'] = Reading(1.31, t)
    ..['door'] = Reading(0, t)
    ..['battery'] = Reading(22, t)
    ..['temperature'] = Reading(41.6, t);
  s.relays['fanIntake'] = true;
  s.heartbeat = t;
  s.actuatorTs['lock'] = t;
  s.rfidInput = {'uid': '04A1B2A3F2', 'name': 'Rene’s card with a long name', 'ts': t};
  s.keypadInput = {'key': '#', 'result': 'Denied', 'ts': t};
  s.lcdMessage = 'Welcome home';
  s.logs = [for (var i = 0; i < 8; i++) LogRow('k$i', t - i * 180000, {'presence': 1, 'weight': 1.3, 'door': 0, 'battery': 90}, null)];
  s.sleepLog = [SleepRow('a', t - 9000000, t - 5000000), SleepRow('b', t - 1000, null)];
  s.cards = [
    RfidCard('04A1B2A3F2', 'Rene’s card', 'Rene · Owner', 'green-card', true, t),
    RfidCard('04C9D07B21', 'Maya’s card', 'Maya Perez · Family', null, false, t),
  ];
  s.access = [AccessRow(t, 'Owner retrieval', 'Rene', 'RFID ···A3F2', 'Granted'), AccessRow(t, 'Keypad attempt', 'Unknown', 'Keypad', 'Denied')];
  s.deliveries = [Delivery(t, '#PB-1047', 'Rider #4821', 1.31, 'In box'), Delivery(t, '#PB-1046', 'J&T Express', null, 'Collected')];
}
