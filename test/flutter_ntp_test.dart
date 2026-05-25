import 'package:flutter_ntp/flutter_ntp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FlutterNTP.clearCache);

  group('NtpServer', () {
    test('every entry has a non-empty URL', () {
      for (final s in NtpServer.values) {
        expect(s.url, isNotEmpty, reason: 'server $s has empty url');
      }
    });

    test('server URLs are unique', () {
      final urls = NtpServer.values.map((s) => s.url).toList();
      expect(urls.toSet().length, urls.length, reason: 'duplicate server URLs');
    });
  });

  group('cache', () {
    test('starts empty', () {
      expect(FlutterNTP.offset, isNull);
      expect(FlutterNTP.lastSyncAt, isNull);
      expect(FlutterNTP.lastSyncServer, isNull);
    });

    test('nowSync falls back to device clock when no offset cached', () {
      final before = DateTime.now();
      final ntp = FlutterNTP.nowSync();
      final after = DateTime.now();
      // Should be within the tight window of two DateTime.now() reads.
      expect(ntp.isBefore(before.subtract(const Duration(milliseconds: 1))), isFalse);
      expect(ntp.isAfter(after.add(const Duration(milliseconds: 1))), isFalse);
    });

    test('clearCache resets state', () {
      FlutterNTP.clearCache();
      expect(FlutterNTP.offset, isNull);
      expect(FlutterNTP.lastSyncAt, isNull);
    });
  });

  group('NtpException', () {
    test('toString includes the message', () {
      const e = NtpException('boom');
      expect(e.toString(), contains('boom'));
    });

    test('toString includes the cause', () {
      const e = NtpException('boom', 'inner');
      expect(e.toString(), contains('boom'));
      expect(e.toString(), contains('inner'));
    });
  });
}
