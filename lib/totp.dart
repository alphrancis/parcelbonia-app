import 'dart:typed_data';

import 'secrets.dart';

/// Rider access codes — standard TOTP (RFC 6238), the same algorithm Google
/// Authenticator uses. The app, the website and the Arduino Pro Mini all hold
/// the same secret and derive the code from the current UTC time, so they
/// agree without any network connection.
///
///   Algorithm : HMAC-SHA1
///   Digits    : 6
///   Period    : 30 seconds
///   T0        : 0 (Unix epoch, UTC)
///
/// The Pro Mini must keep UTC time (the DS3231 RTC) and should accept the
/// previous and next 30-second window too, to tolerate clock drift.
abstract final class RiderTotp {
  /// Shared secret, Base32. Lives in the git-ignored lib/secrets.dart
  /// (template: lib/secrets.example.dart). Enter the same value in the website
  /// and firmware; it can also be added to Google Authenticator.
  static const secretBase32 = riderTotpSecretBase32;

  /// The same 20 bytes, for the Arduino sketch.
  static const secretBytes = riderTotpSecretBytes;

  static const period = 30, digits = 6;

  /// `otpauth://` link (lets the same secret be added to Google Authenticator).
  static const uri = 'otpauth://totp/Parcelbonia:PB-01?secret=$secretBase32'
      '&issuer=Parcelbonia&algorithm=SHA1&digits=6&period=30';

  /// Code for the given time (epoch milliseconds).
  static String codeAt(int epochMs) => generate(secretBytes, epochMs ~/ 1000 ~/ period, digits: digits);

  /// Seconds left before the code at [epochMs] changes.
  static int secondsLeft(int epochMs) => period - (epochMs ~/ 1000) % period;

  /// HOTP (RFC 4226) for a counter value.
  static String generate(List<int> key, int counter, {int digits = 6}) {
    final msg = ByteData(8)..setUint64(0, counter);
    final h = hmacSha1(key, msg.buffer.asUint8List());
    final o = h[19] & 0x0f;
    final bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
    var mod = 1;
    for (var i = 0; i < digits; i++) {
      mod *= 10;
    }
    return (bin % mod).toString().padLeft(digits, '0');
  }

  static Uint8List hmacSha1(List<int> key, List<int> msg) {
    const block = 64;
    var k = key.length > block ? sha1(key) : Uint8List.fromList(key);
    k = Uint8List(block)..setAll(0, k);
    final ipad = [for (final b in k) b ^ 0x36];
    final opad = [for (final b in k) b ^ 0x5c];
    return sha1([...opad, ...sha1([...ipad, ...msg])]);
  }

  static Uint8List sha1(List<int> data) {
    int rotl(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xffffffff;
    var h0 = 0x67452301, h1 = 0xEFCDAB89, h2 = 0x98BADCFE, h3 = 0x10325476, h4 = 0xC3D2E1F0;

    final bitLen = data.length * 8;
    final padded = <int>[...data, 0x80];
    while (padded.length % 64 != 56) {
      padded.add(0);
    }
    final len = ByteData(8)..setUint64(0, bitLen);
    padded.addAll(len.buffer.asUint8List());

    final w = List<int>.filled(80, 0);
    for (var chunk = 0; chunk < padded.length; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        final j = chunk + i * 4;
        w[i] = (padded[j] << 24) | (padded[j + 1] << 16) | (padded[j + 2] << 8) | padded[j + 3];
      }
      for (var i = 16; i < 80; i++) {
        w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }
      var a = h0, b = h1, c = h2, d = h3, e = h4;
      for (var i = 0; i < 80; i++) {
        final int f, k;
        if (i < 20) {
          f = (b & c) | ((~b & 0xffffffff) & d);
          k = 0x5A827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ED9EBA1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8F1BBCDC;
        } else {
          f = b ^ c ^ d;
          k = 0xCA62C1D6;
        }
        final t = (rotl(a, 5) + f + e + k + w[i]) & 0xffffffff;
        e = d;
        d = c;
        c = rotl(b, 30);
        b = a;
        a = t;
      }
      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
    }
    final out = ByteData(20);
    for (final (i, h) in [h0, h1, h2, h3, h4].indexed) {
      out.setUint32(i * 4, h);
    }
    return out.buffer.asUint8List();
  }
}
