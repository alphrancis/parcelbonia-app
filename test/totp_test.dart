import 'package:flutter_test/flutter_test.dart';
import 'package:parcelbonia_app/totp.dart';

void main() {
  test('SHA-1 matches the standard test vector', () {
    final h = RiderTotp.sha1('abc'.codeUnits).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(h, 'a9993e364706816aba3e25717850c26c9cd0d89d');
  });

  test('TOTP matches RFC 6238 SHA-1 test vectors', () {
    final key = '12345678901234567890'.codeUnits;
    const vectors = {59: '94287082', 1111111109: '07081804', 1234567890: '89005924', 2000000000: '69279037'};
    vectors.forEach((t, code) => expect(RiderTotp.generate(key, t ~/ 30, digits: 8), code, reason: 'T=$t'));
  });

  test('Base32 secret and byte array are the same key', () {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var bits = 0, value = 0;
    final out = <int>[];
    for (final ch in RiderTotp.secretBase32.split('')) {
      value = (value << 5) | alphabet.indexOf(ch);
      bits += 5;
      if (bits >= 8) {
        out.add((value >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    expect(out, RiderTotp.secretBytes);
  });

  test('6-digit code matches an independent implementation (Python hmac)', () {
    // A retired key, used only as a fixed test vector.
    const key = [
      0xCD, 0x7E, 0x9F, 0xA3, 0x7E, 0xC3, 0x82, 0xE4, 0x57, 0xEF, //
      0x58, 0x22, 0xC9, 0xBE, 0xF5, 0x56, 0x1E, 0x9E, 0xCE, 0xC4,
    ];
    expect(RiderTotp.generate(key, 1790000000 ~/ 30), '544565');
  });
}
