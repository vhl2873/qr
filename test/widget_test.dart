import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobqr/main.dart';

void main() {
  testWidgets('QR workspace renders two navigation flows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('QR Generator'), findsOneWidget);
    expect(find.text('Tao QR'), findsWidgets);
    expect(find.text('Gan vao anh'), findsOneWidget);
    expect(find.text('Ma QR'), findsOneWidget);
    expect(find.byKey(const ValueKey('qr-preview')), findsNothing);

    await tester.tap(find.text('Gan vao anh'));
    await tester.pumpAndSettle();

    expect(find.text('QR Cover Editor'), findsOneWidget);
    expect(find.text('Preview thanh pham'), findsOneWidget);
    expect(find.text('Chon anh bia'), findsOneWidget);
    expect(find.byKey(const ValueKey('qr-size-slider')), findsOneWidget);
  });

  testWidgets('QR overlay appears after entering data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/job/123',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('qr-preview')), findsOneWidget);

    await tester.tap(find.text('Gan vao anh'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('qr-overlay')), findsOneWidget);
    expect(find.text('QR tu man Tao QR se duoc dung tai day.'), findsOneWidget);
  });
}
