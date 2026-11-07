// Template for lib/secrets.dart, which is git-ignored.
//
// Setup: copy this file to lib/secrets.dart and put in your own secret.
// To generate one (20 random bytes):
//   python -c "import secrets,base64;k=secrets.token_bytes(20);print(base64.b32encode(k).decode());print(', '.join('0x%02X'%b for b in k))"
//
// The app, the website and the Pro Mini firmware must all use the same value.

/// Rider-code TOTP secret, Base32 (RFC 4648, no padding).
const riderTotpSecretBase32 = 'REPLACE_WITH_YOUR_BASE32_SECRET';

/// The same 20 bytes, for the Arduino sketch.
const riderTotpSecretBytes = <int>[
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
];
