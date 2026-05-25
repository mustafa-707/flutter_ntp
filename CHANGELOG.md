# Changelog

## 0.1.0

- **Fix:** the cache was effectively never hit. The previous code stored the
  NTP offset as the cached value and later interpreted it as a
  `microsecondsSinceEpoch` for the "cached at" timestamp, so the freshness
  check compared `now()` against a date near 1970 and always thought the
  cache was stale. Cache now tracks `(offset, syncedAt, server)` correctly,
  so subsequent `now()` calls are instant until the cache expires.
- **Fix:** `encodeTimestamp` overwrote `array[7]` with a random byte on every
  call, corrupting the `rootDelay` field of the outgoing packet. The random
  byte is now written to the last byte of the **transmit** timestamp as
  RFC 5905 §3 suggests for spoofing resistance.
- **Fix:** wire format rewritten with `ByteData` (no more double-precision
  arithmetic on 64-bit fixed-point timestamps), removing the subtle
  precision loss from the previous `pow(2.0, ...)` decoder.
- **Fix:** removed duplicate `NtpServer` entries (`ntpPool`/`pool`,
  `milUsno`/`usno`, etc.).
- **API:** new `FlutterNTP.sync()` performs a one-shot round-trip and caches
  the offset; new `FlutterNTP.nowSync()` returns the corrected time without
  any I/O. `FlutterNTP.now()` keeps its old signature but gains
  `forceRefresh` and `allowFallback` flags, plus optional `server`.
- **API:** typed `NtpException` instead of raw `String`s.
- **API:** new `offset`, `lastSyncAt`, `lastSyncServer`, and `clearCache()`
  getters / utility.
- **API:** `isSupported` getter (returns `false` on the web).
- DNS lookup now honors the supplied `timeout`.
- Bumped lints to `flutter_lints ^5.0.0`, SDK constraints to Dart 3.4 /
  Flutter 3.22.
- Rebuilt the example with Material 3 and a live "ticking" NTP clock.

## 0.0.2

- README added.

## 0.0.1

- Initial release.
