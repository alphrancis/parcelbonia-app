<div align="center">
  <img src="assets/splash/logo.png" width="96" alt="Parcelbonia logo" />

  <h1>Parcelbonia</h1>

  <p><strong>Mobile control center for the PB-01 smart parcel receiver</strong></p>

  <p>
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.32-02569B?logo=flutter&logoColor=white" />
    <img alt="Dart" src="https://img.shields.io/badge/Dart-3.8-0175C2?logo=dart&logoColor=white" />
    <img alt="Firebase" src="https://img.shields.io/badge/Firebase-Realtime_DB-FFCA28?logo=firebase&logoColor=black" />
    <img alt="Platforms" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey" />
  </p>
</div>

---

Parcelbonia is a smart parcel box that receives deliveries while you are away.
This app lets you watch it live, unlock it remotely, hand out one-time rider
codes, test the hardware, and review its delivery and access history. It's
built in Flutter and styled in a liquid-glass look.

## Contents

- [Features](#features)
- [How it fits together](#how-it-fits-together)
- [Getting started](#getting-started)
- [Rider codes (TOTP)](#rider-codes-totp)
- [Database layout](#database-layout)
- [Project structure](#project-structure)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Features

| | |
|---|---|
| **Live dashboard** | Parcel presence, load cell weight, door switch and battery stream in real time. |
| **Remote unlock** | Pulse the solenoid lock from anywhere. The ESP reports back what the hardware actually did. |
| **Operating modes** | Switch between **Auto**, **Maintenance** and **Sleep** (powers the Arduino down, the ESP stays reachable). |
| **Components hub cooling** | The RTC's built-in temperature sensor watches the electronics hub. Intake and exhaust fans start automatically at a threshold you choose. |
| **Offline rider codes** | Six-digit time-based codes (the Google Authenticator standard). The box checks them on its own, with no Wi-Fi needed. |
| **Maintenance bench** | Read any sensor on request, switch each relay (lock, LED, fans) by hand, and write to the LCD. |
| **RFID cards** | Enroll, rename, disable or remove the cards the reader accepts. |
| **History** | Deliveries, access attempts, sensor logs and sleep sessions, exportable to CSV. |
| **Smart recommendations** | Plain-language advice when something needs attention, like a low battery, an open door, or a hot hub with fans off. |
| **No login** | Opens straight to the dashboard after the splash screen, using a silent anonymous Firebase session. |
| **Liquid-glass UI** | Frosted, light-catching panels over a slowly moving backdrop, a floating icon tab bar, and light and dark themes. |

## How it fits together

```
 ┌──────────────┐      Firebase Realtime DB       ┌──────────────┐   serial   ┌──────────────────┐
 │  This app    │ ◄──────── devices/PB-01 ──────► │   ESP module │ ◄────────► │ Arduino Pro Mini │
 │  (+ website) │   live data · config · cmds     │   (Wi-Fi)    │            │ sensors · relays │
 └──────────────┘                                 └──────────────┘            │ keypad · RFID    │
        │                                                                     │ DS3231 RTC       │
        └──────── same TOTP secret + UTC clock (no network) ────────────────► └──────────────────┘
```

- The app **never writes `live/` itself**. It queues commands under `commands/`,
  and the ESP performs them and writes the real state back. What you see is what
  the hardware did.
- Rider codes don't go through the database at all. The app and the Pro Mini
  each compute the code from a shared secret and the current UTC time.

## Getting started

### Prerequisites

- Flutter **3.32** (Dart 3.8)
- Android Studio with JDK 21, or Xcode for iOS
- A Firebase project with **Realtime Database** and **Authentication**

### 1. Clone and install

```bash
git clone https://github.com/alphrancis/parcelbonia-app.git
cd parcelbonia-app
flutter pub get
```

### 2. Add your secrets

The rider-code secret is not committed. Create it from the template:

```bash
cp lib/secrets.example.dart lib/secrets.dart
```

Generate a fresh secret (20 random bytes) and paste both forms into `lib/secrets.dart`:

```bash
python -c "import secrets,base64;k=secrets.token_bytes(20);print(base64.b32encode(k).decode());print(', '.join('0x%02X'%b for b in k))"
```

> [!IMPORTANT]
> Anyone with this secret can generate valid rider codes for your box.
> Keep it out of git (it is already in `.gitignore`) and store a backup somewhere private.

### 3. Configure Firebase

1. Set your project's API key and database URL in `lib/firebase_config.dart`.
2. In the Firebase console go to **Authentication → Sign-in method** and enable
   **Anonymous**. The app signs in silently, so this step is required.
3. Keep your database rules locked to signed-in users:

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

### 4. Run

```bash
flutter run
```

## Rider codes (TOTP)

Rider codes follow **RFC 6238 (TOTP)**, the same algorithm Google Authenticator uses.
The app, the website and the Arduino Pro Mini share one secret, so they always
agree on the current code without any connection.

| Parameter | Value |
|---|---|
| Algorithm | HMAC-SHA1 |
| Digits | 6 |
| Period | 30 seconds |
| Time base | Unix epoch, **UTC** |
| Secret | 20 bytes, from `lib/secrets.dart` |

**Firmware checklist**

- Set the DS3231 to **UTC**, not local time. A local clock gives every code the wrong value.
- Accept the **previous, current and next** window (±30 s) to absorb clock drift.
- Remember the last accepted window, so the same code can't be used twice.

The SHA-1, HMAC and TOTP code in `lib/totp.dart` uses plain integer maths with no
libraries, so it ports directly to C on the Pro Mini. **Copy authenticator link**
on the Rider code page adds the same secret to any authenticator app for testing.

## Database layout

Everything for the box lives under `devices/PB-01/`:

| Path | Written by | Contents |
|---|---|---|
| `mode` | app | `AUTO` · `MAINTENANCE` · `SLEEP` |
| `live/sensors/<id>` | ESP | `{ value, ts }` for `presence`, `weight`, `door`, `battery`, `temperature` |
| `live/actuators/<id>` | ESP | `{ state, ts }` for `lock`, `led`, `lcd`, `fanIntake`, `fanExhaust` |
| `live/inputs/rfid`, `live/inputs/keypad` | ESP | Last reader and keypad event |
| `live/heartbeat` | ESP | Last time the ESP checked in |
| `commands/` | app | Queued commands: `set-state`, `read-sensor`, `message`, `enroll-card`, … |
| `config/` | app | Device name, location, auto-lock delay, log interval, notifications |
| `config/fan` | app | `thresholdC` (fans on), `hysteresisC` (fans off this far below it) |
| `config/wifi` | app | SSID, hostname, static IP |
| `power` | app / ESP | `{ awake, changedAt, reason }` |
| `cards/<uid>` | app / ESP | RFID cards: name, owner, colour, active |
| `logs`, `access`, `deliveries`, `sleepLog` | ESP / app | History tables |

The display name is stored in `account/profile`.

## Project structure

```
lib/
├── main.dart              App entry: splash → dashboard
├── store.dart             App state, database listeners and commands
├── rtdb.dart              Firebase Auth + Realtime Database over REST / SSE
├── totp.dart              RFC 6238 rider codes (SHA-1, HMAC, TOTP)
├── thermal.dart           Components hub card, fan tiles, threshold editor
├── widgets.dart           Liquid-glass primitives and shared components
├── theme.dart             Colour tokens and typography
├── responsive.dart        Breakpoints, adaptive grid and split panes
├── icons.dart             Stroke icon set
├── firebase_config.dart   Project keys and device ID
├── secrets.example.dart   Template for the git-ignored secrets.dart
└── screens/
    ├── splash.dart        Animated boot screen
    ├── shell.dart         Header, mode switch and floating tab bar
    ├── panels_a.dart      Overview · Maintenance · Sleep · Data logs
    ├── panels_b.dart      Deliveries · Rider code · Access log
    └── panels_c.dart      RFID cards · Settings
```

## Testing

```bash
flutter analyze
flutter test
```

- **`layout_test.dart`** renders every page at small phone, phone, landscape,
  tablet and desktop sizes in both themes, and fails on any overflow.
- **`totp_test.dart`** checks SHA-1 and TOTP against the official RFC test
  vectors and against an independent implementation.

## Troubleshooting

**Dashboard opens but never connects.** Make sure **Anonymous** sign-in is
enabled in Firebase Authentication.

**Build fails with `Unresolved reference 'fileMode'`.** Gradle was upgraded to
9.x, which Flutter 3.32 doesn't support. Set
`android/gradle/wrapper/gradle-wrapper.properties` back to `gradle-8.12-all.zip`,
and decline Android Studio's Gradle upgrade prompt.

**`secrets.dart` not found.** You skipped [step 2](#2-add-your-secrets).

**Rider codes don't match the box.** Check that the DS3231 is set to UTC and
that the secret bytes in the firmware match `lib/secrets.dart` exactly.
