import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows a dialog displaying a QR code for air-gapped data sharing.
Future<void> showQrShareDialog({
  required BuildContext context,
  required String title,
  required String data,
  String? subtitle,
  Color? primaryColor,
  bool isSensitive = false,
  String? copySuccessMessage,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => QrShareDialog(
      title: title,
      data: data,
      subtitle: subtitle,
      primaryColor: primaryColor,
      isSensitive: isSensitive,
      copySuccessMessage: copySuccessMessage,
    ),
  );
}

/// A reusable modal dialog that renders data as a scannable QR code.
///
/// Features:
/// - Light/Dark mode isolated high-contrast container for reliable camera reading.
/// - Character length counter and dense-payload advisory warnings.
/// - One-tap copy to clipboard.
/// - Optional sensitivity warning banner (for AES keys or private credentials).
class QrShareDialog extends StatelessWidget {
  final String title;
  final String data;
  final String? subtitle;
  final Color? primaryColor;
  final bool isSensitive;
  final String? copySuccessMessage;

  const QrShareDialog({
    super.key,
    required this.title,
    required this.data,
    this.subtitle,
    this.primaryColor,
    this.isSensitive = false,
    this.copySuccessMessage,
  });

  // Maximum standard QR capacity for alphanumeric/byte data
  static const int maxQrCharCapacity = 2900;
  static const int denseQrWarningThreshold = 1400;

  @override
  Widget build(BuildContext context) {
    final effectivePrimary = primaryColor ?? Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final qrSize = min(240.0, min(screenWidth * 0.65, screenHeight * 0.35));
    final isTooLarge = data.length > maxQrCharCapacity;
    final isDense = data.length > denseQrWarningThreshold && !isTooLarge;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Icon(Icons.qr_code_2, color: effectivePrimary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              if (isSensitive) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sensitive credential. Only display to trusted recipients.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (data.isEmpty) ...[
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const Text(
                    'No content available to display as QR code.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ] else if (isTooLarge) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Content Too Large for QR (${data.length} characters)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Standard QR codes cannot reliably store this volume of data. Please copy the text to clipboard directly.',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // High-contrast canvas for QR code reader isolation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: qrSize,
                    height: qrSize,
                    child: QrImageView(
                      data: data,
                      version: QrVersions.auto,
                      size: qrSize,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      gapless: true,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      errorStateBuilder: (cxt, err) {
                        return Center(
                          child: Text(
                            'Failed to render QR code: ${err.toString()}',
                            style:
                                const TextStyle(color: Colors.red, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Character count indicator
              Text(
                '${data.length} characters',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),

              if (isDense) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange[800]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Dense QR code: hold scanner close',
                          style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Copy button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy to Clipboard'),
                  onPressed: data.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: data));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                copySuccessMessage ?? 'Copied to clipboard',
                              ),
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
