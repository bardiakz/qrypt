import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The specific classification of data permitted to be shared via QR code.
///
/// Private keys and symmetric secrets MUST NEVER be rendered as QR codes without
/// biometric or app lock gating, and are intentionally omitted from this enum.
enum QrPayloadKind {
  /// Public verification or encryption keys (RSA, ML-KEM, ML-DSA).
  publicKey,

  /// Encrypted ciphertext messages.
  ciphertext,

  /// Word-substitution obfuscation dictionary maps.
  obfuscationMap,
}

/// Shows a modal dialog displaying a QR code for air-gapped data sharing.
Future<void> showQrShareDialog({
  required BuildContext context,
  required String title,
  required String data,
  required QrPayloadKind kind,
  String? subtitle,
  Color? primaryColor,
  String? copySuccessMessage,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => QrShareDialog(
      title: title,
      data: data,
      kind: kind,
      subtitle: subtitle,
      primaryColor: primaryColor,
      copySuccessMessage: copySuccessMessage,
    ),
  );
}

/// A reusable modal dialog that renders non-sensitive payloads as a scannable QR code.
///
/// Features:
/// - Type-safe payload restriction via [QrPayloadKind].
/// - Light/Dark mode isolated high-contrast container for reliable camera reading.
/// - Dynamic in-dialog zoom/enlarge toggle and full-screen pinch-to-zoom interactive viewer.
/// - Catches QR library input-too-long errors and displays "Too large for a QR code. Use Copy.".
/// - Scan-reliability advisory banner for payloads above 1,200 characters.
/// - Explicit security advisory for obfuscation maps.
/// - One-tap copy to clipboard.
class QrShareDialog extends StatefulWidget {
  final String title;
  final String data;
  final QrPayloadKind kind;
  final String? subtitle;
  final Color? primaryColor;
  final String? copySuccessMessage;

  const QrShareDialog({
    super.key,
    required this.title,
    required this.data,
    required this.kind,
    this.subtitle,
    this.primaryColor,
    this.copySuccessMessage,
  });

  /// Threshold above which camera scanning becomes difficult due to dense matrix modules.
  static const int scanReliabilityThreshold = 1200;

  @override
  State<QrShareDialog> createState() => _QrShareDialogState();
}

class _QrShareDialogState extends State<QrShareDialog> {
  bool _isEnlarged = false;

  @override
  Widget build(BuildContext context) {
    final effectivePrimary =
        widget.primaryColor ?? Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final standardQrSize =
        min(240.0, min(screenWidth * 0.65, screenHeight * 0.35));
    final enlargedQrSize =
        min(420.0, min(screenWidth * 0.82, screenHeight * 0.52));
    final qrSize = _isEnlarged ? enlargedQrSize : standardQrSize;
    final dialogWidth = _isEnlarged ? min(screenWidth * 0.92, 520.0) : 340.0;

    QrCode? validQrCode;
    bool isTooLarge = false;

    if (widget.data.isNotEmpty) {
      try {
        final qr = QrCode.fromData(
          data: widget.data,
          errorCorrectLevel: QrErrorCorrectLevel.M,
        );
        // Evaluating QrImage(qr) eagerly forces generation and verification
        // of QR matrix data. If data exceeds QR capacity for Level M,
        // this throws InputTooLongException before rendering.
        QrImage(qr);
        validQrCode = qr;
      } catch (_) {
        isTooLarge = true;
        validQrCode = null;
      }
    }

    final bool isDense = !isTooLarge &&
        validQrCode != null &&
        widget.data.length > QrShareDialog.scanReliabilityThreshold;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Icon(_getKindIcon(), color: effectivePrimary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isTooLarge && validQrCode != null) ...[
            IconButton(
              icon: Icon(_isEnlarged ? Icons.zoom_out : Icons.zoom_in),
              tooltip: _isEnlarged ? 'Reduce size' : 'Enlarge QR code',
              onPressed: () {
                setState(() {
                  _isEnlarged = !_isEnlarged;
                });
              },
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              // Obfuscation map security note
              if (widget.kind == QrPayloadKind.obfuscationMap) ...[
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
                        Icons.info_outline,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: Anyone with this map can read/de-obfuscate messages encoded with it.',
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

              if (widget.data.isEmpty) ...[
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const Text(
                    'No content available to display as QR code.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ] else if (isTooLarge || validQrCode == null) ...[
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
                      const Text(
                        'Too large for a QR code. Use Copy.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Payload length (${widget.data.length} characters) exceeds the maximum QR code storage capacity.',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // High-contrast canvas for QR code reader isolation with tap-to-zoom support
                GestureDetector(
                  onTap: () => _openInteractiveZoomDialog(context, validQrCode!),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Tap to inspect or pinch-zoom in fullscreen',
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
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
                              child: QrImageView.withQr(
                                qr: validQrCode,
                                size: qrSize,
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
                                  return const Center(
                                    child: Text(
                                      'Too large for a QR code. Use Copy.',
                                      style: TextStyle(color: Colors.red, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.open_in_full,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap QR code to zoom in fullscreen',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],

              const SizedBox(height: 10),

              // Character count indicator
              Text(
                '${widget.data.length} characters',
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
                          'Dense QR code (> 1,200 chars): hold scanner close and steady.',
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
                  onPressed: widget.data.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: widget.data));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                widget.copySuccessMessage ?? 'Copied to clipboard',
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

  void _openInteractiveZoomDialog(
    BuildContext context,
    QrCode qrCode,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        final maxQrSize =
            min(520.0, min(screenWidth * 0.88, screenHeight * 0.65));
        final TransformationController transformController =
            TransformationController();

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.black87),
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: Colors.white,
                            width: maxQrSize,
                            height: maxQrSize,
                            child: InteractiveViewer(
                              transformationController: transformController,
                              minScale: 1.0,
                              maxScale: 5.0,
                              boundaryMargin: const EdgeInsets.all(40),
                              child: Center(
                                child: QrImageView.withQr(
                                  qr: qrCode,
                                  size: maxQrSize,
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
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.zoom_out, color: Colors.black87),
                              tooltip: 'Zoom Out',
                              onPressed: () {
                                final currentScale = transformController.value.getMaxScaleOnAxis();
                                if (currentScale > 1.0) {
                                  final newScale = max(1.0, currentScale - 0.5);
                                  transformController.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
                                  setDialogState(() {});
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore, color: Colors.black87),
                              tooltip: 'Reset Zoom',
                              onPressed: () {
                                transformController.value = Matrix4.identity();
                                setDialogState(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.zoom_in, color: Colors.black87),
                              tooltip: 'Zoom In',
                              onPressed: () {
                                final currentScale = transformController.value.getMaxScaleOnAxis();
                                if (currentScale < 5.0) {
                                  final newScale = min(5.0, currentScale + 0.5);
                                  transformController.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        Text(
                          'Pinch or use buttons to zoom & pan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  IconData _getKindIcon() {
    switch (widget.kind) {
      case QrPayloadKind.publicKey:
        return Icons.vpn_key_outlined;
      case QrPayloadKind.ciphertext:
        return Icons.lock_outline;
      case QrPayloadKind.obfuscationMap:
        return Icons.translate_outlined;
    }
  }
}
