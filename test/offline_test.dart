import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parcelbonia_app/connection_banner.dart';
import 'package:parcelbonia_app/store.dart';
import 'package:parcelbonia_app/theme.dart';
import 'package:parcelbonia_app/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('commands made offline are queued, persisted and reported as queued', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = Store(prefs); // no session yet = offline

    expect(await s.unlock(), kQueued);
    expect(s.pendingWrites, 1);

    // Survives an app restart.
    final queued = jsonDecode(prefs.getString('pb-write-queue')!) as List;
    expect(queued.single['p'], 'devices/PB-01/commands');
    expect(Store(prefs).pendingWrites, 1);
    s.dispose();
  });

  test('mode change offline keeps the new mode instead of reverting', () async {
    SharedPreferences.setMockInitialValues({});
    final s = Store(await SharedPreferences.getInstance());
    expect(await s.setMode(Mode.maintenance), kQueued);
    expect(s.mode, Mode.maintenance);
    s.dispose();
  });

  test('cached snapshots are replayed to listeners immediately', () async {
    SharedPreferences.setMockInitialValues({'pb-cache:devices/PB-01/mode': jsonEncode('MAINTENANCE')});
    final s = Store(await SharedPreferences.getInstance());
    dynamic got;
    s.db.listen('devices/PB-01/mode', (v) => got = v);
    expect(got, 'MAINTENANCE');
    s.db.closeAll();
    s.dispose();
  });

  testWidgets('offline banner waits 2 s before showing and hides when back online', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = Store(await SharedPreferences.getInstance())..link = 'offline';
    await tester.pumpWidget(StoreScope(
      store: s,
      child: MaterialApp(theme: buildTheme(true), home: const Scaffold(body: ConnectionBanner())),
    ));

    expect(find.textContaining('Offline'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('Offline'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Offline'), findsOneWidget);

    s.link = 'live';
    s.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Offline'), findsNothing);
    s.dispose();
  });
}
