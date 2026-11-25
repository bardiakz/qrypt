import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/Qrypt.dart';
import '../../models/encryption_method.dart';
import '../../models/obfuscation_method.dart';
import '../../models/sign_method.dart';
import '../../providers/encryption_providers.dart';
import '../../resources/constants.dart';
import '../../resources/global_resources.dart';
import 'kyber_widgets.dart';
import 'qr/qr_share_dialog.dart';

/// Displays the processed encryption/decryption output section, optional
/// ML-KEM shared secret card, decrypt pipeline verification badges, and actions.
class EncryptionOutputPanel extends ConsumerWidget {
  final Color primaryColor;
  final bool isEncryptMode;
  final bool isMLKemMode;
  final bool shouldShowKemSecret;
  final String mlKemSharedSecret;
  final Qrypt? lastDecryptSummary;
  final VoidCallback onClearOutput;
  final VoidCallback onKemKeySaved;

  const EncryptionOutputPanel({
    super.key,
    required this.primaryColor,
    required this.isEncryptMode,
    required this.isMLKemMode,
    required this.shouldShowKemSecret,
    required this.mlKemSharedSecret,
    required this.lastDecryptSummary,
    required this.onClearOutput,
    required this.onKemKeySaved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;
    final outputText = isEncryptMode
        ? ref.watch(processedEncryptProvider).text
        : ref.watch(processedDecryptProvider).text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.defaultPadding),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
          ),
          child: Divider(),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        if (shouldShowKemSecret) ...[
          MLKemSharedSecretCard(
            context: context,
            primaryColor: primaryColor,
            sharedSecretBase64: mlKemSharedSecret,
            isSender: isEncryptMode,
            onKeySaved: onKemKeySaved,
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],
        buildSectionHeader(
          title: isEncryptMode && isMLKemMode
              ? 'Ciphertext Output (send to recipient)'
              : 'Output',
          characterCount: outputText.length.toString(),
          actions: [
            buildActionButton(
              icon: Icons.clear_all,
              color: primaryColor,
              onTap: onClearOutput,
              semanticLabel: 'Clear output',
              tooltip: 'Clear output',
            ),
            if (isEncryptMode)
              buildActionButton(
                icon: Icons.qr_code_2,
                color: primaryColor,
                onTap: () => _shareCiphertextQr(context, ref),
                semanticLabel: 'Share ciphertext as QR code',
                tooltip: 'Share ciphertext as QR code',
              ),
            buildActionButton(
              icon: Icons.content_copy,
              color: primaryColor,
              onTap: () => _copyOutput(context, ref),
              semanticLabel: 'Copy output to clipboard',
              tooltip: 'Copy output (Ctrl+Shift+C)',
            ),
          ],
        ),
        if (!isEncryptMode && lastDecryptSummary != null) ...[
          const SizedBox(height: AppConstants.smallPadding),
          DecryptPipelineSummary(summary: lastDecryptSummary!),
        ],
        const SizedBox(height: AppConstants.smallPadding),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
          ),
          child: Container(
            height: screenHeight * AppConstants.outputHeightRatio,
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            constraints: const BoxConstraints(minHeight: 120),
            width: double.infinity,
            alignment: Alignment.topLeft,
            decoration: BoxDecoration(
              color: getTextFieldBackgroundColor(context),
              border: Border.all(color: getBorderColor(context)),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: outputText.isEmpty
                ? Text(
                    isEncryptMode
                        ? 'Encrypted output will appear here...'
                        : 'Decrypted output will appear here...',
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      outputText,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
      ],
    );
  }

  void _shareCiphertextQr(BuildContext context, WidgetRef ref) {
    final outputText = ref.read(processedEncryptProvider).text;
    if (outputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No output to display as QR code')),
      );
      return;
    }
    showQrShareDialog(
      context: context,
      title: 'Ciphertext QR Code',
      data: outputText,
      kind: QrPayloadKind.ciphertext,
      subtitle: 'Scan with another device to import ciphertext',
      primaryColor: primaryColor,
    );
  }

  void _copyOutput(BuildContext context, WidgetRef ref) {
    final outputText = isEncryptMode
        ? ref.read(processedEncryptProvider).text
        : ref.read(processedDecryptProvider).text;
    if (outputText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No output to copy')));
      return;
    }
    copyToClipboard(outputText, context, isSensitive: !isEncryptMode);
  }
}

/// Renders signature-verification status and detected pipeline metadata badges
/// for the latest decrypted message.
class DecryptPipelineSummary extends StatelessWidget {
  final Qrypt summary;

  const DecryptPipelineSummary({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isVerified =
        summary.sign != SignMethod.none ||
        summary.encryption == EncryptionMethod.rsaSign;

    final String sigLabel;
    if (summary.sign == SignMethod.mlDsa) {
      sigLabel = 'Signature Verified (ML-DSA)';
    } else if (summary.sign == SignMethod.rsaPss) {
      sigLabel = 'Signature Verified (RSA-PSS)';
    } else if (summary.encryption == EncryptionMethod.rsaSign) {
      sigLabel = 'Signature Verified (RSA Legacy)';
    } else {
      sigLabel = 'Unsigned';
    }

    final pipelineLabel =
        '${summary.encryption.displayName} • ${summary.compression.name.toUpperCase()} • ${summary.obfuscation.displayName}';

    final badgeBg = isVerified
        ? (isDark
              ? Colors.green.shade900.withValues(alpha: 0.35)
              : Colors.green.shade50)
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200);
    final badgeBorder = isVerified
        ? (isDark ? Colors.green.shade500 : Colors.green.shade600)
        : getBorderColor(context);
    final badgeFg = isVerified
        ? (isDark ? Colors.green.shade200 : Colors.green.shade800)
        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: badgeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVerified ? Icons.verified_outlined : Icons.info_outline,
                  size: 14,
                  color: badgeFg,
                ),
                const SizedBox(width: 5),
                Text(
                  sigLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: getContainerBackgroundColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: getBorderColor(context)),
            ),
            child: Text(
              pipelineLabel,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
