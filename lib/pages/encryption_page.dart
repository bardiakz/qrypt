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
import '../models/aes_key.dart';
import '../models/encryption_method.dart';
import '../models/kyber_models.dart';
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
  final InputHandler ih = InputHandler();
  bool _isKeyPromptActive = false;
  bool _obscureEncryptAesKey = true;
  bool _obscureDecryptAesKey = true;

  // ML-KEM specific state
  MLKemKeySize _selectedMLKemKeySize = MLKemKeySize.kem768;
  String _mlKemSharedSecret = '';
  String _mlKemCiphertext = '';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAutoSelectAesKey();
    });
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

  // Check if current encryption method is ML-KEM
  bool _isMLKemMode() {
    final selectedEncryption = ref.watch(selectedEncryptionProvider);
    return selectedEncryption == EncryptionMethod.mlKem;
  }

  // Get appropriate input field label based on mode
  String _getInputFieldLabel(bool isEncryptMode) {
    if (_isMLKemMode()) {
      return isEncryptMode ? "Key Exchange Data" : "Ciphertext to Decrypt";
    }
    return "Message";
  }

  // Get appropriate input field hint based on mode
  String _getInputFieldHint(bool isEncryptMode) {
    if (_isMLKemMode()) {
      return isEncryptMode
          ? "Generated shared secret will appear in output..."
          : "Enter ML-KEM ciphertext to extract shared key...";
    }
    return "Enter or paste text...";
  }

  // ML-KEM Key Exchange Function
  void _performMLKemKeyExchange() async {
    // Validate ML-KEM public key input
    if (_mlKemPublicKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the recipient\'s ML-KEM public key'),
        ),
      );
      return;
    }

    ref.read(isProcessingProvider.notifier).state = true;

    try {
      ref.read(processedEncryptProvider.notifier).state = await ih
          .handleKemProcess(
            ref.read(processedEncryptProvider),
            _mlKemPublicKeyController.text,
          );

      setState(() {
        _mlKemCiphertext = base64Encode(
          ref.read(processedEncryptProvider).ciphertext!,
        );
        _mlKemSharedSecret = base64Encode(
          ref.read(processedEncryptProvider).kemSharedSecret!,
        );
      });

      // Update the input field to show generation completed
      _encryptTextController.text = 'Key exchange completed - see output below';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ML-KEM key exchange completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ML-KEM key exchange failed: ${e.toString()}'),
          ),
        );
      }
    } finally {
      ref.read(isProcessingProvider.notifier).state = false;
    }
  }

  // ML-KEM Shared Secret Extraction Function
  void _extractMLKemSharedSecret() async {
    // Validate ciphertext input
    if (_decryptTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter ML-KEM ciphertext to extract shared key'),
        ),
      );
      return;
    }

    ref.read(isProcessingProvider.notifier).state = true;
    ref.read(processedDecryptProvider.notifier).state.inputCiphertext =
        _decryptTextController.text;
    try {
      ref.read(processedDecryptProvider.notifier).state = await ih
          .handleKemDeProcess(
            ref.read(processedDecryptProvider),
            ref.read(selectedKemDecryptKeyPairProvider)!,
          );

      setState(() {
        _mlKemSharedSecret = base64Encode(
          ref.read(processedDecryptProvider).kemSharedSecret!,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared secret extracted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract shared secret: ${e.toString()}'),
          ),
        );
      }
    } finally {
      ref.read(isProcessingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appMode = ref.watch(appModeProvider);
    final isEncryptMode = appMode == AppMode.encrypt;
    final Color primaryColor = ref.watch(primaryColorProvider);
    final bool defaultEncryption = ref.watch(defaultEncryptionProvider);
    final autoDetectTag = ref.watch(autoDetectTagProvider);
    final useTagManually = ref.watch(useTagProvider);
    final isProcessing = ref.watch(isProcessingProvider);
    final isMLKemMode = ref.read(isMLKemModeProvider);

    final selectedEncryption = ref.watch(selectedEncryptionProvider);
    final selectedObfuscation = ref.watch(selectedObfuscationProvider);
    final selectedCompression = ref.watch(selectedCompressionProvider);
    final selectedEncryptKey = ref.watch(selectedAESEncryptKeyProvider);
    final isCustomEncryptKey =
        selectedEncryptKey == null || selectedEncryptKey.isCustom;
    final selectedDecryptKey = ref.watch(selectedAESDecryptKeyProvider);
    final isCustomDecryptKey =
        selectedDecryptKey == null || selectedDecryptKey.isCustom;

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

    Future(() {
      ref.read(currentTextControllerProvider.notifier).state =
          _encryptTextController;
    });

    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppConstants.smallPadding),
          child: GestureDetector(
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
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              ///TODO:Add visual feedback during drag
            },
            child: ListView(
              children: [
                // Header with mode switch and settings
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.smallPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const KeyManagementPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.admin_panel_settings),
                          ),
                        ),
                      ),
                      Center(
                        child: modeSwitch(
                          appMode,
                          primaryColor,
                          ref,
                          _encryptTextController,
                          _decryptTextController,
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ML-KEM Info Container (only show in ML-KEM mode)
                if (ref.read(isMLKemModeProvider)) ...[
                  const SizedBox(height: AppConstants.defaultPadding),
                  buildMLKemInfoContainer(
                    context: context,
                    primaryColor: primaryColor,
                  ),
                ],

                const SizedBox(height: AppConstants.defaultPadding),

                // Message input section
                buildSectionHeader(
                  title: _getInputFieldLabel(isEncryptMode),
                  characterCount: isMLKemMode
                      ? (isEncryptMode
                            ? _mlKemCiphertext.length.toString()
                            : ref.watch(inputTextProvider).length.toString())
                      : ref.watch(inputTextProvider).length.toString(),
                  actions: [
                    if (!isMLKemMode || !isEncryptMode) ...[
                      buildActionButton(
                        icon: Icons.clear,
                        color: primaryColor,
                        onTap: () {
                          if (isEncryptMode) {
                            _encryptTextController.clear();
                            ref.read(inputTextProvider.notifier).state =
                                _encryptTextController.text;
                          } else {
                            _decryptTextController.clear();
                            ref.read(inputTextProvider.notifier).state =
                                _decryptTextController.text;
                          }
                        },
                        semanticLabel: 'Clear text',
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
                            }
                          }
                        },
                        semanticLabel: 'Paste from clipboard',
                      ),
                    ],
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
                    },
                    controller: isEncryptMode
                        ? _encryptTextController
                        : _decryptTextController,
                    maxLines: AppConstants.maxInputLines,
                    readOnly: isMLKemMode && isEncryptMode,
                    decoration: buildInputDecoration(
                      context: context,
                      primaryColor: primaryColor,
                      hintText: _getInputFieldHint(isEncryptMode),
                      labelText: _getInputFieldLabel(isEncryptMode),
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
                              ObfuscationMethod.en2;
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

                  if (!defaultEncryption || isMLKemMode) ...[
                    // ML-KEM specific configurations
                    if (isMLKemMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: EncryptionsDropdownButtonForm(
                          selectedEncryption: selectedEncryption,
                          primaryColor: primaryColor,
                        ),
                      ),

                      const SizedBox(height: AppConstants.defaultPadding),
                      buildPublicKeyField(
                        context: context,
                        controller: _mlKemPublicKeyController,
                        primaryColor: primaryColor,
                        onChanged: (val) {
                          // Handle ML-KEM public key input
                        },
                        validationPattern: r'^[A-Za-z0-9+/=\n\r\s-]+',
                        isEncryptMode: true,
                        labelText: 'Recipient\'s ML-KEM Public Key',
                      ),
                    ] else ...[
                      // Non-ML-KEM configurations
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

                      // Show compression dropdown (not for ML-KEM)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: CompressionsDropdownButtonForm(
                          selectedCompression: selectedCompression,
                          primaryColor: primaryColor,
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
                              // debugPrint(
                              //   'selected rsa pKey: ${ref.read(publicKeyProvider)}',
                              // );
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
                      ],
                    ],
                  ],

                  if (!(ref.watch(selectedEncryptionProvider) ==
                          EncryptionMethod.rsaSign) &&
                      !defaultEncryption &&
                      !(ref.watch(selectedEncryptionProvider) ==
                          EncryptionMethod.mlKem)) ...[
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
                        SignMethod.mlDsa) ...[
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: MlDsaSignKeySelector(primaryColor: primaryColor),
                      ),
                    ],
                  ],

                  // Show obfuscation dropdown (not for ML-KEM)
                  if (!isMLKemMode && !defaultEncryption) ...[
                    const SizedBox(height: AppConstants.defaultPadding),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      child: ObfsDropdownButtonForm(
                        selectedObfuscation: selectedObfuscation,
                        primaryColor: primaryColor,
                      ),
                    ),

                    if (selectedEncryption == EncryptionMethod.none &&
                        selectedObfuscation == ObfuscationMethod.none) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      _buildDefaultAesKeyWarning(
                        context: context,
                        message:
                            'Warning: No encryption or obfuscation is selected. Output will be Base64-encoded by default.',
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
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () {
                              if (isMLKemMode) {
                                _performMLKemKeyExchange();
                              } else {
                                _encrypt(
                                  defaultEncryption,
                                  selectedEncryption,
                                  selectedObfuscation,
                                  selectedCompression,
                                  useTagManually,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppConstants.defaultPadding,
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
                                Icon(isMLKemMode ? Icons.sync_alt : Icons.lock),
                                const SizedBox(
                                  width: AppConstants.smallPadding,
                                ),
                                Text(
                                  isMLKemMode
                                      ? "Generate Shared Key"
                                      : "Encrypt",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ] else ...[
                  // Decrypt mode configurations
                  if (!isMLKemMode) ...[
                    buildSwitchContainer(
                      context: context,
                      title: "Auto-detect Settings (from Tag)",
                      value: autoDetectTag,
                      onChanged: (val) =>
                          ref.read(autoDetectTagProvider.notifier).state = val,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                  ],

                  if (!autoDetectTag || isMLKemMode) ...[
                    const SizedBox(height: AppConstants.defaultPadding),

                    // ML-KEM decrypt mode doesn't need many options
                    if (isMLKemMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: EncryptionsDropdownButtonForm(
                          selectedEncryption: selectedEncryption,
                          primaryColor: primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: KemDecryptKeySelector(
                          primaryColor: primaryColor,
                        ),
                      ),
                      if (!(ref.watch(selectedEncryptionProvider) ==
                              EncryptionMethod.rsaSign) &&
                          !(ref.watch(selectedEncryptionProvider) ==
                              EncryptionMethod.mlKem)) ...[
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
                          SignMethod.mlDsa) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        buildPublicKeyField(
                          context: context,
                          controller: _dsaPublicKeyController,
                          primaryColor: primaryColor,
                          onChanged: (val) {},
                          validationPattern: r'^[A-Za-z0-9+/=\n\r\s-]+',
                          isEncryptMode: isEncryptMode,
                        ),
                      ],
                    ] else ...[
                      // Non-ML-KEM decrypt configurations
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: CompressionsDropdownButtonForm(
                          selectedCompression: selectedCompression,
                          primaryColor: primaryColor,
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
                                decryptPublicKeyGlobal = normalized;
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
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () {
                              if (isMLKemMode) {
                                _extractMLKemSharedSecret();
                              } else {
                                _decrypt(
                                  autoDetectTag,
                                  selectedEncryption,
                                  selectedObfuscation,
                                  selectedCompression,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppConstants.defaultPadding,
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
                                Icon(isMLKemMode ? Icons.key : Icons.lock_open),
                                const SizedBox(
                                  width: AppConstants.smallPadding,
                                ),
                                Text(
                                  isMLKemMode
                                      ? "Extract Shared Key"
                                      : "Decrypt",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],

                // Output section
                const SizedBox(height: AppConstants.defaultPadding),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding,
                  ),
                  child: const Divider(),
                ),

                const SizedBox(height: AppConstants.defaultPadding),

                // ML-KEM specific output or regular output
                if (isMLKemMode) ...[
                  buildMLKemOutputSection(
                    context: context,
                    primaryColor: primaryColor,
                    isEncryptMode: isEncryptMode,
                    mlKemCiphertext: _mlKemCiphertext,
                    mlKemSharedSecret: _mlKemSharedSecret,
                  ),
                ] else ...[
                  // Regular output section for non-ML-KEM
                  buildSectionHeader(
                    title: "Output",
                    characterCount: isEncryptMode
                        ? ref
                              .watch(processedEncryptProvider)
                              .text
                              .length
                              .toString()
                        : ref
                              .watch(processedDecryptProvider)
                              .text
                              .length
                              .toString(),
                    actions: [
                      buildActionButton(
                        icon: Icons.content_copy,
                        color: primaryColor,
                        onTap: () async {
                          final outputText = isEncryptMode
                              ? ref.watch(processedEncryptProvider).text
                              : ref.watch(processedDecryptProvider).text;
                          if (outputText.isNotEmpty) {
                            copyToClipboard(outputText, context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No output to copy'),
                              ),
                            );
                          }
                        },
                        semanticLabel: 'Copy output to clipboard',
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.smallPadding),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    child: Container(
                      height: screenHeight * AppConstants.outputHeightRatio,
                      padding: const EdgeInsets.all(
                        AppConstants.defaultPadding,
                      ),
                      constraints: const BoxConstraints(minHeight: 120),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: getTextFieldBackgroundColor(context),
                        border: Border.all(color: getBorderColor(context)),
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                      child: SelectableText(
                        isEncryptMode
                            ? ref.watch(processedEncryptProvider).text
                            : ref.watch(processedDecryptProvider).text,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppConstants.defaultPadding),
              ],
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

    // Input validation
    if (_encryptTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to encrypt')),
      );
      return;
    }

    final effectiveEncryption = defaultEncryption
        ? EncryptionMethod.aesGcm
        : selectedEncryption;

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

        if (selectedEncryption == EncryptionMethod.rsa || isRsaSign) {
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

          ref.read(inputQryptProvider.notifier).state = Qrypt.withRSA(
            text: _encryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: selectedObfuscation,
            compression: selectedCompression,
            sign: ref.read(selectedSignProvider),
            useTag: useTagManually,
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
          final q = Qrypt.withTag(
            text: _encryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: selectedObfuscation,
            compression: selectedCompression,
            sign: ref.read(selectedSignProvider),
            useTag: useTagManually,
          );
          if (isAes) {
            q.customKey = aesKeyToUse;
            q.useCustomKey = true;
          }
          ref.read(inputQryptProvider.notifier).state = q;
        }

        if (ref.read(selectedSignProvider) == SignMethod.mlDsa) {
          ref.read(inputQryptProvider.notifier).state.dsaKeyPair = ref.read(
            selectedMlDsaSignKeyPairProvider,
          );
        }

        ref.read(processedEncryptProvider.notifier).state = await ih
            .handleProcess(ref.read(inputQryptProvider));
      } else {
        // Default encryption logic (AES-GCM + GZip + EN2 + Tag)
        final q = Qrypt.withTag(
          text: _encryptTextController.text,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.en2,
          compression: CompressionMethod.gZip,
          sign: ref.read(selectedSignProvider),
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
    if (_decryptTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to decrypt')),
      );
      return;
    }

    ref.read(isProcessingProvider.notifier).state = true;

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
      final String decryptKeyToUse =
          (selectedDecryptKey != null && selectedDecryptKey.key.isNotEmpty)
          ? selectedDecryptKey.key
          : typedDecryptKey;

      if (!autoDetectTag) {
        final manualQrypt = Qrypt.withTag(
          text: _decryptTextController.text,
          encryption: selectedEncryption,
          obfuscation: selectedObfuscation,
          compression: selectedCompression,
          sign: ref.read(selectedSignProvider),
          useTag: false,
        );

        final isAes =
            selectedEncryption == EncryptionMethod.aesGcm ||
            selectedEncryption == EncryptionMethod.aesCbc ||
            selectedEncryption == EncryptionMethod.aesCtr;

        if (isAes && decryptKeyToUse.isNotEmpty) {
          manualQrypt.customKey = decryptKeyToUse;
          manualQrypt.useCustomKey = true;
        }

        if (selectedEncryption == EncryptionMethod.rsa ||
            selectedEncryption == EncryptionMethod.rsaSign) {
          ref.read(inputQryptProvider.notifier).state.rsaKeyPair = ref.read(
            selectedRSADecryptKeyPairProvider,
          )!;
        }

        if (ref.read(selectedSignProvider) == SignMethod.mlDsa) {
          manualQrypt.dsaVerifyPublicKEy = base64Decode(
            ref.read(verifyMlDsaPublicKeyProvider),
          );
        }

        ref.read(inputQryptProvider.notifier).state = manualQrypt;
        if (!mounted) return;
        ref.read(processedDecryptProvider.notifier).state = await ih
            .handleDeProcess(context, ref.read(inputQryptProvider), false);
      } else {
        final autoQrypt = Qrypt.autoDecrypt(text: _decryptTextController.text);
        if (decryptKeyToUse.isNotEmpty) {
          autoQrypt.customKey = decryptKeyToUse;
          autoQrypt.useCustomKey = true;
        }

        ref.read(inputQryptProvider.notifier).state = autoQrypt;
        if (!mounted) return;
        ref.read(processedDecryptProvider.notifier).state = await ih
            .handleDeProcess(context, ref.read(inputQryptProvider), true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decryption failed: ${e.toString()}')),
        );
      }
    } finally {
      ref.read(isProcessingProvider.notifier).state = false;
    }
  }
}
