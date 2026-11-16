import 'package:flutter/material.dart';
import '../../services/settings/settings_storage_service.dart';

/// Dialog displaying legal disclaimers, no-warranty notices, and backward compatibility terms.
/// Can be presented on first launch (requiring explicit acceptance) or on demand from settings.
class DisclaimerDialog extends StatelessWidget {
  final bool isFirstTime;
  final VoidCallback? onAccepted;

  const DisclaimerDialog({
    super.key,
    this.isFirstTime = false,
    this.onAccepted,
  });

  static Future<void> show(
    BuildContext context, {
    bool isFirstTime = false,
    VoidCallback? onAccepted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isFirstTime,
      builder: (context) => DisclaimerDialog(
        isFirstTime: isFirstTime,
        onAccepted: onAccepted,
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: isHighlight ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isHighlight
          ? BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.3),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? colorScheme.error
                  : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogContent = AlertDialog(
      title: const Text(
        'Important Notice & Disclaimer',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                context,
                title: '1. Legitimate & Educational Purpose',
                body:
                    'Qrypt is an open-source cryptography and obfuscation utility provided for personal privacy, research, and legitimate data security purposes. You are solely responsible for ensuring that your use of this software complies with all laws, export regulations, and cryptographic restrictions applicable in your local jurisdiction.',
              ),
              _buildSection(
                context,
                title: '2. "AS IS" — No Warranty',
                body:
                    'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. You assume all risks associated with using this software.',
              ),
              _buildSection(
                context,
                title: '3. No Guaranteed Backward Compatibility',
                body:
                    'While we try our best to maintain backward compatibility across updates where feasible, backward compatibility is NOT guaranteed. Cryptographic standards, algorithms, padding schemes, and tag encodings evolve over time. Older ciphertexts, tags, or keys may become deprecated or unreadable in future versions. The developers and maintainers accept no responsibility or liability if older encrypted data or tags cannot be decrypted by future versions or vice versa.',
                isHighlight: true,
              ),
              _buildSection(
                context,
                title: '4. Key Management & Plaintext Responsibility',
                body:
                    'All cryptographic keys and plaintexts are processed and stored exclusively on your device. The authors have no access to your keys and cannot recover, reset, or retrieve any lost keys or forgotten passphrases. You bear sole responsibility for safeguarding and backing up your keys and critical data.',
              ),
              _buildSection(
                context,
                title: '5. Limitation of Liability',
                body:
                    'In no event shall the authors, maintainers, contributors, or copyright holders be held liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, loss of data, loss of profits, business interruption, intercepted communications, compromised keys, or unintended disclosures) arising in any way out of the use of, or inability to use, this software.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isFirstTime)
          FilledButton(
            onPressed: () async {
              await SettingsStorageService.setDisclaimerAccepted(true);
              if (context.mounted) {
                Navigator.of(context).pop();
                onAccepted?.call();
              }
            },
            child: const Text('I Understand & Accept'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
      ],
    );

    if (isFirstTime) {
      return PopScope(
        canPop: false,
        child: dialogContent,
      );
    }

    return dialogContent;
  }
}
