import 'package:flutter/material.dart';

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
