import 'package:flutter/material.dart';
import 'package:flutter_ntp_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders the device-time card', (tester) async {
    await tester.pumpWidget(const NtpDemoApp());
    await tester.pump();

    expect(find.text('flutter_ntp'), findsWidgets);
    expect(find.text('Device time'), findsOneWidget);
    expect(find.text('NTP time'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });
}
