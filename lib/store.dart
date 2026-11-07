import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';
import 'rtdb.dart';

/// App state, mirrored live from devices/PB-01 in the Realtime Database.
/// Paths and shapes match the website (data/device-config.js, data/rtdb.js)
/// and the ESP firmware, so all three stay in sync.

enum Mode { auto, maintenance, sleep }

extension ModeCopy on Mode {
  String get label => const ['Auto', 'Maintenance', 'Sleep'][index];
  String get blurb => const [
        'The locker runs on its own and streams live readings.',
        'Automatic operation is paused for I/O testing.',
        'The Arduino is powered down; the ESP stays online for commands.',
      ][index];
  String get icon => const ['activity', 'sliders', 'moon'][index];
  String get key => const ['AUTO', 'MAINTENANCE', 'SLEEP'][index];
}

class Sensor {
  final String id, name, unit, icon, source;
  final List<String>? states;
  final int decimals;
  final double? max, min;
  final int? safe;
  const Sensor(this.id, this.name, this.icon, this.source,
      {this.unit = '', this.states, this.decimals = 0, this.max, this.min, this.safe});
  bool get isState => states != null;

  String format(Object? v) {
    if (v == null || v == '') return '—';
    if (isState) {
      final on = v == true || (num.tryParse('$v') ?? 0) != 0;
      return states![on ? 1 : 0];
    }
    final n = num.tryParse('$v');
    if (n == null) return '$v';
    return '${n.toStringAsFixed(decimals)}${unit.isEmpty ? '' : ' $unit'}';
  }
}

const sensors = [
  Sensor('presence', 'Parcel presence', 'package', 'IR sensor', states: ['Empty', 'Occupied']),
  Sensor('weight', 'Load cell', 'weight', 'Load sensor', unit: 'kg', decimals: 2, max: 10),
  Sensor('door', 'Door switch', 'shield', 'Magnetic reed switch', states: ['Closed', 'Open'], safe: 0),
  Sensor('battery', 'Battery', 'grid', 'Analog pin', unit: '%', min: 25),
  Sensor('temperature', 'Hub temperature', 'thermo', 'RTC module sensor · components hub', unit: '°C', decimals: 1),
];

/// Sensors shown as tiles on the dashboard (hub temperature has its own card).
final tileSensors = sensors.where((s) => s.id != 'temperature').toList();

class Actuator {
  final String id, name, note;
  final bool relay;
  final String onLabel, offLabel;
  const Actuator(this.id, this.name, this.note, {this.relay = true, this.onLabel = 'On', this.offLabel = 'Off'});
  bool get isFan => id == 'fans';
}

const actuators = [
  Actuator('lock', 'Solenoid lock', 'Relay channel 1 · momentary unlock', onLabel: 'Unlocked', offLabel: 'Locked'),
  Actuator('led', 'Interior LED', 'Relay channel 2 · on/off only'),
  Actuator('lcd', '16x2 LCD', 'Writes one line to the display', relay: false),
  // Intake and exhaust fans are wired to the same relay, so they always run together.
  Actuator('fans', 'Cooling fans', 'Relay channel 3 · intake + exhaust run together', onLabel: 'Running', offLabel: 'Stopped'),
];

/// Fan threshold limits the app allows (°C).
const fanThresholdMin = 25.0, fanThresholdMax = 60.0;

/// Scale used for the hub temperature gauge (°C).
const hubGaugeMax = 70.0;

const logIntervals = {180000: '3 minutes', 240000: '4 minutes', 300000: '5 minutes'};

class Reading {
  final Object? value;
  final int ts;
  Reading(this.value, this.ts);
}

class LogRow {
  final String key;
  final int ts;
  final Map<String, Object?> values;
  final String? event;
  LogRow(this.key, this.ts, this.values, this.event);
}

class SleepRow {
  final String key;
  final int start;
  final int? wake;
  SleepRow(this.key, this.start, this.wake);
}

class RfidCard {
  final String uid, name, owner;
  final String? color;
  final bool active;
  final int addedAt;
  RfidCard(this.uid, this.name, this.owner, this.color, this.active, this.addedAt);
}

class AccessRow {
  final int ts;
  final String event, person, method, result;
  AccessRow(this.ts, this.event, this.person, this.method, this.result);
}

class Delivery {
  final int ts;
  final String parcelId, courier, status;
  final double? weight;
  Delivery(this.ts, this.parcelId, this.courier, this.weight, this.status);
}

class Rec {
  final String level, icon, title, detail;
  const Rec(this.level, this.icon, this.title, this.detail);
}

enum Phase { booting, ready }

int get nowMs => DateTime.now().millisecondsSinceEpoch;

/// Accepts epoch ms, epoch seconds (ESP RTC) or numeric strings.
int toMs(Object? v) {
  final n = num.tryParse('${v ?? ''}')?.toInt() ?? 0;
  if (n <= 0) return 0;
  return n < 100000000000 ? n * 1000 : n;
}

Map<String, dynamic> asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Firebase returns push-lists as maps; arrays when keys are 0..n.
Iterable<MapEntry<String, dynamic>> entries(Object? v) {
  if (v is Map) return v.entries.map((e) => MapEntry('${e.key}', e.value));
  if (v is List) return v.asMap().entries.where((e) => e.value != null).map((e) => MapEntry('${e.key}', e.value));
  return const [];
}

class Store extends ChangeNotifier {
  Store(this._prefs) : auth = Auth(_prefs) {
    db = Rtdb(auth)..onLink = _onLink;
    dark = _prefs.getString('parcelbonia-theme') != 'light';
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      now = nowMs;
      notifyListeners();
    });
  }

  final SharedPreferences _prefs;
  final Auth auth;
  late final Rtdb db;
  late final Timer _ticker;

  // ---- app / UI
  Phase phase = Phase.booting;
  late bool dark;
  String panel = 'Overview';
  bool unlocking = false;
  int now = nowMs;

  // ---- database link
  String link = 'connecting'; // connecting | waiting | live | error | signed-out
  String? linkError;
  bool firstSnapshot = false;

  // ---- account
  String accountName = 'Owner', email = '';
  int accountUpdatedAt = 0;

  // ---- devices/PB-01
  Mode mode = Mode.auto;
  final Map<String, Reading> live = {};
  final Map<String, bool> relays = {'lock': false, 'led': false, 'fans': false};
  final Map<String, int> actuatorTs = {};
  String lcdMessage = '';
  Map<String, dynamic> rfidInput = {}, keypadInput = {};
  int heartbeat = 0;
  bool awake = true;
  int powerChangedAt = 0;
  List<LogRow> logs = [];
  List<SleepRow> sleepLog = [];
  List<RfidCard> cards = [];
  List<AccessRow> access = [];
  List<Delivery> deliveries = [];
  String deviceName = 'Home Parcel Box', location = 'Bacolor, Philippines';
  int autoLockSeconds = 10, logIntervalMs = 180000;
  String ssid = '', wifiPassword = '', hostname = 'parcelbonia-esp', staticIp = '';
  List<bool> notifications = [true, true, false];

  // ---- components hub cooling (config/fan)
  /// Fans switch on at [fanThreshold] and off again [fanHysteresis] °C below it.
  double fanThreshold = 40, fanHysteresis = 3;

  bool get asleep => mode == Mode.sleep || !awake;
  bool get lockOpen => relays['lock'] ?? false;
  bool get hasReadings => sensors.any((s) => live[s.id]?.value != null);
  String get firstName => accountName.trim().split(RegExp(r'\s+')).first;
  String get initials {
    final w = accountName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2);
    final s = w.map((x) => x[0]).join().toUpperCase();
    return s.isEmpty ? 'PB' : s;
  }

  // ------------------------------------------------------------ session

  /// Called by the splash screen: restore the saved session (or create an
  /// anonymous one) and open the streams. There is no login screen.
  Future<void> boot() async {
    try {
      await _ensureSession();
      _startSession();
      // Give the first snapshot a moment so the dashboard opens filled in.
      final until = DateTime.now().add(const Duration(seconds: 4));
      while (!firstSnapshot && DateTime.now().isBefore(until)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      // Offline or auth unavailable: open the dashboard anyway and keep retrying.
      phase = Phase.ready;
      link = 'error';
      linkError = '$e';
      _retryAuthLater();
    }
    notifyListeners();
  }

  Future<void> _ensureSession() async {
    if (auth.hasSavedSession) {
      try {
        await auth.restore();
        return;
      } on AuthError {
        // Saved session no longer valid: fall through to a fresh one.
      }
    }
    await auth.signInAnonymously();
  }

  Timer? _authRetry;
  void _retryAuthLater() {
    _authRetry?.cancel();
    _authRetry = Timer(const Duration(seconds: 10), () async {
      try {
        await _ensureSession();
        _startSession();
      } catch (_) {
        _retryAuthLater();
      }
    });
  }

  /// The token was rejected: silently get a new session instead of showing a login.
  void _reauth() {
    db.closeAll();
    auth.signOut();
    firstSnapshot = false;
    link = 'connecting';
    notifyListeners();
    _ensureSession().then((_) => _startSession()).catchError((_) => _retryAuthLater());
  }

  void _startSession() {
    final s = auth.session!;
    email = s.email;
    if (s.displayName != null) accountName = s.displayName!;
    _authRetry?.cancel();
    phase = Phase.ready;
    link = 'connecting';
    _attach();
    notifyListeners();
  }

  void _onLink(String state, [String? error]) {
    if (state == 'signed-out') return _reauth();
    if (state == 'live' && link == 'live') return;
    link = state;
    linkError = error;
    notifyListeners();
  }

  /// Resume after the app was in the background.
  void resume() {
    if (phase == Phase.ready) db.reconnect();
  }

  // ------------------------------------------------------------ listeners

  void _attach() {
    db.closeAll();
    void on(String path, void Function(dynamic) f, {int? limit}) => db.listen(path, (v) {
          f(v);
          firstSnapshot = true;
          notifyListeners();
        }, limitToLast: limit);

    on('$deviceRoot/mode', (v) {
      mode = Mode.values.firstWhere((m) => m.key == '$v'.toUpperCase(), orElse: () => mode);
    });
    on('$deviceRoot/live', (v) {
      final m = asMap(v);
      live.clear();
      for (final e in asMap(m['sensors']).entries) {
        final slot = e.value is Map ? asMap(e.value) : {'value': e.value};
        live[e.key] = Reading(slot['value'], toMs(slot['ts']));
      }
      final acts = asMap(m['actuators']);
      for (final a in actuators) {
        final slot = asMap(acts[a.id]);
        if (a.relay) relays[a.id] = slot['state'] == true || slot['state'] == 1;
        if (a.id == 'lcd') lcdMessage = '${slot['message'] ?? ''}';
        if (slot['ts'] != null) actuatorTs[a.id] = toMs(slot['ts']);
      }
      final inputs = asMap(m['inputs']);
      rfidInput = asMap(inputs['rfid']);
      keypadInput = asMap(inputs['keypad']);
      heartbeat = toMs(m['heartbeat']);
    });
    on('$deviceRoot/power', (v) {
      final p = asMap(v);
      awake = p['awake'] != false;
      powerChangedAt = toMs(p['changedAt']);
    });
    on('$deviceRoot/config', (v) {
      final c = asMap(v);
      deviceName = '${c['deviceName'] ?? deviceName}';
      location = '${c['location'] ?? location}';
      autoLockSeconds = (num.tryParse('${c['autoLockSeconds']}') ?? autoLockSeconds).toInt();
      final li = (num.tryParse('${c['logIntervalMs']}') ?? logIntervalMs).toInt();
      logIntervalMs = logIntervals.containsKey(li) ? li : 180000;
      final w = asMap(c['wifi']);
      ssid = '${w['ssid'] ?? w['connectedSsid'] ?? ssid}';
      hostname = '${w['hostname'] ?? hostname}';
      staticIp = '${w['staticIp'] ?? staticIp}';
      final fan = asMap(c['fan']);
      fanThreshold = (num.tryParse('${fan['thresholdC']}') ?? fanThreshold).toDouble();
      fanHysteresis = (num.tryParse('${fan['hysteresisC']}') ?? fanHysteresis).toDouble();
      if (c['notifications'] is List) {
        final n = (c['notifications'] as List).map((x) => x == true).toList();
        notifications = [for (var i = 0; i < 3; i++) i < n.length ? n[i] : false];
      }
    });
    on('account/profile', (v) {
      final p = asMap(v);
      if ((p['name'] ?? '').toString().isNotEmpty) accountName = '${p['name']}';
      accountUpdatedAt = toMs(p['updatedAt']);
    });
    on('$deviceRoot/cards', (v) {
      cards = [
        for (final e in entries(v))
          RfidCard(
            e.key,
            '${asMap(e.value)['name'] ?? ''}',
            '${asMap(e.value)['owner'] ?? 'Unassigned'}',
            asMap(e.value)['color'] as String?,
            asMap(e.value)['active'] != false,
            toMs(asMap(e.value)['addedAt']),
          )
      ]..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    });
    on('$deviceRoot/logs', (v) {
      logs = [
        for (final e in entries(v))
          if (e.value is Map)
            LogRow(e.key, toMs(asMap(e.value)['ts']), asMap(asMap(e.value)['sensors']),
                asMap(e.value)['event'] == null ? null : '${asMap(e.value)['event']} ${asMap(e.value)['value'] ?? ''}'.trim())
      ]..sort((a, b) => b.ts.compareTo(a.ts));
    }, limit: 60);
    on('$deviceRoot/sleepLog', (v) {
      sleepLog = [
        for (final e in entries(v))
          if (e.value is Map)
            SleepRow(e.key, toMs(asMap(e.value)['start']),
                toMs(asMap(e.value)['wake'] ?? asMap(e.value)['end']) == 0 ? null : toMs(asMap(e.value)['wake'] ?? asMap(e.value)['end']))
      ]..sort((a, b) => b.start.compareTo(a.start));
    }, limit: 30);
    on('$deviceRoot/access', (v) {
      access = [
        for (final e in entries(v))
          if (e.value is Map) _accessRow(asMap(e.value))
      ]..sort((a, b) => b.ts.compareTo(a.ts));
    }, limit: 50);
    on('$deviceRoot/deliveries', (v) {
      deliveries = [
        for (final e in entries(v))
          if (e.value is Map)
            Delivery(
              toMs(asMap(e.value)['ts']),
              '${asMap(e.value)['parcelId'] ?? '#${e.key.substring(e.key.length > 6 ? e.key.length - 6 : 0)}'}',
              '${asMap(e.value)['courier'] ?? 'Unknown'}',
              num.tryParse('${asMap(e.value)['weight']}')?.toDouble(),
              '${asMap(e.value)['status'] ?? 'In box'}',
            )
      ]..sort((a, b) => b.ts.compareTo(a.ts));
    }, limit: 50);
  }

  /// The website writes {event, person, method, result}; the ESP writes
  /// {uid, name, method, granted}. Accept both.
  AccessRow _accessRow(Map<String, dynamic> r) {
    final granted = r['result'] != null ? r['result'] != 'Denied' : r['granted'] != false;
    final uid = '${r['uid'] ?? ''}';
    return AccessRow(
      toMs(r['ts']),
      '${r['event'] ?? (granted ? 'Owner retrieval' : 'Access attempt')}',
      '${r['person'] ?? r['name'] ?? 'Unknown'}',
      '${r['method'] ?? 'RFID'}${r['method'] == 'RFID' && uid.length >= 4 ? ' ···${uid.substring(uid.length - 4).toUpperCase()}' : ''}',
      '${r['result'] ?? (granted ? 'Granted' : 'Denied')}',
    );
  }

  // ------------------------------------------------------------ writes
  // Every action returns null on success or an error message.

  Future<String?> _try(Future<void> Function() f) async {
    try {
      await f();
      return null;
    } catch (e) {
      return '$e'.replaceFirst('Exception: ', '');
    }
  }

  Future<void> _command(String type, String target, [Object? value]) => db.push('$deviceRoot/commands', {
        'type': type,
        'target': target,
        'value': value,
        'ts': nowMs,
        'status': 'pending',
        'by': 'mobile-app',
      });

  void toggleTheme() {
    dark = !dark;
    _prefs.setString('parcelbonia-theme', dark ? 'dark' : 'light');
    notifyListeners();
  }

  void go(String p) {
    panel = p;
    notifyListeners();
  }

  Future<String?> setMode(Mode m) async {
    if (m == mode) return null;
    final wasAsleep = asleep;
    if (m == Mode.sleep && !wasAsleep) return sleepCommand();
    if (m != Mode.sleep && wasAsleep) {
      final err = await wakeCommand();
      if (err != null || m == Mode.auto) return err;
    }
    final prev = mode;
    mode = m;
    notifyListeners();
    final err = await _try(() => db.put('$deviceRoot/mode', m.key));
    if (err != null) {
      mode = prev;
      notifyListeners();
    }
    return err;
  }

  Future<String?> sleepCommand() => _try(() async {
        final t = nowMs;
        mode = Mode.sleep;
        awake = false;
        notifyListeners();
        await db.put('$deviceRoot/mode', 'SLEEP');
        await db.merge('$deviceRoot/power', {'awake': false, 'changedAt': t, 'reason': 'mobile-app'});
        await db.push('$deviceRoot/sleepLog', {'start': t});
        await _command('sleep', 'arduino');
      });

  Future<String?> wakeCommand() => _try(() async {
        final t = nowMs;
        mode = Mode.auto;
        awake = true;
        notifyListeners();
        await db.put('$deviceRoot/mode', 'AUTO');
        await db.merge('$deviceRoot/power', {'awake': true, 'changedAt': t, 'reason': 'mobile-app'});
        final open = sleepLog.where((r) => r.wake == null).firstOrNull;
        if (open != null) {
          await db.merge('$deviceRoot/sleepLog/${open.key}', {'wake': t, 'duration': t - open.start});
        }
        await _command('wake', 'arduino');
      });

  /// Remote unlock: queue a set-state command; the ESP pulses the relay and
  /// writes the real lock state back to live/actuators/lock.
  Future<String?> unlock() async {
    if (unlocking || asleep) return null;
    unlocking = true;
    notifyListeners();
    final err = await _try(() => _command('set-state', 'lock', true));
    Future.delayed(const Duration(milliseconds: 2400), () {
      unlocking = false;
      notifyListeners();
    });
    return err;
  }

  Future<String?> toggleRelay(String id) => _try(() => _command('set-state', id, !(relays[id] ?? false)));
  Future<String?> sendLcd(String msg) => _try(() => _command('message', 'lcd', msg));
  Future<String?> checkSensor(String id) => _try(() => _command('read-sensor', id));
  Future<String?> checkAll() => _try(() async {
        for (final s in sensors) {
          await _command('read-sensor', s.id);
        }
      });

  Future<String?> logNow() => _try(() => db.push('$deviceRoot/logs', {
        'ts': nowMs,
        'sensors': {for (final s in sensors) s.id: live[s.id]?.value},
        'source': 'mobile-app',
      }));

  /// The ESP turns both fans on at the threshold and off at threshold − hysteresis.
  Future<String?> setFanThreshold(double celsius) => _try(() async {
        final t = (celsius * 2).round() / 2;
        await db.merge('$deviceRoot/config/fan', {'thresholdC': t, 'hysteresisC': fanHysteresis, 'updatedAt': nowMs});
        fanThreshold = t;
        notifyListeners();
      });

  Future<String?> setLogInterval(int ms) => _try(() => db.merge('$deviceRoot/config', {'logIntervalMs': ms}));

  Future<String?> toggleCard(String uid) =>
      _try(() => db.merge('$deviceRoot/cards/$uid', {'active': !cards.firstWhere((c) => c.uid == uid).active}));
  Future<String?> renameCard(String uid, String name) => _try(() => db.merge('$deviceRoot/cards/$uid', {'name': name}));
  Future<String?> deleteCard(String uid) => _try(() => db.remove('$deviceRoot/cards/$uid'));

  /// The ESP puts the reader in learn mode and writes the next UID it sees.
  Future<String?> enrollCard() => _try(() => _command('enroll-card', 'rfid'));

  Future<String?> saveDevice(String name, String loc, int lockDelay) => _try(() =>
      db.merge('$deviceRoot/config', {'deviceName': name, 'location': loc, 'autoLockSeconds': lockDelay}));

  Future<String?> saveWifi(String s, String p, String h, String ip) => _try(() async {
        await db.merge('$deviceRoot/config/wifi', {'ssid': s, 'password': p, 'hostname': h, 'staticIp': ip});
        await _command('reconnect-wifi', 'esp');
      });

  Future<String?> updateName(String name) => _try(() async {
        await auth.updateName(name);
        await db.merge('account/profile', {'name': name, 'updatedAt': nowMs});
        accountName = name;
        notifyListeners();
      });

  Future<String?> toggleNotification(int i) {
    final next = [...notifications]..[i] = !notifications[i];
    notifications = next;
    notifyListeners();
    return _try(() => db.merge('$deviceRoot/config', {'notifications': next}));
  }

  /// Same as the website: clears history, keeps cards and settings.
  Future<String?> resetDevice() => _try(() async {
        for (final p in ['access', 'deliveries', 'logs', 'sleepLog']) {
          await db.remove('$deviceRoot/$p');
        }
      });

  // ------------------------------------------------------- derived copy

  String lockerStatus() {
    if (asleep) return 'Asleep — awaiting wake';
    if (sensors[2].format(live['door']?.value) == 'Open') return 'Door open';
    if (!actuatorTs.containsKey('lock') && !hasReadings) return 'Waiting for the device';
    return lockOpen ? 'Unlocked' : 'Locked & secure';
  }

  String heartbeatLine() {
    if (asleep) return 'Stream paused — Arduino is in SLEEP_MODE_PWR_DOWN';
    return heartbeat > 0 ? 'Last packet ${clockTime(heartbeat)}' : 'Waiting for the first packet from the ESP';
  }

  String connectionText() => switch (link) {
        'live' => 'Realtime Database · synced ${relative(db.lastSync)}',
        'waiting' => 'Connected · waiting for the device',
        'error' => linkError ?? 'Database error',
        'signed-out' => 'Signed out — sign in to stream data',
        _ => 'Connecting to Realtime Database…',
      };

  String sensorValue(Sensor s) => asleep ? '—' : s.format(live[s.id]?.value);

  String sensorTime(Sensor s) {
    if (asleep) return 'No data while asleep';
    final r = live[s.id];
    return r == null || r.ts == 0 ? 'Awaiting first reading' : 'Updated ${relative(r.ts)}';
  }

  String actuatorText(Actuator a) {
    if (!a.relay) return lcdMessage.isEmpty ? 'No message sent' : '"$lcdMessage"';
    if (!actuatorTs.containsKey(a.id)) return 'Unknown';
    return (relays[a.id] ?? false) ? a.onLabel : a.offLabel;
  }

  // ------------------------------------------------------------ cooling

  double? get hubTemp => asleep ? null : (num.tryParse('${live['temperature']?.value ?? ''}'))?.toDouble();
  bool get fansOn => relays['fans'] ?? false;

  /// ok | warm (within 3 °C of the threshold) | hot (at/over it) | none
  String get hubLevel {
    final t = hubTemp;
    if (t == null) return 'none';
    if (t >= fanThreshold) return 'hot';
    if (t >= fanThreshold - 3) return 'warm';
    return 'ok';
  }

  String get hubStatus => switch (hubLevel) {
        'hot' => fansOn ? 'Cooling' : 'Over threshold',
        'warm' => fansOn ? 'Cooling down' : 'Warming up',
        'ok' => fansOn ? 'Fans running' : 'Normal',
        _ => asleep ? 'Asleep' : 'No reading',
      };

  int get rfidTs => toMs(rfidInput['ts']);
  int get keypadTs => toMs(keypadInput['ts']);

  String rfidText() {
    if (rfidInput.isEmpty) return 'No event yet';
    final uid = '${rfidInput['uid'] ?? ''}';
    final short = uid.length >= 4 ? '···${uid.substring(uid.length - 4).toUpperCase()}' : 'unknown card';
    final name = '${rfidInput['name'] ?? ''}';
    return name.isEmpty ? short : '$name · $short';
  }

  String keypadText() {
    if (keypadInput.isEmpty) return 'No event yet';
    final r = keypadInput['result'], k = keypadInput['key'];
    return r != null ? '$r${k != null ? ' · key $k' : ''}' : 'Key ${k ?? '—'}';
  }

  List<Rec> recommendations() {
    if (asleep) {
      return const [
        Rec('info', 'moon', 'Microcontroller is asleep',
            'Live readings resume after you send the wake command. The RTC keeps logging on the ESP.')
      ];
    }
    if (link == 'error') return [Rec('alert', 'shield', 'Database error', linkError ?? 'The app could not read the Realtime Database.')];
    if (!hasReadings) {
      return const [
        Rec('info', 'activity', 'Waiting for the device',
            'No readings have been published yet. Recommendations appear as soon as the ESP writes to live/sensors.')
      ];
    }
    final out = <Rec>[];
    const advice = {
      'weight': 'The load cell is near its rated limit. Collect the parcels.',
      'battery': 'Battery is running down. Charge or swap the pack soon.',
      'door': 'The door is open. Close it so the locker can re-arm.',
      'presence': 'A parcel is waiting inside. Collect it to free the locker.',
      'temperature': '',
    };
    for (final s in sensors) {
      final raw = live[s.id]?.value;
      if (raw == null) continue;
      final shown = s.format(raw);
      if (s.isState) {
        final on = shown == s.states![1] ? 1 : 0;
        if (s.safe != null && on != s.safe) {
          out.add(Rec('alert', 'shield', '${s.name}: $shown', advice[s.id]!));
        } else if (on == 1 && s.safe == null) {
          out.add(Rec('info', 'package', '${s.name}: $shown', advice[s.id]!));
        }
        continue;
      }
      final n = num.tryParse('$raw');
      if (n == null) continue;
      if (s.max != null && n > s.max! * .85) {
        final over = n > s.max!;
        out.add(Rec(over ? 'alert' : 'warn', s.icon, '${s.name} ${over ? 'above' : 'near'} its limit — $shown', advice[s.id]!));
      } else if (s.min != null && n < s.min!) {
        out.add(Rec('warn', s.icon, '${s.name} below ${s.min!.toInt()}${s.unit} — $shown', advice[s.id]!));
      }
    }
    final t = hubTemp;
    if (t != null && t >= fanThreshold) {
      out.add(fansOn
          ? Rec('warn', 'fan', 'Components hub at ${t.toStringAsFixed(1)} °C — fans cooling',
              'Above the ${fanThreshold.toStringAsFixed(1)} °C threshold. Intake and exhaust fans are running.')
          : Rec('alert', 'thermo', 'Components hub at ${t.toStringAsFixed(1)} °C — fans not running',
              'The hub is over its threshold but the fans are off. Check them in Maintenance.'));
    }
    if (heartbeat > 0 && nowMs - heartbeat > 120000) {
      out.add(const Rec('alert', 'shield', 'No data for over two minutes', 'Check the ESP Wi-Fi connection in Settings → ESP module.'));
    }
    if (mode == Mode.maintenance) {
      out.insert(0, const Rec('warn', 'settings', 'Maintenance mode is active', 'Automatic operation is paused. Return to Auto when testing is done.'));
    }
    if (out.isEmpty) out.add(const Rec('ok', 'shield', 'All readings within range', 'No action needed — the locker is operating normally.'));
    return out;
  }

  @override
  void dispose() {
    _ticker.cancel();
    _authRetry?.cancel();
    db.closeAll();
    super.dispose();
  }
}

// ------------------------------------------------------------ formatting
// Same output as components/format.js.

String _two(int n) => n.toString().padLeft(2, '0');
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String hm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h)}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String clockTime(int ts) {
  if (ts == 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h)}:${_two(d.minute)}:${_two(d.second)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String dateTime(int? ts) {
  if (ts == null || ts == 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final t = DateTime.now();
  final same = d.year == t.year && d.month == t.month && d.day == t.day;
  return '${same ? 'Today' : '${_months[d.month - 1]} ${d.day}'}, ${hm(d)}';
}

String relative(int ts) {
  if (ts == 0) return 'never';
  final secs = ((nowMs - ts) / 1000).round();
  if (secs < 5) return 'just now';
  if (secs < 60) return '${secs}s ago';
  if (secs < 3600) return '${(secs / 60).round()}m ago';
  if (secs < 86400) return '${(secs / 3600).round()}h ago';
  return '${(secs / 86400).round()}d ago';
}

String duration(int ms) {
  final total = (ms / 1000).round();
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
