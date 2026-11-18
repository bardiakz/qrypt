import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrypt/pages/widgets/qr/qr_share_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QrShareDialog Widget Tests', () {
    testWidgets('renders QR code, title, subtitle, and character count for valid payload', (
      WidgetTester tester,
    ) async {
      const payload = 'qrypt:test:payload:123456';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Test QR Code',
              data: payload,
              subtitle: 'Scan to test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test QR Code'), findsOneWidget);
      expect(find.text('Scan to test'), findsOneWidget);
      expect(find.text('${payload.length} characters'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('renders sensitivity banner when isSensitive is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'AES Key QR',
              data: '12345678901234567890123456789012',
              isSensitive: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Sensitive credential. Only display to trusted recipients.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('displays empty message and disables copy button when data is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Empty QR',
              data: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No content available to display as QR code.'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Copy to Clipboard'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('displays oversized warning when data exceeds capacity (> 2900 chars)', (
      WidgetTester tester,
    ) async {
      final hugeData = 'A' * 3000;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Huge QR',
              data: hugeData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Content Too Large for QR (3000 characters)'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('displays dense QR warning when data is between 1401 and 2900 chars', (
      WidgetTester tester,
    ) async {
      final denseData = 'B' * 1500;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Dense QR',
              data: denseData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Dense QR code: hold scanner close'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('copies data to clipboard and shows snackbar on copy tap', (
      WidgetTester tester,
    ) async {
      String? copiedString;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copiedString = (call.arguments as Map)['text'] as String?;
          return null;
        }
        return null;
      });

      const testPayload = 'sample-qr-clipboard-data';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Copy QR',
              data: testPayload,
              copySuccessMessage: 'Custom copy message',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy to Clipboard'));
      await tester.pumpAndSettle();

      expect(copiedString, equals(testPayload));
      expect(find.text('Custom copy message'), findsOneWidget);
    });

    testWidgets('showQrShareDialog helper launches and closes dialog correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showQrShareDialog(
                  context: context,
                  title: 'Helper QR Dialog',
                  data: 'helper-payload-123',
                ),
                child: const Text('Open QR Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open QR Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Helper QR Dialog'), findsOneWidget);
      expect(find.byType(QrShareDialog), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(QrShareDialog), findsNothing);
    });
  });
}
