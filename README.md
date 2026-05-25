# flutter_ntp

[![pub package](https://img.shields.io/pub/v/flutter_ntp.svg)](https://pub.dev/packages/flutter_ntp)

A small, fast **NTP (Network Time Protocol) client** for Flutter and Dart.

- Pure Dart, no platform channels — works on Android, iOS, macOS, Windows, Linux.
- Sync once, read forever: the offset between device and server is cached, so subsequent calls are instant.
- 40+ public NTP servers built in, or pass any host name.
- Typed `NtpException`, configurable timeout, optional fallback to device clock.

## Install

```yaml
dependencies:
  flutter_ntp: ^0.1.0
```

```bash
flutter pub get
```

## Usage

```dart
import 'package:flutter_ntp/flutter_ntp.dart';
```

### Quick start

```dart
// One time, somewhere early in your app:
await FlutterNTP.sync();

// Anywhere else — instant, no network:
final accurateNow = FlutterNTP.nowSync();
print('NTP time : $accurateNow');
print('Offset   : ${FlutterNTP.offset}');
```

### One-shot

```dart
final ntpNow = await FlutterNTP.now();         // re-uses the cache when fresh
final ntpNow = await FlutterNTP.now(forceRefresh: true); // always re-sync
```

### Pick a server / set a timeout

```dart
await FlutterNTP.sync(
  server: NtpServer.cloudflare,
  timeout: const Duration(seconds: 3),
);

// Or a custom host:
await FlutterNTP.sync(lookUpAddress: 'my-internal-ntp.example.com');
```

### Error handling

`FlutterNTP.now()` falls back to `DateTime.now()` by default if the network call fails — useful in offline scenarios. Pass `allowFallback: false` to make failures explicit:

```dart
try {
  final t = await FlutterNTP.now(allowFallback: false);
} on NtpException catch (e) {
  // handle network / DNS / timeout
}
```

### Inspect / reset the cache

```dart
FlutterNTP.offset;          // Duration? — last known server-device offset
FlutterNTP.lastSyncAt;      // DateTime? — when sync last succeeded
FlutterNTP.lastSyncServer;  // String?   — host name of last sync
FlutterNTP.clearCache();    // forget everything
```

### Available servers

```text
google · cloudflare · facebook · microsoft · apple · nist · pool · usno · isc
timeNl · chrony · hetzner · hetzner2 · ntpSe · qix · mskIx · ripe · ispClockIsc
natMorris · eduUtcnist · ntpstm · netGps · ptb · plNtp · fuBerlin · surfnet
asynchronos · czNtp · roNtp · lysator · caTime · mxCronos · esHora · itInrim
beOma · huAtomki · eusI2t · chNeel · cnNeu · jpNict · brUfrj · clShoa · intEsa
```

## Platform support

| Platform           | Supported |
|--------------------|:---------:|
| Android / iOS      | ✅        |
| macOS / Windows / Linux | ✅   |
| Web                | ❌ (no UDP) |

`FlutterNTP.isSupported` is `false` on the web.

## Support

If you find this package useful, consider supporting the author:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
