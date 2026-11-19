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
              kind: QrPayloadKind.ciphertext,
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

    testWidgets('displays obfuscation map security note when kind is obfuscationMap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Obfuscation Map QR',
              data: '{"name":"test","map":{}}',
              kind: QrPayloadKind.obfuscationMap,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Note: Anyone with this map can read/de-obfuscate messages encoded with it.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
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
              kind: QrPayloadKind.publicKey,
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

    testWidgets('displays "Too large for a QR code. Use Copy." when data exceeds capacity', (
      WidgetTester tester,
    ) async {
      final hugeData = 'A' * 3000;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Huge QR',
              data: hugeData,
              kind: QrPayloadKind.ciphertext,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Too large for a QR code. Use Copy.'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('successfully renders 2604-char ML-DSA-65 public key via Level L fallback with dense warning and zoom support', (
      WidgetTester tester,
    ) async {
      // 2604 chars is the exact size of an ML-DSA-65 Base64 public key.
      // Exceeds Level M capacity (18,672 bits), but fits cleanly in Level L (up to 23,624 bits / Version 40).
      final mlDsaPublicKey = 'A' * 2604;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'ML-DSA Public Key: ds1',
              subtitle: 'Share this verification key with recipients',
              data: mlDsaPublicKey,
              kind: QrPayloadKind.publicKey,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No crash/red screen; renders scannable QR code using Level L
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('ML-DSA Public Key: ds1'), findsOneWidget);
      expect(find.text('Share this verification key with recipients'), findsOneWidget);
      expect(find.text('2604 characters'), findsOneWidget);
      expect(
        find.textContaining('Dense QR code (> 1,200 chars): hold scanner close and steady.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });

    testWidgets('displays "Too large for a QR code. Use Copy." for payloads exceeding maximum QR capacity (e.g. 3500 chars)', (
      WidgetTester tester,
    ) async {
      // 3500 chars exceeds maximum possible QR code capacity (2,953 bytes in Level L Version 40)
      final oversizedData = 'C' * 3500;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'ML-DSA-87 Public Key',
              subtitle: 'Oversized key payload',
              data: oversizedData,
              kind: QrPayloadKind.publicKey,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fallback card is shown cleanly
      expect(
        find.text('Too large for a QR code. Use Copy.'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('3500 characters'), findsOneWidget);
      expect(find.textContaining('Dense QR code'), findsNothing);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });

    testWidgets('displays dense QR warning when data is between 1201 and 2900 chars', (
      WidgetTester tester,
    ) async {
      final denseData = 'B' * 1300;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Dense QR',
              data: denseData,
              kind: QrPayloadKind.publicKey,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Dense QR code (> 1,200 chars): hold scanner close and steady.'),
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
              kind: QrPayloadKind.ciphertext,
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
                  kind: QrPayloadKind.publicKey,
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

    testWidgets('in-dialog zoom toggle expands and reduces QR code view', (
      WidgetTester tester,
    ) async {
      const payload = 'qrypt:test:zoom:toggle:payload';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Zoomable QR',
              data: payload,
              kind: QrPayloadKind.publicKey,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows zoom_in icon
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsNothing);

      // Tap zoom_in button to enlarge
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pumpAndSettle();

      // Now shows zoom_out icon
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsNothing);

      // Tap zoom_out button to reduce back to standard size
      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
    });

    testWidgets('tapping QR container opens interactive fullscreen zoom viewer with zoom controls', (
      WidgetTester tester,
    ) async {
      const payload = 'qrypt:test:fullscreen:zoom:payload';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrShareDialog(
              title: 'Interactive Zoom QR',
              data: payload,
              kind: QrPayloadKind.ciphertext,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tap QR code to zoom in fullscreen'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);

      // Tap the QR container to open interactive zoom dialog
      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      // Interactive viewer dialog should be open
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Pinch or use buttons to zoom & pan'), findsOneWidget);
      expect(find.byTooltip('Zoom In'), findsOneWidget);
      expect(find.byTooltip('Zoom Out'), findsOneWidget);
      expect(find.byTooltip('Reset Zoom'), findsOneWidget);

      // Test Zoom In button
      await tester.tap(find.byTooltip('Zoom In'));
      await tester.pumpAndSettle();

      // Test Reset Zoom button
      await tester.tap(find.byTooltip('Reset Zoom'));
      await tester.pumpAndSettle();

      // Close the fullscreen zoom dialog
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });
}
