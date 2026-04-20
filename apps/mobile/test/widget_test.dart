import 'package:ficct_final_app/src/app.dart';
import 'package:ficct_final_app/src/core/utils/frequency_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots the app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const FicctFinalApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('maps wifi frequencies to channels', () {
    expect(wifiChannelFromFrequency(2412), 1);
    expect(wifiChannelFromFrequency(2437), 6);
    expect(wifiChannelFromFrequency(2462), 11);
    expect(wifiChannelFromFrequency(5180), 36);
    expect(wifiChannelFromFrequency(5955), 1);
    expect(wifiChannelFromFrequency(1234), isNull);
  });
}
