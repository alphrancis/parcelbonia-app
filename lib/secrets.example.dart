// Template for lib/secrets.dart, which is git-ignored.
//
// Setup: copy this file to lib/secrets.dart and put in your own secret.
// To generate one (20 random bytes):
//   python -c "import secrets,base64;k=secrets.token_bytes(20);print(base64.b32encode(k).decode());print(', '.join('0x%02X'%b for b in k))"
//
// The app, the website and the Pro Mini firmware must all use the same value.

/// Built-in Firebase Authentication account (Email/Password) the app signs
/// in with silently at startup. There is no login screen.
const appAccountEmail = 'REPLACE_WITH_APP_ACCOUNT_EMAIL';
const appAccountPassword = 'REPLACE_WITH_APP_ACCOUNT_PASSWORD';

/// Rider-code TOTP secret, Base32 (RFC 4648, no padding).
const riderTotpSecretBase32 = 'REPLACE_WITH_YOUR_BASE32_SECRET';

/// The same 20 bytes, for the Arduino sketch.
const riderTotpSecretBytes = <int>[
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
];
