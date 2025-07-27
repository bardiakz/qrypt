import 'package:flutter/material.dart';

import '../../models/kyber_models.dart';
import '../../resources/constants.dart';
import '../../resources/global_resources.dart';

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
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ML-KEM performs quantum-secure key exchange. The generated shared key can be used with AES for message encryption.',
              style: TextStyle(
                fontSize: 12,
                color: primaryColor.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildMLKemOutputSection({
  required BuildContext context,
  required Color primaryColor,
  required bool isEncryptMode,
  required String mlKemCiphertext,
  required String mlKemSharedSecret,
}) {
  if (isEncryptMode) {
    return Column(
      children: [
        // Ciphertext output
        _buildMLKemOutputField(
          context: context,
          primaryColor: primaryColor,
          title: 'Ciphertext (send to recipient)',
          content: mlKemCiphertext,
          icon: Icons.send,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        // Shared secret output
        _buildMLKemOutputField(
          context: context,
          primaryColor: primaryColor,
          title: 'Shared Secret (keep private)',
          content: mlKemSharedSecret,
          icon: Icons.key,
          isSecret: true,
        ),
      ],
    );
  } else {
    return _buildMLKemOutputField(
      context: context,
      primaryColor: primaryColor,
      title: 'Extracted Shared Secret',
      content: mlKemSharedSecret,
      icon: Icons.key,
      isSecret: true,
    );
  }
}

Widget _buildMLKemOutputField({
  required BuildContext context,
  required Color primaryColor,
  required String title,
  required String content,
  required IconData icon,
  bool isSecret = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.defaultPadding,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const Spacer(),
            if (content.isNotEmpty)
              buildActionButton(
                icon: Icons.content_copy,
                color: primaryColor,
                onTap: () => copyToClipboard(content, context),
                semanticLabel: 'Copy $title',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: isSecret
                ? Colors.amber.withOpacity(0.1)
                : getTextFieldBackgroundColor(context),
            border: Border.all(
              color: isSecret
                  ? Colors.amber.withOpacity(0.3)
                  : getBorderColor(context),
            ),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: SelectableText(
            content.isEmpty ? 'No data generated yet...' : content,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: content.isEmpty ? Colors.grey : null,
            ),
          ),
        ),
      ],
    ),
  );
}

// Generate mock shared secret for demonstration
String generateMockSharedSecret() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = DateTime.now().millisecondsSinceEpoch;
  var result = '';

  // Generate 32-byte (256-bit) shared secret
  for (var i = 0; i < 64; i++) {
    // 64 hex characters = 32 bytes
    result += chars[(random + i) % chars.length];
  }

  // Format as hex-like string
  return result
      .replaceAllMapped(RegExp(r'.{8}'), (match) => '${match.group(0)} ')
      .trim();
}

// Generate mock ML-KEM ciphertext for demonstration
String generateMockMLKemCiphertext(MLKemKeySize selectedMLKemKeySize) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  final random = DateTime.now().millisecondsSinceEpoch;
  var result = '';

  // Generate ciphertext based on selected key size
  int length;
  switch (selectedMLKemKeySize) {
    case MLKemKeySize.kem512:
      length = 768; // Approximate ciphertext size for KEM-512
      break;
    case MLKemKeySize.kem768:
      length = 1088; // Approximate ciphertext size for KEM-768
      break;
    case MLKemKeySize.kem1024:
      length = 1568; // Approximate ciphertext size for KEM-1024
      break;
  }

  for (var i = 0; i < length; i++) {
    result += chars[(random + i) % chars.length];
  }

  // Format with line breaks for readability
  final formatted = result.replaceAllMapped(
    RegExp(r'.{64}'),
    (match) => '${match.group(0)}\n',
  );

  return 'ML-KEM-${selectedMLKemKeySize.bits} Ciphertext:\n$formatted';
}
