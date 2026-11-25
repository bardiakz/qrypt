import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/pages/settings_page.dart';
import 'package:qrypt/pages/widgets/Dropdown_button_forms.dart';
import 'package:qrypt/pages/widgets/kyber_widgets.dart';
import 'package:qrypt/pages/widgets/ml_dsa/ml_dsa_key_selector.dart';
import 'package:qrypt/pages/widgets/ml_kem/kem_key_selector.dart';
import 'package:qrypt/pages/widgets/mode_switch.dart';
import 'package:qrypt/pages/widgets/rsa/rsa_key_selector.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:flutter/services.dart';
import 'package:qrypt/providers/aes_providers.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/ml_dsa_providers.dart';
import 'package:qrypt/providers/rsa_providers.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import '../models/aes_key.dart';
import '../models/encryption_method.dart';
import '../models/kem_key_pair.dart';
import '../models/kyber_models.dart';
import '../models/ml_dsa_key_pair.dart';
import '../models/rsa_key_pair.dart';
import '../models/sign_method.dart';
import '../providers/resource_providers.dart';
import '../resources/constants.dart';
import '../resources/global_resources.dart';
import '../services/input_handler.dart';
import 'key_management_page.dart';
import 'widgets/aes/aes_key_management_dialog.dart';
import 'widgets/aes/aes_key_selector.dart';
import 'widgets/aes/create_aes_key_dialog.dart';
import 'widgets/asymmetric_selector_header.dart';
import 'widgets/disclaimer_dialog.dart';
import 'widgets/encryption_output_panel.dart';
import 'widgets/ml_dsa/ml_dsa_key_management_dialog.dart';
import 'widgets/ml_kem/kem_key_management_dialog.dart';
import 'widgets/qr/qr_share_dialog.dart';
import 'widgets/rsa/rsa_key_management_dialog.dart';
import 'widgets/web_storage_notice_banner.dart';
import '../services/settings/settings_storage_service.dart';

class EncryptionPage extends ConsumerStatefulWidget {
  const EncryptionPage({super.key});

  @override
  ConsumerState<EncryptionPage> createState() => _EncryptionPageState();
}

class _EncryptionPageState extends ConsumerState<EncryptionPage> {
  final _encryptTextController = TextEditingController();
  final _decryptTextController = TextEditingController();
  final _encryptPublicKeyController = TextEditingController();
  final _decryptPublicKeyController = TextEditingController();
  final _customAesKeyController = TextEditingController();
  final _customDecryptAesKeyController = TextEditingController();
  final _mlKemPublicKeyController = TextEditingController();
  final _mlKemDecryptController = TextEditingController();
  final _dsaPublicKeyController = TextEditingController();
  final _rsaVerifyPublicKeyController = TextEditingController();
  final InputHandler ih = InputHandler();
  bool _isKeyPromptActive = false;
  bool _obscureEncryptAesKey = true;
  bool _obscureDecryptAesKey = true;

  // ML-KEM specific state
  MLKemKeySize _selectedMLKemKeySize = MLKemKeySize.kem768;
  String _mlKemSharedSecret = '';

  // Metadata from the most recent successful decryption (reset on input edit/clear/error)
  Qrypt? _lastDecryptSummary;

  @override
  void dispose() {
    _encryptTextController.dispose();
    _decryptTextController.dispose();
    _encryptPublicKeyController.dispose();
    _decryptPublicKeyController.dispose();
    _customAesKeyController.dispose();
    _customDecryptAesKeyController.dispose();
    _mlKemPublicKeyController.dispose();
    _mlKemDecryptController.dispose();
    _dsaPublicKeyController.dispose();
    _rsaVerifyPublicKeyController.dispose();
    super.dispose();
  }

  Widget buildMLKemKeySizeSelector({
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
          color: getContainerBackgroundColor(context),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ML-KEM Key Size',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            DropdownButtonFormField<MLKemKeySize>(
              initialValue: _selectedMLKemKeySize,
              decoration: buildInputDecoration(
                context: context,
                primaryColor: primaryColor,
              ),
              items: MLKemKeySize.values.map((keySize) {
                return DropdownMenuItem(
                  value: keySize,
                  child: Text(keySize.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMLKemKeySize = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAesKeyField({
    required BuildContext context,
    required Color primaryColor,
    required bool isEncryptMode,
  }) {
    final controller = isEncryptMode
        ? _customAesKeyController
        : _customDecryptAesKeyController;
    final keyProvider = isEncryptMode
        ? customEncryptAesKeyProvider
        : customDecryptAesKeyProvider;
    final isObscured = isEncryptMode
        ? _obscureEncryptAesKey
        : _obscureDecryptAesKey;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscured,
        onChanged: (value) {
          ref.read(keyProvider.notifier).state = value;
          setState(() {});
        },
        decoration: buildInputDecoration(
          context: context,
          primaryColor: primaryColor,
          labelText: 'Custom AES Key',
          hintText: '16, 24, or 32 characters',
          errorText: controller.text.isEmpty
              ? null
              : validateAesKey(controller.text),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isObscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.blueGrey,
                ),
                tooltip: isObscured ? 'Show key' : 'Hide key',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    if (isEncryptMode) {
                      _obscureEncryptAesKey = !_obscureEncryptAesKey;
                    } else {
                      _obscureDecryptAesKey = !_obscureDecryptAesKey;
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.content_paste_go,
                  size: 20,
                  color: Colors.blueGrey,
                ),
                tooltip: 'Paste from clipboard',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final pastedText = await pasteFromClipboard(context);
                  if (pastedText != null) {
                    controller.text = pastedText;
                    ref.read(keyProvider.notifier).state = pastedText;
                    setState(() {});
                  }
                },
              ),
              if (isEncryptMode) ...[
                IconButton(
                  icon: const Icon(
                    Icons.casino_outlined,
                    size: 20,
                    color: Colors.blueGrey,
                  ),
                  tooltip: 'Generate random key',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final randomKey = generateRandomAesKey();
                    controller.text = randomKey;
                    ref.read(keyProvider.notifier).state = randomKey;
                    setState(() {});
                  },
                ),
              ],
              IconButton(
                icon: const Icon(
                  Icons.bookmark_add_outlined,
                  size: 20,
                  color: Colors.blueGrey,
                ),
                tooltip: 'Save key',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final keyText = controller.text.trim();
                  if (keyText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a key before saving'),
                      ),
                    );
                    return;
                  }
                  final error = validateAesKey(keyText);
                  if (error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                    return;
                  }
                  final savedKey = await showDialog<AESKey>(
                    context: context,
                    builder: (ctx) => CreateAESKeyDialog(
                      primaryColor: primaryColor,
                      initialKey: keyText,
                    ),
                  );
                  if (savedKey != null) {
                    controller.text = savedKey.key;
                    ref.read(keyProvider.notifier).state = savedKey.key;
                    final selProvider = isEncryptMode
                        ? selectedAESEncryptKeyProvider
                        : selectedAESDecryptKeyProvider;
                    ref.read(selProvider.notifier).state = savedKey;
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildDefaultAesKeyWarning({
    required BuildContext context,
    required String message,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final warningColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade800;
    final warningBackground = isDarkMode
        ? Colors.red.shade900.withValues(alpha: 0.22)
        : Colors.red.shade50;
    final warningBorder = isDarkMode
        ? Colors.red.shade300.withValues(alpha: 0.55)
        : Colors.red.shade700.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: BoxDecoration(
          color: warningBackground,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: warningBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Icon(
                Icons.warning_amber_rounded,
                color: warningColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: warningColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoDetectAesKeyChip({
    required BuildContext context,
    required Color primaryColor,
  }) {
    final selectedDecrypt = ref.watch(selectedAESDecryptKeyProvider);
    final selectedEncrypt = ref.watch(selectedAESEncryptKeyProvider);
    final typedDecrypt = ref.watch(customDecryptAesKeyProvider).trim();

    String keyLabel;
    if (selectedDecrypt != null && !selectedDecrypt.isCustom) {
      keyLabel = '${selectedDecrypt.name} (${selectedDecrypt.bitLength}-bit)';
    } else if (typedDecrypt.isNotEmpty) {
      keyLabel = 'Custom key';
    } else if (selectedEncrypt != null && !selectedEncrypt.isCustom) {
      keyLabel =
          '${selectedEncrypt.name} (${selectedEncrypt.bitLength}-bit, active)';
    } else {
      keyLabel = 'Auto (last used / prompt)';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: getContainerBackgroundColor(context),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.vpn_key_outlined, size: 16, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AES key (if AES-tagged): $keyLabel',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AESKeyManagementDialog(
                    primaryColor: primaryColor,
                    onKeySelected: (key) {
                      ref.read(selectedAESDecryptKeyProvider.notifier).state =
                          key;
                      _customDecryptAesKeyController.text = key.key;
                      ref.read(customDecryptAesKeyProvider.notifier).state =
                          key.key;
                    },
                  ),
                );
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  ({List<RSAKeyPair> items, RSAKeyPair? selected, bool defaultedToFirst})
  _resolveRsaKeys(List<RSAKeyPair> keys) {
    final preferred =
        ref.watch(selectedRSADecryptKeyPairProvider) ??
        ref.watch(selectedRSAEncryptKeyPairProvider);
    return resolveSelectedKeyPair<RSAKeyPair>(keys, preferred, (kp) => kp.id);
  }

  ({
    List<QryptKEMKeyPair> items,
    QryptKEMKeyPair? selected,
    bool defaultedToFirst,
  })
  _resolveKemKeys(List<QryptKEMKeyPair> keys) {
    final preferred =
        ref.watch(selectedKemDecryptKeyPairProvider) ??
        ref.watch(selectedKemEncryptKeyPairProvider);
    return resolveSelectedKeyPair<QryptKEMKeyPair>(
      keys,
      preferred,
      (kp) => kp.id,
    );
  }

  ({
    List<QryptMLDSAKeyPair> items,
    QryptMLDSAKeyPair? selected,
    bool defaultedToFirst,
  })
  _resolveMlDsaKeys(List<QryptMLDSAKeyPair> keys) {
    final preferred =
        ref.watch(selectedMlDsaSignKeyPairProvider) ??
        ref.watch(selectedMlDsaVerifyKeyPairProvider);
    return resolveSelectedKeyPair<QryptMLDSAKeyPair>(
      keys,
      preferred,
      (kp) => kp.id,
    );
  }

  String _rsaKeySubtitle(RSAKeyPair kp) =>
      'RSA • Created ${formatPublicKeyCreatedDate(kp.createdAt)}';

  String _kemKeySubtitle(QryptKEMKeyPair kp) {
    final alg =
        kp.algorithm ??
        MLKemKeySizeExtension.fromPublicKeyLength(
          kp.publicKey.length,
        )?.displayName ??
        'ML-KEM';
    return '$alg • Created ${formatPublicKeyCreatedDate(kp.createdAt)}';
  }

  String _mlDsaKeySubtitle(QryptMLDSAKeyPair kp) =>
      '${kp.algorithm} • Created ${formatPublicKeyCreatedDate(kp.createdAt)}';

  void _openRsaPublicKeyShare(
    BuildContext context,
    Color primaryColor,
    RSAKeyPair kp,
  ) {
    showQrShareDialog(
      context: context,
      title: 'RSA Public Key: ${kp.name}',
      data: kp.publicKey,
      kind: QrPayloadKind.publicKey,
      subtitle: 'Share this public key with senders',
      primaryColor: primaryColor,
    );
  }

  void _openKemPublicKeyShare(
    BuildContext context,
    Color primaryColor,
    QryptKEMKeyPair kp,
  ) {
    showQrShareDialog(
      context: context,
      title: 'ML-KEM Public Key: ${kp.name}',
      data: base64Encode(kp.kemKeyPair.publicKey),
      kind: QrPayloadKind.publicKey,
      subtitle: 'Share this public key for encapsulation',
      primaryColor: primaryColor,
    );
  }

  void _openMlDsaPublicKeyShare(
    BuildContext context,
    Color primaryColor,
    QryptMLDSAKeyPair kp,
  ) {
    showQrShareDialog(
      context: context,
      title: 'ML-DSA Public Key: ${kp.name}',
      data: base64Encode(kp.publicKey),
      kind: QrPayloadKind.publicKey,
      subtitle: 'Share this verification key with recipients',
      primaryColor: primaryColor,
    );
  }

  Widget _buildPublicKeyShareRow<T>({
    required BuildContext context,
    required Color primaryColor,
    required String algorithmLabel,
    required List<T> items,
    required T? activeKey,
    required String Function(T) getId,
    required String Function(T) getName,
    required String Function(T) getSubtitle,
    required ValueChanged<T> onSelected,
    required void Function(T) onShare,
    required VoidCallback onManage,
  }) {
    return PublicKeyShareRow(
      primaryColor: primaryColor,
      algorithmLabel: algorithmLabel,
      selectedKeyName: activeKey != null ? getName(activeKey) : null,
      canSwitch: items.length > 1,
      onChooseKey: items.length > 1
          ? () async {
              final chosen = await showPublicKeyChoiceDialog<T>(
                context: context,
                primaryColor: primaryColor,
                title: 'Select $algorithmLabel Key',
                keyPairs: items,
                getId: getId,
                getName: getName,
                getSubtitle: getSubtitle,
                selectedKeyPair: activeKey,
                onManageKeys: onManage,
              );
              if (chosen != null && context.mounted) {
                onSelected(chosen);
              }
            }
          : null,
      onSharePublicKey: activeKey != null ? () => onShare(activeKey) : null,
      onCreateKey: onManage,
    );
  }

  Widget _buildRsaPublicKeyRow({
    required BuildContext context,
    required Color primaryColor,
    required List<RSAKeyPair> items,
    required RSAKeyPair? activeKey,
  }) {
    return _buildPublicKeyShareRow<RSAKeyPair>(
      context: context,
      primaryColor: primaryColor,
      algorithmLabel: 'RSA',
      items: items,
      activeKey: activeKey,
      getId: (kp) => kp.id,
      getName: (kp) => kp.name,
      getSubtitle: _rsaKeySubtitle,
      onSelected: (kp) {
        ref.read(selectedRSADecryptKeyPairProvider.notifier).state = kp;
      },
      onShare: (kp) => _openRsaPublicKeyShare(context, primaryColor, kp),
      onManage: () => showDialog(
        context: context,
        builder: (ctx) => RSAKeyManagementDialog(primaryColor: primaryColor),
      ),
    );
  }

  Widget _buildKemPublicKeyRow({
    required BuildContext context,
    required Color primaryColor,
    required List<QryptKEMKeyPair> items,
    required QryptKEMKeyPair? activeKey,
  }) {
    return _buildPublicKeyShareRow<QryptKEMKeyPair>(
      context: context,
      primaryColor: primaryColor,
      algorithmLabel: 'ML-KEM',
      items: items,
      activeKey: activeKey,
      getId: (kp) => kp.id,
      getName: (kp) => kp.name,
      getSubtitle: _kemKeySubtitle,
      onSelected: (kp) {
        ref.read(selectedKemDecryptKeyPairProvider.notifier).state = kp;
      },
      onShare: (kp) => _openKemPublicKeyShare(context, primaryColor, kp),
      onManage: () => showDialog(
        context: context,
        builder: (ctx) => KemKeyManagementDialog(primaryColor: primaryColor),
      ),
    );
  }

  Widget _buildMlDsaPublicKeyRow({
    required BuildContext context,
    required Color primaryColor,
    required List<QryptMLDSAKeyPair> items,
    required QryptMLDSAKeyPair? activeKey,
  }) {
    return _buildPublicKeyShareRow<QryptMLDSAKeyPair>(
      context: context,
      primaryColor: primaryColor,
      algorithmLabel: 'ML-DSA',
      items: items,
      activeKey: activeKey,
      getId: (kp) => kp.id,
      getName: (kp) => kp.name,
      getSubtitle: _mlDsaKeySubtitle,
      onSelected: (kp) {
        ref.read(selectedMlDsaSignKeyPairProvider.notifier).state = kp;
      },
      onShare: (kp) => _openMlDsaPublicKeyShare(context, primaryColor, kp),
      onManage: () => showDialog(
        context: context,
        builder: (ctx) => MlDsaKeyManagementDialog(primaryColor: primaryColor),
      ),
    );
  }

  Widget _buildEncryptMyPublicKeyChip({
    required BuildContext context,
    required Color primaryColor,
    required EncryptionMethod method,
  }) {
    if (method == EncryptionMethod.mlKem) {
      final resolved = ref
          .watch(kemKeyPairsProvider)
          .whenOrNull(data: _resolveKemKeys);
      final items = resolved?.items ?? const <QryptKEMKeyPair>[];
      final activeKey = resolved?.selected;

      return PublicKeyShareCard(
        title: 'Your ML-KEM Public Key',
        collapsedSummary: activeKey?.name ?? 'No keys saved',
        trailingAction: IconButton(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) =>
                KemKeyManagementDialog(primaryColor: primaryColor),
          ),
          icon: Icon(Icons.key, size: 18, color: primaryColor),
          tooltip: 'Manage ML-KEM Keys',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        rows: [
          _buildKemPublicKeyRow(
            context: context,
            primaryColor: primaryColor,
            items: items,
            activeKey: activeKey,
          ),
        ],
      );
    }

    final resolved = ref
        .watch(rsaKeyPairsProvider)
        .whenOrNull(data: _resolveRsaKeys);
    final items = resolved?.items ?? const <RSAKeyPair>[];
    final activeKey = resolved?.selected;

    return PublicKeyShareCard(
      title: 'Your RSA Public Key',
      collapsedSummary: activeKey?.name ?? 'No keys saved',
      trailingAction: IconButton(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => RSAKeyManagementDialog(primaryColor: primaryColor),
        ),
        icon: Icon(Icons.key, size: 18, color: primaryColor),
        tooltip: 'Manage RSA Keys',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
      rows: [
        _buildRsaPublicKeyRow(
          context: context,
          primaryColor: primaryColor,
          items: items,
          activeKey: activeKey,
        ),
      ],
    );
  }

  Widget _buildAutoDetectPublicKeyBar({
    required BuildContext context,
    required Color primaryColor,
  }) {
    final rsaResolved = ref
        .watch(rsaKeyPairsProvider)
        .whenOrNull(data: _resolveRsaKeys);
    final kemResolved = ref
        .watch(kemKeyPairsProvider)
        .whenOrNull(data: _resolveKemKeys);
    final dsaResolved = ref
        .watch(mlDsaKeyPairsProvider)
        .whenOrNull(data: _resolveMlDsaKeys);

    final rows = <Widget>[];
    final algoLabels = <String>[];

    if (rsaResolved != null &&
        rsaResolved.items.isNotEmpty &&
        rsaResolved.selected != null) {
      algoLabels.add('RSA');
      rows.add(
        _buildRsaPublicKeyRow(
          context: context,
          primaryColor: primaryColor,
          items: rsaResolved.items,
          activeKey: rsaResolved.selected,
        ),
      );
    }
    if (kemResolved != null &&
        kemResolved.items.isNotEmpty &&
        kemResolved.selected != null) {
      algoLabels.add('ML-KEM');
      rows.add(
        _buildKemPublicKeyRow(
          context: context,
          primaryColor: primaryColor,
          items: kemResolved.items,
          activeKey: kemResolved.selected,
        ),
      );
    }
    if (dsaResolved != null &&
        dsaResolved.items.isNotEmpty &&
        dsaResolved.selected != null) {
      algoLabels.add('ML-DSA');
      rows.add(
        _buildMlDsaPublicKeyRow(
          context: context,
          primaryColor: primaryColor,
          items: dsaResolved.items,
          activeKey: dsaResolved.selected,
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.smallPadding),
      child: PublicKeyShareCard(
        title: 'Share Public Key',
        collapsedSummary: algoLabels.join(' • '),
        rows: rows,
      ),
    );
  }

  void _clearCurrentOutput(bool isEncryptMode) {
    final empty = Qrypt(
      text: '',
      encryption: EncryptionMethod.aesGcm,
      obfuscation: ObfuscationService.defaultMethod,
      compression: CompressionMethod.gZip,
      sign: SignMethod.none,
    );
    if (isEncryptMode) {
      ref.read(processedEncryptProvider.notifier).state = empty;
    } else {
      ref.read(processedDecryptProvider.notifier).state = empty;
    }
    setState(() {
      _mlKemSharedSecret = '';
      if (!isEncryptMode) {
        _lastDecryptSummary = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDisclaimer();
      _initAutoSelectAesKey();
      ref.read(currentTextControllerProvider.notifier).state =
          _encryptTextController;
    });
  }

  Future<void> _checkDisclaimer() async {
    final accepted = await SettingsStorageService.isDisclaimerAccepted();
    if (!accepted && mounted) {
      await DisclaimerDialog.show(context, isFirstTime: true);
    }
  }

  Future<void> _initAutoSelectAesKey() async {
    final storage = ref.read(aesKeyStorageServiceProvider);
    final keys = await storage.getKeys();
    if (keys.isEmpty || !mounted) return;

    final currentSelected = ref.read(selectedAESEncryptKeyProvider);
    if (currentSelected != null) return;

    final lastUsedId = await storage.getLastUsedKeyId();
    AESKey? keyToSelect;
    if (lastUsedId != null) {
      for (final k in keys) {
        if (k.id == lastUsedId) {
          keyToSelect = k;
          break;
        }
      }
    }
    // If no last-used key matched but exactly one key exists, select it
    if (keyToSelect == null && keys.length == 1) {
      keyToSelect = keys.first;
    }

    if (keyToSelect != null && mounted) {
      ref.read(selectedAESEncryptKeyProvider.notifier).state = keyToSelect;
      _customAesKeyController.text = keyToSelect.key;
      ref.read(customEncryptAesKeyProvider.notifier).state = keyToSelect.key;
      if (ref.read(selectedAESDecryptKeyProvider) == null) {
        ref.read(selectedAESDecryptKeyProvider.notifier).state = keyToSelect;
        _customDecryptAesKeyController.text = keyToSelect.key;
        ref.read(customDecryptAesKeyProvider.notifier).state = keyToSelect.key;
      }
    }
  }

  void _onSwipeLeft() {
    final currentMode = ref.read(appModeProvider);
    if (currentMode == AppMode.encrypt) {
      ref.read(appModeProvider.notifier).state = AppMode.decrypt;
      ref.read(inputTextProvider.notifier).state = _decryptTextController.text;
      HapticFeedback.lightImpact();
    }
  }

  void _onSwipeRight() {
    final currentMode = ref.read(appModeProvider);
    if (currentMode == AppMode.decrypt) {
      ref.read(appModeProvider.notifier).state = AppMode.encrypt;
      ref.read(inputTextProvider.notifier).state = _encryptTextController.text;
      HapticFeedback.lightImpact();
    }
  }

  void _onShortcutTriggerProcess() {
    if (ref.read(isProcessingProvider)) return;
    final isEncryptMode = ref.read(appModeProvider) == AppMode.encrypt;
    final defaultEncryption = ref.read(defaultEncryptionProvider);
    final selectedEncryption = ref.read(selectedEncryptionProvider);
    final selectedCompression = ref.read(selectedCompressionProvider);
    final useTagManually = ref.read(useTagProvider);
    final selectedObfuscation = ref.read(selectedObfuscationProvider);

    if (isEncryptMode) {
      _encrypt(
        defaultEncryption,
        selectedEncryption,
        selectedObfuscation,
        selectedCompression,
        useTagManually,
      );
    } else {
      final autoDetectTag = ref.read(autoDetectTagProvider);
      _decrypt(
        autoDetectTag,
        selectedEncryption,
        selectedObfuscation,
        selectedCompression,
      );
    }
  }

  void _onShortcutCopyOutput() {
    final isEncryptMode = ref.read(appModeProvider) == AppMode.encrypt;
    final outputText = isEncryptMode
        ? ref.read(processedEncryptProvider).text
        : ref.read(processedDecryptProvider).text;
    if (outputText.isNotEmpty) {
      copyToClipboard(outputText, context, isSensitive: !isEncryptMode);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No output to copy')),
      );
    }
  }

  void _onShortcutClearInput() {
    final isEncryptMode = ref.read(appModeProvider) == AppMode.encrypt;
    if (isEncryptMode) {
      _encryptTextController.clear();
      ref.read(inputTextProvider.notifier).state = '';
      setState(() {
        _mlKemSharedSecret = '';
      });
    } else {
      _decryptTextController.clear();
      ref.read(inputTextProvider.notifier).state = '';
      setState(() {
        _mlKemSharedSecret = '';
        _lastDecryptSummary = null;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Input cleared (Ctrl+L)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onShortcutToggleMode() {
    final isEncryptMode = ref.read(appModeProvider) == AppMode.encrypt;
    if (isEncryptMode) {
      _onSwipeLeft();
    } else {
      _onSwipeRight();
    }
  }

  // Get appropriate input field label based on mode
  String _getInputFieldLabel(bool isEncryptMode, bool isMLKemMode) {
    if (isMLKemMode) {
      return isEncryptMode ? "Key Exchange (Optional Note)" : "Ciphertext to Decrypt";
    }
    return "Message";
  }

  // Get appropriate input field hint based on mode
  String _getInputFieldHint(bool isEncryptMode, bool isMLKemMode) {
    if (isMLKemMode) {
      return isEncryptMode
          ? "Optional note (KEM ciphertext is generated automatically)..."
          : "Paste ML-KEM ciphertext (with tag / obfuscation) to decapsulate...";
    }
    return "Enter or paste text...";
  }

  @override
  Widget build(BuildContext context) {
    final appMode = ref.watch(appModeProvider);
    final isEncryptMode = appMode == AppMode.encrypt;
    final Color primaryColor = ref.watch(primaryColorProvider);
    final bool defaultEncryption = ref.watch(defaultEncryptionProvider);
    final autoDetectTag = ref.watch(autoDetectTagProvider);
    final useTagManually = ref.watch(useTagProvider);
    final isProcessing = ref.watch(isProcessingProvider);
    final selectedEncryption = ref.watch(selectedEncryptionProvider);
    final isMLKemMode = selectedEncryption == EncryptionMethod.mlKem;
    final shouldShowKemSecret = isEncryptMode
        ? (isMLKemMode && _mlKemSharedSecret.isNotEmpty)
        : (_mlKemSharedSecret.isNotEmpty &&
            ref.watch(processedDecryptProvider).encryption ==
                EncryptionMethod.mlKem);

    final selectedObfuscation = ref.watch(selectedObfuscationProvider);
    final encryptObfuscation = selectedObfuscation.v2Equivalent;
    final selectedCompression = ref.watch(selectedCompressionProvider);
    final selectedEncryptKey = ref.watch(selectedAESEncryptKeyProvider);
    final isCustomEncryptKey =
        selectedEncryptKey == null || selectedEncryptKey.isCustom;
    final selectedDecryptKey = ref.watch(selectedAESDecryptKeyProvider);
    final isCustomDecryptKey =
        selectedDecryptKey == null || selectedDecryptKey.isCustom;

    ref.listen(selectedEncryptionProvider, (previous, next) {
      if (previous != next && _mlKemSharedSecret.isNotEmpty) {
        setState(() {
          _mlKemSharedSecret = '';
        });
      }
    });
    ref.listen(appModeProvider, (previous, next) {
      if (previous != next && _mlKemSharedSecret.isNotEmpty) {
        setState(() {
          _mlKemSharedSecret = '';
        });
      }
      ref.read(currentTextControllerProvider.notifier).state =
          next == AppMode.encrypt
              ? _encryptTextController
              : _decryptTextController;
    });
    ref.listen(selectedAESEncryptKeyProvider, (previous, next) {
      if (next != null && _customAesKeyController.text != next.key) {
        _customAesKeyController.text = next.key;
      }
    });
    ref.listen(selectedAESDecryptKeyProvider, (previous, next) {
      if (next != null && _customDecryptAesKeyController.text != next.key) {
        _customDecryptAesKeyController.text = next.key;
      }
    });
    ref.listen(rsaDecryptPublicKeyProvider, (previous, next) {
      if (_decryptPublicKeyController.text != next) {
        _decryptPublicKeyController.text = next;
      }
    });
    ref.listen(rsaVerifyPublicKeyProvider, (previous, next) {
      if (_rsaVerifyPublicKeyController.text != next) {
        _rsaVerifyPublicKeyController.text = next;
      }
    });
    ref.listen(verifyMlDsaPublicKeyProvider, (previous, next) {
      if (_dsaPublicKeyController.text != next) {
        _dsaPublicKeyController.text = next;
      }
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _onShortcutTriggerProcess,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            _onShortcutTriggerProcess,
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
          shift: true,
        ): _onShortcutCopyOutput,
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          meta: true,
          shift: true,
        ): _onShortcutCopyOutput,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _onShortcutClearInput,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            _onShortcutClearInput,
        const SingleActivator(LogicalKeyboardKey.keyM, control: true):
            _onShortcutToggleMode,
        const SingleActivator(LogicalKeyboardKey.keyM, meta: true):
            _onShortcutToggleMode,
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalMargin = constraints.maxWidth > 840
                    ? (constraints.maxWidth - 840) / 2 +
                          AppConstants.smallPadding
                    : AppConstants.smallPadding;
                return ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalMargin,
                    vertical: AppConstants.smallPadding,
                  ),
                  children: [
                    // Header with mode switch and settings (swipe restricted to header bar)
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: (DragEndDetails details) {
                        const double sensitivity = 100.0;
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! > sensitivity) {
                            _onSwipeRight();
                          } else if (details.primaryVelocity! < -sensitivity) {
                            _onSwipeLeft();
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.smallPadding,
                          vertical: AppConstants.smallPadding,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Key Management',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const KeyManagementPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.vpn_key_outlined),
                            ),
                            Expanded(
                              child: Center(
                                child: modeSwitch(
                                  context,
                                  appMode,
                                  primaryColor,
                                  ref,
                                  _encryptTextController,
                                  _decryptTextController,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.settings),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const WebStorageNoticeBanner(),

                // ML-KEM Info Container (only show in ML-KEM mode)
                if (isMLKemMode) ...[
                  const SizedBox(height: AppConstants.defaultPadding),
                  buildMLKemInfoContainer(
                    context: context,
                    primaryColor: primaryColor,
                  ),
                ],

                const SizedBox(height: AppConstants.defaultPadding),

                // Message input section
                buildSectionHeader(
                  title: _getInputFieldLabel(isEncryptMode, isMLKemMode),
                  characterCount:
                      ref.watch(inputTextProvider).length.toString(),
                  actions: [
                    buildActionButton(
                      icon: Icons.clear,
                      color: primaryColor,
                      onTap: () {
                        if (isEncryptMode) {
                          _encryptTextController.clear();
                          ref.read(inputTextProvider.notifier).state = '';
                          setState(() {
                            _mlKemSharedSecret = '';
                          });
                        } else {
                          _decryptTextController.clear();
                          ref.read(inputTextProvider.notifier).state = '';
                          setState(() {
                            _mlKemSharedSecret = '';
                            _lastDecryptSummary = null;
                          });
                        }
                      },
                      semanticLabel: 'Clear text',
                      tooltip: 'Clear input (Ctrl+L)',
                    ),
                    buildActionButton(
                      icon: Icons.content_paste,
                      color: primaryColor,
                      onTap: () async {
                        final pastedText = await pasteFromClipboard(context);
                        if (pastedText != null) {
                          if (isEncryptMode) {
                            _encryptTextController.text = pastedText;
                            ref.read(inputTextProvider.notifier).state =
                                _encryptTextController.text;
                          } else {
                            _decryptTextController.text = pastedText;
                            ref.read(inputTextProvider.notifier).state =
                                _decryptTextController.text;
                            if (_lastDecryptSummary != null) {
                              setState(() {
                                _lastDecryptSummary = null;
                              });
                            }
                          }
                        }
                      },
                      semanticLabel: 'Paste from clipboard',
                      tooltip: 'Paste from clipboard',
                    ),
                  ],
                ),

                const SizedBox(height: AppConstants.smallPadding),

                // Message input field
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding,
                  ),
                  child: TextField(
                    onChanged: (text) {
                      ref.read(inputTextProvider.notifier).state = text;
                      if (!isEncryptMode && _lastDecryptSummary != null) {
                        setState(() {
                          _lastDecryptSummary = null;
                        });
                      }
                    },
                    controller: isEncryptMode
                        ? _encryptTextController
                        : _decryptTextController,
                    maxLines: AppConstants.maxInputLines,
                    readOnly: isMLKemMode && isEncryptMode,
                    decoration: buildInputDecoration(
                      context: context,
                      primaryColor: primaryColor,
                      hintText: _getInputFieldHint(isEncryptMode, isMLKemMode),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.defaultPadding),

                // Mode-specific configuration sections
                if (isEncryptMode) ...[
                  // Encrypt mode configurations
                  if (!isMLKemMode) ...[
                    buildSwitchContainer(
                      context: context,
                      title: "Default Preset",
                      subtitle: "AES-GCM • GZip • EN2 • Tag",
                      value: defaultEncryption,
                      onChanged: (val) {
                        ref.read(defaultEncryptionProvider.notifier).state =
                            val;

                        // When leaving default mode, preload the same pipeline
                        // used by default encryption so the visible options match.
                        if (!val) {
                          ref.read(selectedCompressionProvider.notifier).state =
                              CompressionMethod.gZip;
                          ref.read(selectedEncryptionProvider.notifier).state =
                              EncryptionMethod.aesGcm;
                          ref.read(selectedObfuscationProvider.notifier).state =
                              ObfuscationService.defaultMethod;
                          ref.read(selectedSignProvider.notifier).state =
                              SignMethod.none;
                          ref.read(useTagProvider.notifier).state = true;
                        }
                      },
                      primaryColor: primaryColor,
                    ),
                    if (defaultEncryption) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: AESEncryptKeySelector(
                          primaryColor: primaryColor,
                          onKeyChanged: (k) {
                            _customAesKeyController.text = k.key;
                          },
                        ),
                      ),
                      if (isCustomEncryptKey) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildCustomAesKeyField(
                          context: context,
                          primaryColor: primaryColor,
                          isEncryptMode: true,
                        ),
                      ],
                    ],
                    const SizedBox(height: AppConstants.defaultPadding),
                  ],

                  if (!defaultEncryption) ...[
                    // Include Tag Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                          vertical: AppConstants.smallPadding,
                        ),
                        decoration: BoxDecoration(
                          color: useTagManually
                              ? primaryColor.withValues(alpha: 0.1)
                              : getContainerBackgroundColor(context),
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                          border: Border.all(
                            color: useTagManually
                                ? primaryColor.withValues(alpha: 0.3)
                                : getBorderColor(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Include Tag",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Switch(
                              value: useTagManually,
                              onChanged: (val) =>
                                  ref.read(useTagProvider.notifier).state =
                                      val,
                              activeThumbColor: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.defaultPadding),

                    // Compression dropdown (locked to NONE for ML-KEM)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: CompressionsDropdownButtonForm(
                        selectedCompression: selectedCompression,
                        primaryColor: primaryColor,
                        enabled: selectedEncryption != EncryptionMethod.mlKem,
                      ),
                    ),

                    const SizedBox(height: AppConstants.defaultPadding),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: EncryptionsDropdownButtonForm(
                        selectedEncryption: selectedEncryption,
                        primaryColor: primaryColor,
                      ),
                    ),

                    // AES Key Section - Show only for AES encryption methods
                    if (selectedEncryption == EncryptionMethod.aesGcm ||
                        selectedEncryption == EncryptionMethod.aesCbc ||
                        selectedEncryption == EncryptionMethod.aesCtr) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: AESEncryptKeySelector(
                          primaryColor: primaryColor,
                          onKeyChanged: (k) {
                            _customAesKeyController.text = k.key;
                          },
                        ),
                      ),
                      if (isCustomEncryptKey) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildCustomAesKeyField(
                          context: context,
                          primaryColor: primaryColor,
                          isEncryptMode: true,
                        ),
                      ],
                    ],

                    // ML-KEM recipient public key field
                    if (selectedEncryption == EncryptionMethod.mlKem) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      buildPublicKeyField(
                        context: context,
                        controller: _mlKemPublicKeyController,
                        primaryColor: primaryColor,
                        onChanged: (val) {},
                        validationPattern: r'^[A-Za-z0-9+/=\n\r\s-]+',
                        isEncryptMode: true,
                        labelText: 'Recipient\'s ML-KEM Public Key',
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildEncryptMyPublicKeyChip(
                        context: context,
                        primaryColor: primaryColor,
                        method: EncryptionMethod.mlKem,
                      ),
                    ],

                    // RSA specific fields
                    if (selectedEncryption == EncryptionMethod.rsa ||
                        selectedEncryption == EncryptionMethod.rsaSign) ...[
                      if (selectedEncryption == EncryptionMethod.rsaSign) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding,
                          ),
                          child: RSAEncryptKeySelector(
                            primaryColor: primaryColor,
                          ),
                        ),
                      ],

                      const SizedBox(height: AppConstants.defaultPadding),
                      buildPublicKeyField(
                        context: context,
                        controller: _encryptPublicKeyController,
                        primaryColor: primaryColor,
                        onChanged: (val) {
                          try {
                            String normalized = val.trim().replaceAll(
                              RegExp(r'\r\n|\r|\n'),
                              '\n',
                            );
                            ref.read(publicKeyProvider.notifier).state =
                                normalized;
                          } catch (e) {
                            if (kDebugMode) {
                              print('Error normalizing public key: $e');
                            }
                          }
                        },
                        validationPattern:
                            r'^-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/=\n]+\n-----END PUBLIC KEY-----',
                        isEncryptMode: true,
                      ),
                      if (selectedEncryption == EncryptionMethod.rsa) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildEncryptMyPublicKeyChip(
                          context: context,
                          primaryColor: primaryColor,
                          method: EncryptionMethod.rsa,
                        ),
                      ],
                    ],

                    // Signs dropdown (for all except rsaSign)
                    if (selectedEncryption != EncryptionMethod.rsaSign) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: SignsDropdownButtonForm(
                          selectedSign: ref.read(selectedSignProvider),
                          primaryColor: primaryColor,
                        ),
                      ),
                      if (ref.watch(selectedSignProvider) ==
                          SignMethod.rsaPss) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding,
                          ),
                          child: RSASignKeySelector(
                            primaryColor: primaryColor,
                          ),
                        ),
                      ],
                      if (ref.watch(selectedSignProvider) ==
                          SignMethod.mlDsa) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding,
                          ),
                          child: MlDsaSignKeySelector(
                            primaryColor: primaryColor,
                          ),
                        ),
                      ],
                    ],

                    // Obfuscation dropdown (for all manual modes)
                    const SizedBox(height: AppConstants.defaultPadding),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: ObfsDropdownButtonForm(
                        selectedObfuscation: encryptObfuscation,
                        primaryColor: primaryColor,
                      ),
                    ),

                    if (encryptObfuscation == ObfuscationMethod.custom) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: CustomMapDropdownButtonForm(
                          primaryColor: primaryColor,
                        ),
                      ),
                    ],

                    if (selectedEncryption == EncryptionMethod.none &&
                        encryptObfuscation == ObfuscationMethod.none) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      _buildDefaultAesKeyWarning(
                        context: context,
                        message:
                            'Warning: No encryption or obfuscation is selected. Output will be Base64-encoded by default.',
                      ),
                    ] else if (selectedEncryption == EncryptionMethod.none) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      _buildDefaultAesKeyWarning(
                        context: context,
                        message:
                            'Warning: Encryption is disabled. Obfuscation only disguises format and does not provide cryptographic confidentiality.',
                      ),
                    ],
                  ],

                  const SizedBox(height: AppConstants.defaultPadding),

                  // Action Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    width: double.infinity,
                    child: Tooltip(
                      message: isMLKemMode
                          ? 'Encapsulate & Encrypt (Ctrl+Enter)'
                          : 'Encrypt (Ctrl+Enter)',
                      child: ElevatedButton(
                        onPressed: isProcessing
                            ? null
                            : () {
                                _encrypt(
                                  defaultEncryption,
                                  selectedEncryption,
                                  encryptObfuscation,
                                  selectedCompression,
                                  useTagManually,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(
                            AppConstants.defaultPadding,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius,
                            ),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isMLKemMode ? Icons.key : Icons.lock),
                                  const SizedBox(
                                    width: AppConstants.smallPadding,
                                  ),
                                  Flexible(
                                    child: Text(
                                      isMLKemMode
                                          ? "Encapsulate & Encrypt"
                                          : "Encrypt",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Decrypt mode configurations
                  buildSwitchContainer(
                    context: context,
                    title: "Auto-detect Settings (from Tag)",
                    value: autoDetectTag,
                    onChanged: (val) =>
                        ref.read(autoDetectTagProvider.notifier).state = val,
                    primaryColor: primaryColor,
                  ),
                  if (autoDetectTag) ...[
                    const SizedBox(height: AppConstants.smallPadding),
                    _buildAutoDetectAesKeyChip(
                      context: context,
                      primaryColor: primaryColor,
                    ),
                    _buildAutoDetectPublicKeyBar(
                      context: context,
                      primaryColor: primaryColor,
                    ),
                  ],
                  const SizedBox(height: AppConstants.defaultPadding),

                  if (!autoDetectTag) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: CompressionsDropdownButtonForm(
                        selectedCompression: selectedCompression,
                        primaryColor: primaryColor,
                        enabled: selectedEncryption != EncryptionMethod.mlKem,
                      ),
                    ),

                    const SizedBox(height: AppConstants.defaultPadding),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: EncryptionsDropdownButtonForm(
                        selectedEncryption: selectedEncryption,
                        primaryColor: primaryColor,
                      ),
                    ),

                    // AES Key Section for Decrypt
                    if (selectedEncryption == EncryptionMethod.aesGcm ||
                        selectedEncryption == EncryptionMethod.aesCbc ||
                        selectedEncryption == EncryptionMethod.aesCtr) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: AESDecryptKeySelector(
                          primaryColor: primaryColor,
                          onKeyChanged: (k) {
                            _customDecryptAesKeyController.text = k.key;
                          },
                        ),
                      ),
                      if (isCustomDecryptKey) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildCustomAesKeyField(
                          context: context,
                          primaryColor: primaryColor,
                          isEncryptMode: false,
                        ),
                      ],
                    ],

                    // ML-KEM key selector for manual decrypt
                    if (selectedEncryption == EncryptionMethod.mlKem) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: KemDecryptKeySelector(
                          primaryColor: primaryColor,
                        ),
                      ),
                    ],

                    // RSA decrypt configurations
                    if (selectedEncryption == EncryptionMethod.rsa ||
                        selectedEncryption == EncryptionMethod.rsaSign) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: RSADecryptKeySelector(
                          primaryColor: primaryColor,
                        ),
                      ),

                      if (selectedEncryption == EncryptionMethod.rsaSign) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        buildPublicKeyField(
                          context: context,
                          controller: _decryptPublicKeyController,
                          primaryColor: primaryColor,
                          onChanged: (val) {
                            try {
                              String normalized = val.trim().replaceAll(
                                RegExp(r'\r\n|\r|\n'),
                                '\n',
                              );
                              ref
                                      .read(
                                        rsaDecryptPublicKeyProvider.notifier,
                                      )
                                      .state =
                                  normalized;
                            } catch (e) {
                              if (kDebugMode) {
                                print('Error normalizing public key: $e');
                              }
                            }
                          },
                          validationPattern:
                              r'^-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/=\n]+\n-----END PUBLIC KEY-----',
                          isEncryptMode: false,
                        ),
                      ],
                    ],

                    if (!(ref.watch(selectedEncryptionProvider) ==
                        EncryptionMethod.rsaSign)) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: SignsDropdownButtonForm(
                          selectedSign: ref.read(selectedSignProvider),
                          primaryColor: primaryColor,
                        ),
                      ),
                    ],
                    if (ref.watch(selectedSignProvider) ==
                        SignMethod.rsaPss) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      buildPublicKeyField(
                        context: context,
                        controller: _rsaVerifyPublicKeyController,
                        primaryColor: primaryColor,
                        onChanged: (val) {
                          try {
                            String normalized = val.trim().replaceAll(
                              RegExp(r'\r\n|\r|\n'),
                              '\n',
                            );
                            ref
                                .read(rsaVerifyPublicKeyProvider.notifier)
                                .state = normalized;
                          } catch (e) {
                            if (kDebugMode) {
                              print('Error normalizing RSA verify key: $e');
                            }
                          }
                        },
                        validationPattern: r'^[A-Za-z0-9+/=\n\r\s-]+',
                        isEncryptMode: isEncryptMode,
                        labelText: 'RSA Sender Public Key (Verify)',
                      ),
                    ],
                    if (ref.watch(selectedSignProvider) ==
                        SignMethod.mlDsa) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      buildPublicKeyField(
                        context: context,
                        controller: _dsaPublicKeyController,
                        primaryColor: primaryColor,
                        onChanged: (val) {
                          ref
                                  .read(verifyMlDsaPublicKeyProvider.notifier)
                                  .state =
                              _dsaPublicKeyController.text;
                        },
                        validationPattern: r'^[A-Za-z0-9+/=\n\r\s-]+',
                        isEncryptMode: isEncryptMode,
                      ),
                    ],

                    const SizedBox(height: AppConstants.defaultPadding),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: ObfsDropdownButtonForm(
                        selectedObfuscation: selectedObfuscation,
                        primaryColor: primaryColor,
                        isDecryptMode: true,
                      ),
                    ),

                    if (selectedObfuscation == ObfuscationMethod.custom) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: CustomMapDropdownButtonForm(
                          primaryColor: primaryColor,
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: AppConstants.defaultPadding),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    width: double.infinity,
                    child: Tooltip(
                      message: 'Decrypt (Ctrl+Enter)',
                      child: ElevatedButton(
                        onPressed: isProcessing
                            ? null
                            : () {
                                _decrypt(
                                  autoDetectTag,
                                  selectedEncryption,
                                  selectedObfuscation,
                                  selectedCompression,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(
                            AppConstants.defaultPadding,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius,
                            ),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_open),
                                  SizedBox(
                                    width: AppConstants.smallPadding,
                                  ),
                                  Flexible(
                                    child: Text(
                                      "Decrypt",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],

                // Output section
                EncryptionOutputPanel(
                  primaryColor: primaryColor,
                  isEncryptMode: isEncryptMode,
                  isMLKemMode: isMLKemMode,
                  shouldShowKemSecret: shouldShowKemSecret,
                  mlKemSharedSecret: _mlKemSharedSecret,
                  lastDecryptSummary: _lastDecryptSummary,
                  onClearOutput: () => _clearCurrentOutput(isEncryptMode),
                  onKemKeySaved: () => setState(() {}),
                ),
              ],
            );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _encrypt(
    bool defaultEncryption,
    EncryptionMethod selectedEncryption,
    ObfuscationMethod selectedObfuscation,
    CompressionMethod selectedCompression,
    bool useTagManually,
  ) async {
    // Prevent concurrent runs or dialog double-taps
    if (_isKeyPromptActive || ref.read(isProcessingProvider)) return;

    final effectiveObfuscation = selectedObfuscation.v2Equivalent;

    final effectiveEncryption = defaultEncryption
        ? EncryptionMethod.aesGcm
        : selectedEncryption;

    // Input validation (optional for ML-KEM encapsulation)
    if (effectiveEncryption != EncryptionMethod.mlKem &&
        _encryptTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to encrypt')),
      );
      return;
    }

    final isAes =
        effectiveEncryption == EncryptionMethod.aesGcm ||
        effectiveEncryption == EncryptionMethod.aesCbc ||
        effectiveEncryption == EncryptionMethod.aesCtr;

    String aesKeyToUse = '';
    AESKey? activeAesKey = ref.read(selectedAESEncryptKeyProvider);

    if (isAes) {
      _isKeyPromptActive = true;
      try {
        final storage = ref.read(aesKeyStorageServiceProvider);
        final typedKey = _customAesKeyController.text.trim();

        // Re-validate active key from storage in case it was deleted
        if (activeAesKey != null && !activeAesKey.isCustom) {
          final storedKey = await storage.getKeyById(activeAesKey.id);
          if (storedKey != null) {
            activeAesKey = storedKey;
            aesKeyToUse = storedKey.key;
          } else {
            ref.read(selectedAESEncryptKeyProvider.notifier).state = null;
            activeAesKey = null;
          }
        } else if (activeAesKey?.isCustom == true) {
          activeAesKey = null;
        }

        if (aesKeyToUse.isEmpty && typedKey.isNotEmpty) {
          aesKeyToUse = typedKey;
        }

        if (aesKeyToUse.isEmpty) {
          // Intercept: prompt user to create or select an AES key before running pipeline
          final savedKeys = await storage.getKeys();
          if (!mounted) return;

          AESKey? chosenKey;
          if (savedKeys.isNotEmpty) {
            await showDialog(
              context: context,
              builder: (ctx) => AESKeyManagementDialog(
                primaryColor: ref.read(primaryColorProvider),
                onKeySelected: (k) {
                  chosenKey = k;
                },
              ),
            );
          } else {
            chosenKey = await showDialog<AESKey>(
              context: context,
              builder: (ctx) => CreateAESKeyDialog(
                primaryColor: ref.read(primaryColorProvider),
              ),
            );
          }

          if (!mounted) return;
          if (chosenKey == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Encryption cancelled: AES key required.'),
              ),
            );
            return;
          }

          activeAesKey = chosenKey;
          ref.read(selectedAESEncryptKeyProvider.notifier).state = chosenKey;
          _customAesKeyController.text = chosenKey!.key;
          ref.read(customEncryptAesKeyProvider.notifier).state = chosenKey!.key;
          aesKeyToUse = chosenKey!.key;
        }

        final validationError = validateAesKey(aesKeyToUse);
        if (validationError != null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(validationError)));
          }
          return;
        }
      } finally {
        _isKeyPromptActive = false;
      }
    }

    ref.read(isProcessingProvider.notifier).state = true;

    try {
      if (!defaultEncryption) {
        final bool isRsaSign = selectedEncryption == EncryptionMethod.rsaSign;

        if (selectedEncryption == EncryptionMethod.mlKem) {
          final recipientPubKey = _mlKemPublicKeyController.text.trim();
          if (recipientPubKey.isEmpty) {
            throw Exception('Please enter the recipient\'s ML-KEM public key');
          }
          Map<String, String>? customMapToUse;
          if (effectiveObfuscation == ObfuscationMethod.custom) {
            final customProfile = ref.read(selectedCustomMapProvider);
            if (customProfile == null) {
              throw Exception(
                'Please select or import a custom map for Custom obfuscation.',
              );
            }
            customMapToUse = customProfile.map;
          }

          ref.read(inputQryptProvider.notifier).state = Qrypt.withKem(
            text: _encryptTextController.text,
            obfuscation: effectiveObfuscation,
            sign: ref.read(selectedSignProvider),
            useTag: useTagManually,
            customMap: customMapToUse,
            kemReceiverPublicKey: recipientPubKey,
          );
        } else if (selectedEncryption == EncryptionMethod.rsa || isRsaSign) {
          final selectedKeyPair = ref.read(selectedRSAEncryptKeyPairProvider);
          if (selectedEncryption == EncryptionMethod.rsaSign) {
            if (selectedKeyPair == null) {
              throw Exception('Please select an RSA key pair');
            }
          }

          String rsaReceiversPublicKey = ref.read(publicKeyProvider).trim();

          if (rsaReceiversPublicKey.isEmpty) {
            throw Exception('Please enter the receiver\'s public key');
          }

          if (!rsaReceiversPublicKey.contains('BEGIN PUBLIC KEY')) {
            throw Exception(
              'Invalid public key format. Please ensure it\'s in PEM format.',
            );
          }

          Map<String, String>? customMapToUse;
          if (effectiveObfuscation == ObfuscationMethod.custom) {
            final customProfile = ref.read(selectedCustomMapProvider);
            if (customProfile == null) {
              throw Exception(
                'Please select or import a custom map for Custom obfuscation.',
              );
            }
            customMapToUse = customProfile.map;
          }

          ref.read(inputQryptProvider.notifier).state = Qrypt.withRSA(
            text: _encryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: effectiveObfuscation,
            compression: selectedCompression,
            sign: ref.read(selectedSignProvider),
            useTag: useTagManually,
            customMap: customMapToUse,
            rsaKeyPair:
                selectedKeyPair ??
                RSAKeyPair(
                  id: 'n',
                  name: 'n',
                  publicKey: 'n',
                  privateKey: 'n',
                  createdAt: DateTime.now(),
                ),
            rsaReceiverPublicKey: rsaReceiversPublicKey,
          );
        } else {
          Map<String, String>? customMapToUse;
          if (effectiveObfuscation == ObfuscationMethod.custom) {
            final customProfile = ref.read(selectedCustomMapProvider);
            if (customProfile == null) {
              throw Exception(
                'Please select or import a custom map for Custom obfuscation.',
              );
            }
            customMapToUse = customProfile.map;
          }

          final q = Qrypt.withTag(
            text: _encryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: effectiveObfuscation,
            compression: selectedCompression,
            sign: ref.read(selectedSignProvider),
            useTag: useTagManually,
            customMap: customMapToUse,
          );
          if (isAes) {
            q.customKey = aesKeyToUse;
            q.useCustomKey = true;
          }
          ref.read(inputQryptProvider.notifier).state = q;
        }

        if (ref.read(selectedSignProvider) == SignMethod.rsaPss) {
          ref.read(inputQryptProvider.notifier).state.rsaSignKeyPair = ref.read(
            selectedRSASignKeyPairProvider,
          );
        }

        if (ref.read(selectedSignProvider) == SignMethod.mlDsa) {
          ref.read(inputQryptProvider.notifier).state.dsaKeyPair = ref.read(
            selectedMlDsaSignKeyPairProvider,
          );
        }

        final processed = await ih.handleProcess(ref.read(inputQryptProvider));
        ref.read(processedEncryptProvider.notifier).state = processed;

        if (selectedEncryption == EncryptionMethod.mlKem &&
            processed.kemSharedSecret != null &&
            processed.kemSharedSecret!.isNotEmpty) {
          setState(() {
            _mlKemSharedSecret = base64.encode(processed.kemSharedSecret!);
          });
        } else if (_mlKemSharedSecret.isNotEmpty) {
          setState(() {
            _mlKemSharedSecret = '';
          });
        }
      } else {
        // Default encryption logic (AES-GCM + GZip + EN2 + Tag)
        if (_mlKemSharedSecret.isNotEmpty) {
          setState(() {
            _mlKemSharedSecret = '';
          });
        }
        final q = Qrypt.withTag(
          text: _encryptTextController.text,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationService.defaultMethod,
          compression: CompressionMethod.gZip,
          sign: SignMethod.none,
          useTag: true,
        );
        q.customKey = aesKeyToUse;
        q.useCustomKey = true;
        ref.read(inputQryptProvider.notifier).state = q;

        ref.read(processedEncryptProvider.notifier).state = await ih
            .handleProcess(ref.read(inputQryptProvider));
      }

      // Record last used key ID on success
      if (isAes && activeAesKey != null) {
        final storage = ref.read(aesKeyStorageServiceProvider);
        await storage.setLastUsedKeyId(activeAesKey.id);
        if (ref.read(selectedAESDecryptKeyProvider) == null) {
          ref.read(selectedAESDecryptKeyProvider.notifier).state = activeAesKey;
          _customDecryptAesKeyController.text = activeAesKey.key;
          ref.read(customDecryptAesKeyProvider.notifier).state = activeAesKey.key;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encryption failed: ${e.toString()}')),
        );
      }
    } finally {
      ref.read(isProcessingProvider.notifier).state = false;
    }
  }

  void _decrypt(
    bool autoDetectTag,
    EncryptionMethod selectedEncryption,
    ObfuscationMethod selectedObfuscation,
    CompressionMethod selectedCompression,
  ) async {
    if (ref.read(isProcessingProvider)) return;

    // Input validation
    final cleanDecryptText = _decryptTextController.text.trim();
    if (cleanDecryptText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to decrypt')),
      );
      return;
    }

    ref.read(isProcessingProvider.notifier).state = true;
    if (_lastDecryptSummary != null) {
      setState(() {
        _lastDecryptSummary = null;
      });
    }

    try {
      AESKey? selectedDecryptKey = ref.read(selectedAESDecryptKeyProvider);
      if (selectedDecryptKey != null && !selectedDecryptKey.isCustom) {
        final storage = ref.read(aesKeyStorageServiceProvider);
        final stored = await storage.getKeyById(selectedDecryptKey.id);
        if (stored != null) {
          selectedDecryptKey = stored;
        } else {
          ref.read(selectedAESDecryptKeyProvider.notifier).state = null;
          selectedDecryptKey = null;
        }
      } else if (selectedDecryptKey?.isCustom == true) {
        selectedDecryptKey = null;
      }

      final typedDecryptKey = _customDecryptAesKeyController.text.trim();
      String decryptKeyToUse =
          (selectedDecryptKey != null && selectedDecryptKey.key.isNotEmpty)
          ? selectedDecryptKey.key
          : typedDecryptKey;

      if (decryptKeyToUse.isEmpty) {
        final activeEncryptKey = ref.read(selectedAESEncryptKeyProvider);
        if (activeEncryptKey != null &&
            !activeEncryptKey.isCustom &&
            activeEncryptKey.key.isNotEmpty) {
          decryptKeyToUse = activeEncryptKey.key;
        } else {
          final storage = ref.read(aesKeyStorageServiceProvider);
          final lastId = await storage.getLastUsedKeyId();
          if (lastId != null) {
            final lastKey = await storage.getKeyById(lastId);
            if (lastKey != null && lastKey.key.isNotEmpty) {
              decryptKeyToUse = lastKey.key;
            }
          }
        }
      }

      if (!autoDetectTag) {
        final manualQrypt = Qrypt.withTag(
          text: cleanDecryptText,
          encryption: selectedEncryption,
          obfuscation: selectedObfuscation,
          compression: selectedCompression,
          sign: ref.read(selectedSignProvider),
          useTag: false,
        );

        if (selectedObfuscation == ObfuscationMethod.custom) {
          final customProfile = ref.read(selectedCustomMapProvider);
          if (customProfile == null) {
            throw Exception('Please select a custom map to decrypt.');
          }
          manualQrypt.customMap = customProfile.map;
        }

        final isAes =
            selectedEncryption == EncryptionMethod.aesGcm ||
            selectedEncryption == EncryptionMethod.aesCbc ||
            selectedEncryption == EncryptionMethod.aesCtr;

        if (isAes && decryptKeyToUse.isNotEmpty) {
          manualQrypt.customKey = decryptKeyToUse;
          manualQrypt.useCustomKey = true;
        }

        if (selectedEncryption == EncryptionMethod.mlKem) {
          final selectedKemKey = ref.read(selectedKemDecryptKeyPairProvider);
          if (selectedKemKey != null) {
            manualQrypt.kemKeyPair = selectedKemKey;
          }
        }

        if (selectedEncryption == EncryptionMethod.rsa ||
            selectedEncryption == EncryptionMethod.rsaSign) {
          final selectedRsaKey = ref.read(selectedRSADecryptKeyPairProvider);
          if (selectedRsaKey == null) {
            throw Exception('Please select an RSA key pair for decryption');
          }
          manualQrypt.rsaKeyPair = selectedRsaKey;
        }

        if (selectedEncryption == EncryptionMethod.rsaSign) {
          final decryptPubKey = ref.read(rsaDecryptPublicKeyProvider);
          if (decryptPubKey.isNotEmpty) {
            manualQrypt.rsaSenderPublicKey = decryptPubKey;
          }
        }

        if (ref.read(selectedSignProvider) == SignMethod.rsaPss) {
          final verifyKey = ref.read(rsaVerifyPublicKeyProvider);
          if (verifyKey.isNotEmpty) {
            manualQrypt.rsaVerifyPublicKey = verifyKey;
          }
        }

        if (ref.read(selectedSignProvider) == SignMethod.mlDsa) {
          final rawVerifyKey = ref.read(verifyMlDsaPublicKeyProvider).trim();
          if (rawVerifyKey.isEmpty) {
            throw Exception(
              'Please enter the sender\'s ML-DSA public key for verification',
            );
          }
          try {
            manualQrypt.dsaVerifyPublicKey = base64Decode(rawVerifyKey);
          } on FormatException {
            throw const FormatException(
              'Invalid Base64 format for ML-DSA verification public key',
            );
          }
        }

        ref.read(inputQryptProvider.notifier).state = manualQrypt;
        if (!mounted) return;
        final deProcessed = await ih
            .handleDeProcess(context, ref.read(inputQryptProvider), false);
        if (!mounted) return;
        ref.read(processedDecryptProvider.notifier).state = deProcessed;
        setState(() {
          _lastDecryptSummary = deProcessed;
          if (deProcessed.kemSharedSecret != null &&
              deProcessed.kemSharedSecret!.isNotEmpty) {
            _mlKemSharedSecret = base64.encode(deProcessed.kemSharedSecret!);
          } else {
            _mlKemSharedSecret = '';
          }
        });
      } else {
        final autoQrypt = Qrypt.autoDecrypt(text: cleanDecryptText);
        if (decryptKeyToUse.isNotEmpty) {
          autoQrypt.customKey = decryptKeyToUse;
          autoQrypt.useCustomKey = true;
        }

        ref.read(inputQryptProvider.notifier).state = autoQrypt;
        if (!mounted) return;
        final deProcessed = await ih
            .handleDeProcess(context, ref.read(inputQryptProvider), true);
        if (!mounted) return;
        ref.read(processedDecryptProvider.notifier).state = deProcessed;
        setState(() {
          _lastDecryptSummary = deProcessed;
          if (deProcessed.kemSharedSecret != null &&
              deProcessed.kemSharedSecret!.isNotEmpty) {
            _mlKemSharedSecret = base64.encode(deProcessed.kemSharedSecret!);
          } else {
            _mlKemSharedSecret = '';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastDecryptSummary = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decryption failed: ${e.toString()}')),
        );
      }
    } finally {
      ref.read(isProcessingProvider.notifier).state = false;
    }
  }
}
