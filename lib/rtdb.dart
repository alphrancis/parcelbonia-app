import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';

/// Firebase Auth (email/password) + Realtime Database over REST and
/// Server-Sent Events — the same protocol the ESP firmware uses, so it works
/// on Android, iOS and desktop without any google-services files.

class AuthError implements Exception {
  final String message;
  AuthError(this.message);
  @override
  String toString() => message;
}

class Session {
  String idToken, refreshToken, uid, email;
  String? displayName;
  DateTime expiresAt;
  Session(this.idToken, this.refreshToken, this.uid, this.email, this.expiresAt, [this.displayName]);
}

class Auth {
  Auth(this._prefs);
  final SharedPreferences _prefs;
  Session? session;
  Future<Session>? _refreshing;

  static const _kRefresh = 'pb-refresh-token', _kEmail = 'pb-email', _kUid = 'pb-uid';

  bool get hasSavedSession => _prefs.getString(_kRefresh) != null;

  Future<Session> signIn(String email, String password) async {
    final res = await _post(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$firebaseApiKey',
      {'email': email, 'password': password, 'returnSecureToken': true},
    );
    final s = Session(res['idToken'], res['refreshToken'], res['localId'], res['email'] ?? email,
        _expiry(res['expiresIn']), (res['displayName'] as String?)?.isEmpty == true ? null : res['displayName']);
    _save(s);
    return session = s;
  }

  /// Signs in without credentials (Firebase anonymous auth) so the database
  /// rules (`auth != null`) are satisfied without a login screen. The refresh
  /// token is saved, so the same anonymous user is reused on every launch.
  Future<Session> signInAnonymously() async {
    final res = await _post(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseApiKey',
      {'returnSecureToken': true},
    );
    final s = Session(res['idToken'], res['refreshToken'], res['localId'], '', _expiry(res['expiresIn']));
    _save(s);
    return session = s;
  }

  /// Restores the saved session (Firebase keeps you signed in the same way).
  Future<Session?> restore() async {
    final rt = _prefs.getString(_kRefresh);
    if (rt == null) return null;
    session = Session('', rt, _prefs.getString(_kUid) ?? '', _prefs.getString(_kEmail) ?? '', DateTime(2000));
    try {
      await token(force: true);
      await _lookup();
      return session;
    } on AuthError {
      signOut();
      rethrow;
    }
  }

  /// A valid ID token, refreshed 5 minutes before it expires.
  Future<String> token({bool force = false}) async {
    final s = session;
    if (s == null) throw AuthError('Signed out');
    if (!force && DateTime.now().isBefore(s.expiresAt.subtract(const Duration(minutes: 5)))) return s.idToken;
    return (await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null))).idToken;
  }

  Future<Session> _refresh() async {
    final s = session!;
    final r = await http
        .post(Uri.parse('https://securetoken.googleapis.com/v1/token?key=$firebaseApiKey'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(s.refreshToken)}')
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(r.body);
    if (r.statusCode != 200) throw AuthError(_message(body));
    s
      ..idToken = body['id_token']
      ..refreshToken = body['refresh_token']
      ..uid = body['user_id']
      ..expiresAt = _expiry(body['expires_in']);
    _save(s);
    return s;
  }

  Future<void> _lookup() async {
    try {
      final res = await _post(
          'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=$firebaseApiKey', {'idToken': session!.idToken});
      final u = (res['users'] as List).first;
      session!
        ..email = u['email'] ?? session!.email
        ..displayName = (u['displayName'] as String?)?.isEmpty == true ? null : u['displayName'];
    } catch (_) {}
  }

  Future<void> updateName(String name) async {
    await _post('https://identitytoolkit.googleapis.com/v1/accounts:update?key=$firebaseApiKey',
        {'idToken': await token(), 'displayName': name, 'returnSecureToken': false});
    session?.displayName = name;
  }

  /// Re-authenticates with the current password, then sets the new one.
  Future<void> changePassword(String current, String next) async {
    final email = session!.email;
    await signIn(email, current);
    final res = await _post('https://identitytoolkit.googleapis.com/v1/accounts:update?key=$firebaseApiKey',
        {'idToken': session!.idToken, 'password': next, 'returnSecureToken': true});
    session!
      ..idToken = res['idToken']
      ..refreshToken = res['refreshToken']
      ..expiresAt = _expiry(res['expiresIn']);
    _save(session!);
  }

  Future<void> sendPasswordReset(String email) => _post(
      'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$firebaseApiKey',
      {'requestType': 'PASSWORD_RESET', 'email': email});

  void signOut() {
    session = null;
    _prefs.remove(_kRefresh);
    _prefs.remove(_kUid);
  }

  void _save(Session s) {
    _prefs.setString(_kRefresh, s.refreshToken);
    _prefs.setString(_kEmail, s.email);
    _prefs.setString(_kUid, s.uid);
  }

  static DateTime _expiry(dynamic seconds) =>
      DateTime.now().add(Duration(seconds: int.tryParse('$seconds') ?? 3600));

  static Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final http.Response r;
    try {
      r = await http
          .post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw AuthError('The server took too long to answer. Check your connection.');
    } catch (_) {
      throw AuthError('Network error — check your connection.');
    }
    final json = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw AuthError(_message(json));
    return json;
  }

  static String _message(dynamic body) {
    final code = (body is Map ? (body['error']?['message'] ?? '') : '').toString();
    if (code.contains('INVALID_LOGIN_CREDENTIALS') || code.contains('INVALID_PASSWORD') || code.contains('EMAIL_NOT_FOUND')) {
      return 'Incorrect email or password.';
    }
    if (code.contains('INVALID_EMAIL')) return 'Enter a valid email address.';
    if (code.contains('USER_DISABLED')) return 'This account has been disabled.';
    if (code.contains('TOO_MANY_ATTEMPTS')) return 'Too many attempts. Wait a moment and try again.';
    if (code.contains('WEAK_PASSWORD')) return 'Pick a longer password (6+ characters).';
    if (code.contains('TOKEN_EXPIRED') || code.contains('INVALID_REFRESH_TOKEN') || code.contains('USER_NOT_FOUND')) {
      return 'Your session expired. Sign in again.';
    }
    return code.isEmpty ? 'Something went wrong.' : code.replaceAll('_', ' ').toLowerCase();
  }
}

/// One live listener on a database path (like `onValue` in the web SDK).
class DbStream {
  DbStream(this._db, this.path, this.onValue, {this.limitToLast});
  final Rtdb _db;
  final String path;
  final int? limitToLast;
  final void Function(dynamic value) onValue;

  dynamic _value;
  http.Client? _client;
  StreamSubscription? _sub;
  Timer? _retry;
  bool _closed = false;
  int _attempt = 0;

  Future<void> start() async {
    if (_closed) return;
    _client?.close();
    final client = _client = http.Client();
    try {
      final token = await _db.auth.token();
      final q = {
        'auth': token,
        if (limitToLast != null) ...{'orderBy': '"\$key"', 'limitToLast': '$limitToLast'},
      };
      final uri = Uri.parse('$firebaseDbUrl/$path.json').replace(queryParameters: q);
      final req = http.Request('GET', uri)..headers['Accept'] = 'text/event-stream';
      final res = await client.send(req).timeout(const Duration(seconds: 20));
      if (res.statusCode == 401) {
        await _db.auth.token(force: true);
        return _scheduleRetry(immediate: true);
      }
      if (res.statusCode != 200) {
        _db._error('Database refused $path (HTTP ${res.statusCode})');
        return _scheduleRetry();
      }
      _attempt = 0;
      String? event;
      final data = StringBuffer();
      _sub = res.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trim());
        } else if (line.isEmpty && event != null) {
          _handle(event!, data.toString());
          event = null;
          data.clear();
        }
      }, onError: (_) => _scheduleRetry(), onDone: _scheduleRetry, cancelOnError: true);
    } catch (_) {
      _db._offline();
      _scheduleRetry();
    }
  }

  void _handle(String event, String raw) {
    switch (event) {
      case 'put':
      case 'patch':
        final msg = jsonDecode(raw) as Map<String, dynamic>;
        final segs = (msg['path'] as String).split('/').where((s) => s.isNotEmpty).toList();
        if (event == 'put') {
          _value = _setAt(_value, segs, msg['data']);
        } else {
          (msg['data'] as Map<String, dynamic>).forEach((k, v) {
            _value = _setAt(_value, [...segs, ...k.split('/').where((s) => s.isNotEmpty)], v);
          });
        }
        _db._synced();
        onValue(_value);
      case 'auth_revoked':
        _db.auth.token(force: true).then((_) => _scheduleRetry(immediate: true), onError: (_) => _db._signedOut());
      case 'cancel':
        _db._error('Permission denied on $path — check your database rules.');
    }
  }

  static dynamic _setAt(dynamic node, List<String> segs, dynamic value) {
    if (segs.isEmpty) return value;
    final map = node is Map ? Map<String, dynamic>.from(node) : <String, dynamic>{};
    final child = _setAt(map[segs.first], segs.sublist(1), value);
    if (child == null) {
      map.remove(segs.first);
    } else {
      map[segs.first] = child;
    }
    return map.isEmpty ? null : map;
  }

  void _scheduleRetry({bool immediate = false}) {
    _sub?.cancel();
    _sub = null;
    if (_closed) return;
    _retry?.cancel();
    final secs = immediate ? 0 : [1, 2, 4, 8, 15, 30][_attempt.clamp(0, 5)];
    _attempt++;
    _retry = Timer(Duration(seconds: secs), start);
  }

  void restart() => _scheduleRetry(immediate: true);

  void close() {
    _closed = true;
    _retry?.cancel();
    _sub?.cancel();
    _client?.close();
  }
}

class Rtdb {
  Rtdb(this.auth);
  final Auth auth;
  final List<DbStream> _streams = [];
  void Function(String state, [String? error])? onLink;
  int lastSync = 0;

  void _synced() {
    lastSync = DateTime.now().millisecondsSinceEpoch;
    onLink?.call('live');
  }

  void _offline() => onLink?.call('connecting');
  void _error(String e) => onLink?.call('error', e);
  void _signedOut() => onLink?.call('signed-out');

  void listen(String path, void Function(dynamic) onValue, {int? limitToLast}) {
    final s = DbStream(this, path, onValue, limitToLast: limitToLast);
    _streams.add(s);
    s.start();
  }

  /// Reconnect every listener (after the app returns from background).
  void reconnect() {
    for (final s in _streams) {
      s.restart();
    }
  }

  void closeAll() {
    for (final s in _streams) {
      s.close();
    }
    _streams.clear();
    lastSync = 0;
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<void> put(String path, dynamic v) => _send('PUT', path, v);
  Future<void> merge(String path, Map<String, dynamic> v) => _send('PATCH', path, v);
  Future<void> remove(String path) => _send('DELETE', path);
  Future<String> push(String path, dynamic v) async => (await _send('POST', path, v))['name'] as String;

  Future<dynamic> _send(String method, String path, [dynamic body]) async {
    Future<http.Response> go() async {
      final uri = Uri.parse('$firebaseDbUrl/$path.json').replace(queryParameters: {'auth': await auth.token()});
      final req = http.Request(method, uri);
      if (body != null) req.body = jsonEncode(body);
      return http.Response.fromStream(await req.send()).timeout(const Duration(seconds: 15));
    }

    var r = await go();
    if (r.statusCode == 401) {
      await auth.token(force: true);
      r = await go();
    }
    if (r.statusCode != 200) {
      throw Exception(r.statusCode == 401 ? 'Permission denied by the database rules.' : 'Database write failed (${r.statusCode}).');
    }
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }
}
