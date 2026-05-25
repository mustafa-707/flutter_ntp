import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Curated list of public NTP servers.
///
/// Use any of these as the [server] argument to [FlutterNTP.now] /
/// [FlutterNTP.sync], or pass a raw hostname through [lookUpAddress].
enum NtpServer {
  google('time.google.com'),
  cloudflare('time.cloudflare.com'),
  facebook('time.facebook.com'),
  microsoft('time.windows.com'),
  apple('time.apple.com'),
  nist('time.nist.gov'),
  pool('pool.ntp.org'),
  usno('tick.usno.navy.mil'),
  isc('ntp.isc.org'),
  timeNl('ntp.time.nl'),
  chrony('chrony.eu'),
  hetzner('ntp1.hetzner.de'),
  hetzner2('ntp2.hetzner.de'),
  ntpSe('gbg1.ntp.se'),
  qix('ntp.qix.ca'),
  mskIx('ntp.ix.ru'),
  ripe('ntp.ripe.net'),
  ispClockIsc('clock.isc.org'),
  natMorris('ntp.nat.ms'),
  eduUtcnist('utcnist.colorado.edu'),
  ntpstm('ntpstm.netbone-digital.com'),
  netGps('gps.layer42.net'),
  ptb('ptbtime1.ptb.de'),
  plNtp('ntp.fizyka.umk.pl'),
  fuBerlin('time.fu-berlin.de'),
  surfnet('chime1.surfnet.nl'),
  asynchronos('asynchronos.iiss.at'),
  czNtp('ntp.nic.cz'),
  roNtp('ntp1.usv.ro'),
  lysator('timehost.lysator.liu.se'),
  caTime('time.nrc.ca'),
  mxCronos('cronos.cenam.mx'),
  esHora('hora.roa.es'),
  itInrim('ntp1.inrim.it'),
  beOma('ntp1.oma.be'),
  huAtomki('ntp.atomki.mta.hu'),
  eusI2t('ntp.i2t.ehu.eus'),
  chNeel('ntp.neel.ch'),
  cnNeu('ntp.neu.edu.cn'),
  jpNict('ntp.nict.jp'),
  brUfrj('ntps1.pads.ufrj.br'),
  clShoa('ntp.shoa.cl'),
  intEsa('time.esa.int');

  const NtpServer(this.url);
  final String url;
}

/// Thrown by [FlutterNTP] when a sync attempt fails.
class NtpException implements Exception {
  const NtpException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'NtpException: $message'
      : 'NtpException: $message (cause: $cause)';
}

/// Pure-Dart NTP (Network Time Protocol) client.
///
/// Typical usage:
/// ```dart
/// // One-time sync somewhere early in your app:
/// await FlutterNTP.sync();
///
/// // Anywhere else, fast (no network):
/// final ntpTime = FlutterNTP.nowSync();
/// ```
///
/// The class keeps an in-memory cached offset between the device clock and
/// the chosen NTP server, so subsequent calls are instant until the cache
/// expires.
abstract final class FlutterNTP {
  FlutterNTP._();

  /// NTP epoch is 1900-01-01 UTC, UNIX epoch is 1970-01-01 UTC.
  static const int _ntpEpochOffsetSeconds = 2208988800;

  /// 12 years in microseconds — sanity check against absurd offsets.
  static const int _maxOffsetMicros = 12 * 365 * 24 * 60 * 60 * 1000000;

  static const Duration _defaultTimeout = Duration(seconds: 5);
  static const Duration _defaultCacheDuration = Duration(hours: 1);

  static final Random _random = Random.secure();

  static Duration? _cachedOffset;
  static DateTime? _cachedAt;
  static String? _cachedServer;

  /// The last successfully measured offset (server time minus device time),
  /// or `null` if [sync] has never succeeded.
  static Duration? get offset => _cachedOffset;

  /// When [sync] last produced [offset], or `null` if never synced.
  static DateTime? get lastSyncAt => _cachedAt;

  /// Server URL of the last successful sync, or `null` if never synced.
  static String? get lastSyncServer => _cachedServer;

  /// Whether the current platform can run NTP queries.
  ///
  /// Returns `false` on the web (no `RawDatagramSocket`).
  static bool get isSupported => !_isWeb;

  /// Drop any cached offset.
  static void clearCache() {
    _cachedOffset = null;
    _cachedAt = null;
    _cachedServer = null;
  }

  /// Performs a single NTP round-trip and caches the resulting offset.
  ///
  /// Returns the offset (server clock - device clock).
  ///
  /// Throws [NtpException] on DNS, socket, or protocol errors.
  static Future<Duration> sync({
    NtpServer server = NtpServer.google,
    String? lookUpAddress,
    int port = 123,
    Duration timeout = _defaultTimeout,
  }) async {
    if (!isSupported) {
      throw const NtpException('FlutterNTP is not supported on this platform.');
    }

    final host = lookUpAddress ?? server.url;
    final offset = await _query(host: host, port: port, timeout: timeout);

    _cachedOffset = offset;
    _cachedAt = DateTime.now();
    _cachedServer = host;
    return offset;
  }

  /// Returns the current time corrected with the NTP offset.
  ///
  /// - If a fresh cached offset exists (younger than [cacheDuration]) it is
  ///   reused without a network call.
  /// - Otherwise a new [sync] is performed.
  /// - If the sync fails and [allowFallback] is `true` (default) the local
  ///   device time is returned; otherwise the [NtpException] is rethrown.
  static Future<DateTime> now({
    NtpServer server = NtpServer.google,
    String? lookUpAddress,
    int port = 123,
    Duration timeout = _defaultTimeout,
    Duration cacheDuration = _defaultCacheDuration,
    bool forceRefresh = false,
    bool allowFallback = true,
  }) async {
    final local = DateTime.now();

    if (!forceRefresh && _hasFreshCache(cacheDuration)) {
      return local.add(_cachedOffset!);
    }

    try {
      final offset = await sync(
        server: server,
        lookUpAddress: lookUpAddress,
        port: port,
        timeout: timeout,
      );
      return DateTime.now().add(offset);
    } on NtpException catch (e, stack) {
      developer.log('NTP sync failed: ${e.message}', name: 'flutter_ntp', stackTrace: stack);
      if (allowFallback) return local;
      rethrow;
    }
  }

  /// Synchronous variant of [now] that uses the cached offset, or the device
  /// clock when no cache exists. Never performs network I/O.
  static DateTime nowSync() {
    final local = DateTime.now();
    final offset = _cachedOffset;
    return offset == null ? local : local.add(offset);
  }

  static bool _hasFreshCache(Duration cacheDuration) {
    final at = _cachedAt;
    final off = _cachedOffset;
    if (at == null || off == null) return false;
    return DateTime.now().difference(at) < cacheDuration;
  }

  static Future<Duration> _query({
    required String host,
    required int port,
    required Duration timeout,
  }) async {
    final List<InternetAddress> addresses;
    try {
      addresses = await InternetAddress.lookup(host).timeout(timeout);
    } on TimeoutException catch (e) {
      throw NtpException('DNS lookup for $host timed out', e);
    } catch (e) {
      throw NtpException('DNS lookup for $host failed', e);
    }
    if (addresses.isEmpty) {
      throw NtpException('DNS lookup for $host returned no records');
    }

    final serverAddress = addresses.first;
    final bindAddress = serverAddress.type == InternetAddressType.IPv6
        ? InternetAddress.anyIPv6
        : InternetAddress.anyIPv4;

    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(bindAddress, 0);
    } catch (e) {
      throw NtpException('Could not bind UDP socket', e);
    }

    try {
      final request = _buildRequest();
      final originateTime = DateTime.now();
      socket.send(request, serverAddress, port);

      final response = await _readResponse(socket, timeout);
      final destinationTime = DateTime.now();

      return _computeOffset(response, originateTime, destinationTime);
    } finally {
      socket.close();
    }
  }

  static Future<Uint8List> _readResponse(RawDatagramSocket socket, Duration timeout) async {
    final completer = Completer<Uint8List>();
    late StreamSubscription<RawSocketEvent> sub;

    sub = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null && !completer.isCompleted) {
          completer.complete(datagram.data);
        }
      }
    }, onError: (Object e, StackTrace s) {
      if (!completer.isCompleted) completer.completeError(NtpException('Socket error', e), s);
    }, onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(const NtpException('Socket closed before response arrived'));
      }
    });

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException catch (e) {
      throw NtpException('No NTP response within ${timeout.inMilliseconds} ms', e);
    } finally {
      await sub.cancel();
    }
  }

  static Uint8List _buildRequest() {
    final buffer = Uint8List(48);
    // LI = 0 (no warning), VN = 3, Mode = 3 (client)
    buffer[0] = 0x1B;
    // Stratum / poll / precision left at 0 — that's fine for a client request.

    final data = ByteData.view(buffer.buffer);
    _writeNtpTimestamp(data, 40, DateTime.now());

    // RFC 5905 suggests randomizing the low bits of the transmit timestamp
    // to make spoofing harder. Apply to the last byte of the timestamp.
    buffer[47] = _random.nextInt(256);
    return buffer;
  }

  static Duration _computeOffset(
    Uint8List response,
    DateTime originateTime,
    DateTime destinationTime,
  ) {
    if (response.length < 48) {
      throw NtpException('Malformed NTP response (${response.length} bytes)');
    }

    final data = ByteData.view(response.buffer, response.offsetInBytes, response.lengthInBytes);
    final receiveTime = _readNtpTimestamp(data, 32);
    final transmitTime = _readNtpTimestamp(data, 40);

    // Standard NTP offset formula:
    //   offset = ((T2 - T1) + (T3 - T4)) / 2
    final offsetMicros =
        ((receiveTime.microsecondsSinceEpoch - originateTime.microsecondsSinceEpoch) +
                (transmitTime.microsecondsSinceEpoch - destinationTime.microsecondsSinceEpoch)) ~/
            2;

    if (offsetMicros.abs() > _maxOffsetMicros) {
      throw NtpException('NTP offset out of plausible range: $offsetMicros µs');
    }
    return Duration(microseconds: offsetMicros);
  }

  static void _writeNtpTimestamp(ByteData data, int offset, DateTime time) {
    final microsSinceUnix = time.toUtc().microsecondsSinceEpoch;
    final secondsSinceUnix = microsSinceUnix ~/ 1000000;
    final microsRemainder = microsSinceUnix - secondsSinceUnix * 1000000;
    final ntpSeconds = (secondsSinceUnix + _ntpEpochOffsetSeconds) & 0xFFFFFFFF;
    final fractional = ((microsRemainder / 1000000) * 0x100000000).round() & 0xFFFFFFFF;
    data.setUint32(offset, ntpSeconds, Endian.big);
    data.setUint32(offset + 4, fractional, Endian.big);
  }

  static DateTime _readNtpTimestamp(ByteData data, int offset) {
    final ntpSeconds = data.getUint32(offset, Endian.big);
    final fractional = data.getUint32(offset + 4, Endian.big);
    if (ntpSeconds == 0 && fractional == 0) {
      return DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
    }
    final unixSeconds = ntpSeconds - _ntpEpochOffsetSeconds;
    final micros = (fractional / 0x100000000 * 1000000).round();
    return DateTime.fromMicrosecondsSinceEpoch(unixSeconds * 1000000 + micros, isUtc: true);
  }
}

bool get _isWeb => identical(0, 0.0);
