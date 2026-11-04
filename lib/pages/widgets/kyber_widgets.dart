import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../models/aes_key.dart';
import '../../resources/constants.dart';
import '../../resources/global_resources.dart';
import 'aes/create_aes_key_dialog.dart';

enum SharedSecretFormat { base64, hex }

Widget buildMLKemInfoContainer({
  required BuildContext context,
  required Color primaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.defaultPadding,
    ),
    child: Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ML-KEM performs post-quantum key encapsulation. The shared secret can be directly saved and used as a 256-bit AES key.',
              style: TextStyle(
                fontSize: 12,
                color: primaryColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class MLKemSharedSecretCard extends StatefulWidget {
  final BuildContext context;
  final Color primaryColor;
  final Uint8List? sharedSecretBytes;
  final String? sharedSecretBase64;
  final bool isSender;
  final VoidCallback? onKeySaved;

  const MLKemSharedSecretCard({
    super.key,
    required this.context,
    required this.primaryColor,
    this.sharedSecretBytes,
    this.sharedSecretBase64,
    required this.isSender,
    this.onKeySaved,
  });

  @override
  State<MLKemSharedSecretCard> createState() => _MLKemSharedSecretCardState();
}

class _MLKemSharedSecretCardState extends State<MLKemSharedSecretCard> {
  SharedSecretFormat _format = SharedSecretFormat.base64;

  Uint8List get _bytes {
    if (widget.sharedSecretBytes != null &&
        widget.sharedSecretBytes!.isNotEmpty) {
      return widget.sharedSecretBytes!;
    }
    if (widget.sharedSecretBase64 != null &&
        widget.sharedSecretBase64!.isNotEmpty) {
      try {
        return base64.decode(widget.sharedSecretBase64!.trim());
      } catch (_) {}
    }
    return Uint8List(0);
  }

  String get _formattedSecret {
    final bytes = _bytes;
    if (bytes.isEmpty) return '';
    if (_format == SharedSecretFormat.hex) {
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
    return base64.encode(bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes.isEmpty) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secret = _formattedSecret;
    final charCount = secret.length;
    final formatLabel = _format == SharedSecretFormat.base64
        ? '$charCount chars (Base64)'
        : '$charCount chars (Hex)';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prominent warning banner for sender or confirmation for receiver
          if (widget.isSender)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.red.shade900.withValues(alpha: 0.3)
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.red.shade400
                      : Colors.amber.shade700,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: isDarkMode
                        ? Colors.red.shade300
                        : Colors.amber.shade900,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAVE THIS SECRET NOW',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.red.shade200
                                : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This ephemeral shared secret was generated during encapsulation. It cannot be recovered after leaving this screen!',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.green.shade900.withValues(alpha: 0.3)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.green.shade400
                      : Colors.green.shade700,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: isDarkMode
                        ? Colors.green.shade300
                        : Colors.green.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Decapsulated Shared Secret',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.green.shade200
                                : Colors.green.shade900,
                          ),
                        ),
                        Text(
                          'Decapsulated using your private key. Matches the sender\'s 256-bit AES key.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Header with format toggle
          Row(
            children: [
              Icon(Icons.key, size: 18, color: widget.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Shared Secret',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              SegmentedButton<SharedSecretFormat>(
                segments: const [
                  ButtonSegment(
                    value: SharedSecretFormat.base64,
                    label: Text('Base64 (44)', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: SharedSecretFormat.hex,
                    label: Text('Hex (64)', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _format = newSelection.first;
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Monospace secret box with length subtitle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.grey.shade900
                  : Colors.amber.shade50.withValues(alpha: 0.5),
              border: Border.all(
                color: isDarkMode
                    ? Colors.amber.shade700
                    : Colors.amber.shade300,
              ),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  secret,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$formatLabel • 32 raw bytes (256 bits)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Action row: Copy & "Save as AES Key"
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Key'),
                onPressed: () {
                  copyToClipboard(secret, context);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.bookmark_add, size: 16),
                label: const Text('Save as AES Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final dateStr =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  final savedKey = await showDialog<AESKey>(
                    context: context,
                    builder: (ctx) => CreateAESKeyDialog(
                      primaryColor: widget.primaryColor,
                      initialKey: secret,
                      initialName: 'ML-KEM Key ($dateStr)',
                    ),
                  );
                  if (savedKey != null && widget.onKeySaved != null) {
                    widget.onKeySaved!();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget buildMLKemOutputSection({
  required BuildContext context,
  required Color primaryColor,
  required bool isEncryptMode,
  required String mlKemCiphertext,
  required String mlKemSharedSecret,
}) {
  return MLKemSharedSecretCard(
    context: context,
    primaryColor: primaryColor,
    sharedSecretBase64: mlKemSharedSecret,
    isSender: isEncryptMode,
  );
}
