import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ntp/flutter_ntp.dart';

void main() => runApp(const NtpDemoApp());

class NtpDemoApp extends StatelessWidget {
  const NtpDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ntp demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const _HomeScreen(),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  NtpServer _server = NtpServer.google;
  bool _busy = false;
  Object? _error;
  Timer? _ticker;
  DateTime _tick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _tick = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FlutterNTP.sync(server: _server, timeout: const Duration(seconds: 4));
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ntpNow = FlutterNTP.nowSync();
    final offset = FlutterNTP.offset;

    return Scaffold(
      appBar: AppBar(title: const Text('flutter_ntp')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ClockCard(
                title: 'Device time',
                time: _tick,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 12),
              _ClockCard(
                title: 'NTP time',
                time: ntpNow,
                color: theme.colorScheme.primaryContainer,
                subtitle: offset == null
                    ? 'No sync yet — using device time'
                    : 'Offset: ${_formatOffset(offset)} · synced ${_formatRelative(FlutterNTP.lastSyncAt)} ago via ${FlutterNTP.lastSyncServer}',
              ),
              const SizedBox(height: 20),
              DropdownMenu<NtpServer>(
                initialSelection: _server,
                label: const Text('NTP server'),
                expandedInsets: EdgeInsets.zero,
                onSelected: (s) {
                  if (s != null) setState(() => _server = s);
                },
                dropdownMenuEntries: [
                  for (final s in NtpServer.values)
                    DropdownMenuEntry(value: s, label: '${s.name} (${s.url})'),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _sync,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_busy ? 'Syncing…' : 'Sync now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: FlutterNTP.offset == null
                    ? null
                    : () => setState(FlutterNTP.clearCache),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear cache'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('$_error', style: theme.textTheme.bodyMedium),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatOffset(Duration d) {
    final sign = d.isNegative ? '-' : '+';
    final abs = d.abs();
    if (abs.inMilliseconds < 1000) return '$sign${abs.inMilliseconds} ms';
    return '$sign${abs.inMilliseconds / 1000} s';
  }

  static String _formatRelative(DateTime? when) {
    if (when == null) return 'never';
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}

class _ClockCard extends StatelessWidget {
  const _ClockCard({
    required this.title,
    required this.time,
    required this.color,
    this.subtitle,
  });

  final String title;
  final DateTime time;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              _format(time),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  static String _format(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }
}
