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
import 'package:qrypt/pages/widgets/ml_kem/kem_key_selector.dart';
import 'package:qrypt/pages/widgets/mode_switch.dart';
import 'package:qrypt/pages/widgets/rsa/rsa_key_selector.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:flutter/services.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/rsa_providers.dart';
import '../models/encryption_method.dart';
import '../models/kyber_models.dart';
import '../models/rsa_key_pair.dart';
import '../providers/resource_providers.dart';
import '../resources/constants.dart';
import '../resources/global_resources.dart';
import '../services/input_handler.dart';

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
  final InputHandler ih = InputHandler();

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
            const SizedBox(height: 8),
            DropdownButtonFormField<MLKemKeySize>(
              value: _selectedMLKemKeySize,
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

  Widget _buildPublicKeyField({
    required BuildContext context,
    required TextEditingController controller,
    required Color primaryColor,
    required ValueChanged<String> onChanged,
    required String validationPattern,
    required bool isEncryptMode,
    String? labelText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: buildInputDecoration(
              context: context,
              primaryColor: primaryColor,
              labelText: labelText ?? 'Public Key',
              errorText: controller.text.isEmpty
                  ? null
                  : (RegExp(validationPattern).hasMatch(controller.text)
                        ? null
                        : 'Invalid key format'),
            ),
            maxLines: 3,
          ),
          Positioned(
            top: 25,
            right: 5,
            child: InkWell(
              onTap: () async {
                final pastedText = await pasteFromClipboard(context);
                if (pastedText != null) {
                  controller.text = pastedText;
                  onChanged(pastedText);
                }
              },
              borderRadius: BorderRadius.circular(
                AppConstants.switchBorderRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                child: Icon(
                  Icons.content_paste_go,
                  color: Colors.blueGrey,
                  size: AppConstants.iconSize + 5,
                  semanticLabel: 'Paste from clipboard',
                ),
              ),
            ),
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            onChanged: (value) {
              ref.read(keyProvider.notifier).state = value;
            },
            decoration: buildInputDecoration(
              context: context,
              primaryColor: primaryColor,
              labelText: 'Custom AES Key',
              hintText: 'Enter your custom AES key (16, 24, or 32 bytes)',
              errorText: controller.text.isEmpty
                  ? null
                  : validateAesKey(controller.text),
            ),
            maxLines: 1,
          ),
          Positioned(
            top: 5,
            right: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final pastedText = await pasteFromClipboard(context);
                    if (pastedText != null) {
                      controller.text = pastedText;
                      ref.read(keyProvider.notifier).state = pastedText;
                    }
                  },
                  borderRadius: BorderRadius.circular(
                    AppConstants.switchBorderRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.smallPadding),
                    child: Icon(
                      Icons.content_paste_go,
                      color: Colors.blueGrey,
                      size: AppConstants.iconSize + 2,
                      semanticLabel: 'Paste from clipboard',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    // Generate a random 32-byte AES key
                    final randomKey = generateRandomAesKey();
                    controller.text = randomKey;
                    ref.read(keyProvider.notifier).state = randomKey;
                  },
                  borderRadius: BorderRadius.circular(
                    AppConstants.switchBorderRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.smallPadding),
                    child: Icon(
                      Icons.casino,
                      color: Colors.blueGrey,
                      size: AppConstants.iconSize + 2,
                      semanticLabel: 'Generate random key',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
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
          ref.read(processedEncryptProvider).sharedSecret!,
        );
        ;
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
          ref.read(processedDecryptProvider).sharedSecret!,
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

    final useCustomAesKey = isEncryptMode
        ? ref.watch(useCustomEncryptAesKeyProvider)
        : ref.watch(useCustomDecryptAesKeyProvider);

    final selectedEncryption = ref.watch(selectedEncryptionProvider);
    final selectedObfuscation = ref.watch(selectedObfuscationProvider);
    final selectedCompression = ref.watch(selectedCompressionProvider);

    Future(() {
      ref.read(currentTextControllerProvider.notifier).state =
          _encryptTextController;
    });

    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(
            left: 2,
            right: 2,
            top: 4,
            bottom: AppConstants.smallPadding,
          ),
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
                Row(
                  children: [
                    Expanded(child: Container()),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppConstants.defaultPadding,
                        ),
                        child: modeSwitch(
                          appMode,
                          primaryColor,
                          ref,
                          _encryptTextController,
                          _decryptTextController,
                        ),
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

                // ML-KEM Info Container (only show in ML-KEM mode)
                if (ref.read(isMLKemModeProvider)) ...[
                  const SizedBox(height: AppConstants.defaultPadding),
                  buildMLKemInfoContainer(
                    context: context,
                    primaryColor: primaryColor,
                  ),
                ],

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
                    // Read-only for ML-KEM encrypt mode
                    decoration: buildInputDecoration(
                      context: context,
                      primaryColor: primaryColor,
                      hintText: _getInputFieldHint(isEncryptMode),
                      labelText: _getInputFieldLabel(isEncryptMode),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.largePadding),

                // Mode-specific configuration sections
                if (isEncryptMode) ...[
                  // Encrypt mode configurations
                  if (!isMLKemMode) ...[
                    buildSwitchContainer(
                      context: context,
                      title: "Use Default Encryption",
                      value: defaultEncryption,
                      onChanged: (val) =>
                          ref.read(defaultEncryptionProvider.notifier).state =
                              val,
                      primaryColor: primaryColor,
                    ),
                  ],

                  if (!defaultEncryption || isMLKemMode) ...[
                    // const SizedBox(height: AppConstants.smallPadding),

                    // ML-KEM specific configurations
                    if (isMLKemMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                          vertical: AppConstants.smallPadding,
                        ),
                        child: EncryptionsDropdownButtonForm(
                          selectedEncryption: selectedEncryption,
                          primaryColor: primaryColor,
                        ),
                      ),

                      // buildMLKemKeySizeSelector(
                      //   context: context,
                      //   primaryColor: primaryColor,
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: AppConstants.defaultPadding,
                      //     vertical: AppConstants.defaultPadding,
                      //   ),
                      //   child: KemEncryptKeySelector(
                      //     primaryColor: primaryColor,
                      //   ),
                      // ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildPublicKeyField(
                        context: context,
                        controller: _mlKemPublicKeyController,
                        primaryColor: primaryColor,
                        onChanged: (val) {
                          // Handle ML-KEM public key input
                        },
                        validationPattern: r'^[A-Za-z0-9+/=\n\r\s-]+',
                        // Basic validation for ML-KEM keys
                        isEncryptMode: true,
                        labelText: 'Recipient\'s ML-KEM Public Key',
                      ),
                    ] else ...[
                      // Non-ML-KEM configurations
                      if (!isMLKemMode) ...[
                        const SizedBox(height: AppConstants.smallPadding),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: useTagManually
                                  ? primaryColor.withOpacity(0.1)
                                  : getContainerBackgroundColor(context),
                              borderRadius: BorderRadius.circular(
                                AppConstants.borderRadius,
                              ),
                              border: Border.all(
                                color: useTagManually
                                    ? primaryColor.withOpacity(0.3)
                                    : getBorderColor(context),
                              ),
                            ),

                            child: Row(
                              children: [
                                const SizedBox(width: 12),
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
                                  activeColor: primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppConstants.defaultPadding),

                      // Show compression dropdown (not for ML-KEM)
                      if (!isMLKemMode) ...[
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
                      ],

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

                      if (!(ref.watch(selectedEncryptionProvider) ==
                          EncryptionMethod.rsaSign)) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding,
                          ),
                          child: SignsDropdownButtonForm(
                            selectedSign: ref.read(selectedSignProvider),
                            primaryColor: primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                      ],

                      // Show obfuscation dropdown (not for ML-KEM)
                      if (!isMLKemMode) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding,
                          ),
                          child: ObfsDropdownButtonForm(
                            selectedObfuscation: selectedObfuscation,
                            primaryColor: primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                      ],

                      // Custom AES Key Section - Show only for AES encryption methods
                      if (!isMLKemMode &&
                          (selectedEncryption == EncryptionMethod.aesGcm ||
                              selectedEncryption == EncryptionMethod.aesCbc ||
                              selectedEncryption ==
                                  EncryptionMethod.aesCtr)) ...[
                        buildSwitchContainer(
                          context: context,
                          title: "Use Custom AES Key",
                          value: useCustomAesKey,
                          onChanged: (val) {
                            ref
                                    .read(
                                      useCustomEncryptAesKeyProvider.notifier,
                                    )
                                    .state =
                                val;
                            if (!val) {
                              _customAesKeyController.clear();
                              ref
                                      .read(
                                        customEncryptAesKeyProvider.notifier,
                                      )
                                      .state =
                                  '';
                            }
                          },
                          primaryColor: primaryColor,
                        ),

                        if (useCustomAesKey) ...[
                          const SizedBox(height: AppConstants.defaultPadding),
                          _buildCustomAesKeyField(
                            context: context,
                            primaryColor: primaryColor,
                            isEncryptMode: true,
                          ),
                        ],

                        const SizedBox(height: AppConstants.defaultPadding),
                      ],

                      // RSA specific fields
                      if (!isMLKemMode &&
                          (selectedEncryption == EncryptionMethod.rsa ||
                              selectedEncryption ==
                                  EncryptionMethod.rsaSign)) ...[
                        if (selectedEncryption == EncryptionMethod.rsaSign)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.defaultPadding,
                            ),
                            child: RSAEncryptKeySelector(
                              primaryColor: primaryColor,
                            ),
                          ),

                        const SizedBox(height: AppConstants.largePadding / 2),
                        _buildPublicKeyField(
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
                      ],
                    ],
                  ],

                  const SizedBox(height: AppConstants.largePadding),

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
                                const SizedBox(width: 5),
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
                  ],

                  if (!autoDetectTag || isMLKemMode) ...[
                    const SizedBox(height: AppConstants.defaultPadding),

                    // ML-KEM decrypt mode doesn't need many options
                    if (isMLKemMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                          vertical: AppConstants.smallPadding,
                        ),
                        child: EncryptionsDropdownButtonForm(
                          selectedEncryption: selectedEncryption,
                          primaryColor: primaryColor,
                        ),
                      ),
                      // buildMLKemKeySizeSelector(
                      //   context: context,
                      //   primaryColor: primaryColor,
                      // ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                          vertical: AppConstants.defaultPadding,
                        ),
                        child: KemDecryptKeySelector(
                          primaryColor: primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      // Note: In decrypt mode, we might need private key selector for ML-KEM
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

                      const SizedBox(height: AppConstants.defaultPadding),

                      // Custom AES Key Section for Decrypt
                      if (selectedEncryption == EncryptionMethod.aesGcm ||
                          selectedEncryption == EncryptionMethod.aesCbc ||
                          selectedEncryption == EncryptionMethod.aesCtr) ...[
                        buildSwitchContainer(
                          context: context,
                          title: "Use Custom AES Key",
                          value: useCustomAesKey,
                          onChanged: (val) {
                            ref
                                    .read(
                                      useCustomDecryptAesKeyProvider.notifier,
                                    )
                                    .state =
                                val;
                            if (!val) {
                              _customDecryptAesKeyController.clear();
                              ref
                                      .read(
                                        customDecryptAesKeyProvider.notifier,
                                      )
                                      .state =
                                  '';
                            }
                          },
                          primaryColor: primaryColor,
                        ),

                        if (useCustomAesKey) ...[
                          const SizedBox(height: AppConstants.defaultPadding),
                          _buildCustomAesKeyField(
                            context: context,
                            primaryColor: primaryColor,
                            isEncryptMode: false,
                          ),
                        ],

                        const SizedBox(height: AppConstants.defaultPadding),
                      ],

                      // RSA decrypt configurations
                      if (selectedEncryption == EncryptionMethod.rsa ||
                          selectedEncryption == EncryptionMethod.rsaSign) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding,
                          ),
                          child: RSADecryptKeySelector(
                            primaryColor: primaryColor,
                          ),
                        ),

                        const SizedBox(height: AppConstants.defaultPadding),
                        if (selectedEncryption == EncryptionMethod.rsaSign)
                          _buildPublicKeyField(
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
                                        .read(decryptPublicKeyProvider.notifier)
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
                  ],

                  const SizedBox(height: AppConstants.largePadding),
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
                                const SizedBox(width: 5),
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
                const SizedBox(height: AppConstants.xlargePadding),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding,
                  ),
                  child: const Divider(),
                ),

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
    // Input validation
    if (_encryptTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to encrypt')),
      );
      return;
    }

    // Validate custom AES key if being used
    final useCustomAesKey = ref.read(useCustomEncryptAesKeyProvider);
    final customAesKey = ref.read(customEncryptAesKeyProvider);

    if (useCustomAesKey &&
        (selectedEncryption == EncryptionMethod.aesGcm ||
            selectedEncryption == EncryptionMethod.aesCbc ||
            selectedEncryption == EncryptionMethod.aesCtr)) {
      if (customAesKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a custom AES key')),
        );
        return;
      }

      final validationError = validateAesKey(customAesKey);
      if (validationError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
        return;
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

          String rsaReceiversPublicKey = ref
              .read(receiverPublicKeyProvider)
              .trim();

          if (rsaReceiversPublicKey.isEmpty) {
            throw Exception('Please enter the receiver\'s public key');
          }

          if (!rsaReceiversPublicKey.contains('BEGIN PUBLIC KEY')) {
            throw Exception(
              'Invalid public key format. Please ensure it\'s in PEM format.',
            );
          }

          // Create Qrypt object with RSA parameters
          ref.read(inputQryptProvider.notifier).state = Qrypt.withRSA(
            text: _encryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: selectedObfuscation,
            compression: selectedCompression,
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
          // Non-RSA encryption - create Qrypt object with custom AES key if provided
          if (useCustomAesKey && customAesKey.isNotEmpty) {
            // Create Qrypt object with custom AES key
            ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(
              text: _encryptTextController.text,
              encryption: selectedEncryption,
              obfuscation: selectedObfuscation,
              compression: selectedCompression,
              useTag: useTagManually,
            );
            ref.read(inputQryptProvider.notifier).state.customKey =
                customAesKey;
            ref.read(inputQryptProvider.notifier).state.useCustomKey =
                useCustomAesKey;
          } else {
            // Standard non-RSA encryption
            ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(
              text: _encryptTextController.text,
              encryption: selectedEncryption,
              obfuscation: selectedObfuscation,
              compression: selectedCompression,
              useTag: useTagManually,
            );
          }
        }

        ref.read(processedEncryptProvider.notifier).state = await ih
            .handleProcess(ref.read(inputQryptProvider));
      } else {
        // Default encryption logic
        if (selectedEncryption == EncryptionMethod.rsa) {
          final selectedKeyPair = ref.read(selectedRSAEncryptKeyPairProvider);
          final rsaReceiversPublicKey = ref.read(publicKeyProvider).trim();

          if (selectedKeyPair == null) {
            throw Exception('Please select an RSA key pair');
          }

          if (rsaReceiversPublicKey.isEmpty) {
            throw Exception('Please enter the receiver\'s public key');
          }

          ref.read(inputQryptProvider.notifier).state = Qrypt.withRSA(
            text: _encryptTextController.text,
            encryption: selectedEncryption,
            // Use selected encryption instead of default
            obfuscation: ObfuscationMethod.en2,
            compression: CompressionMethod.brotli,
            useTag: true,
            rsaKeyPair: selectedKeyPair,
            rsaReceiverPublicKey: rsaReceiversPublicKey,
          );
        } else {
          ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(
            text: _encryptTextController.text,
            encryption: EncryptionMethod.aesGcm,
            obfuscation: ObfuscationMethod.en2,
            compression: CompressionMethod.brotli,
            useTag: true,
          );
        }

        if (kDebugMode) {
          print('created input qrypt');
          print(
            'RSA Key Pair: ${ref.read(inputQryptProvider).rsaKeyPair.name}',
          );
          print(
            'RSA Public Key length: ${ref.read(inputQryptProvider).rsaReceiverPublicKey.length}',
          );
        }

        ref.read(processedEncryptProvider.notifier).state = await ih
            .handleProcess(ref.read(inputQryptProvider));
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
    // Input validation
    if (_decryptTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to decrypt')),
      );
      return;
    }

    // Validate custom AES key if being used
    final useCustomAesKey = ref.read(useCustomDecryptAesKeyProvider);
    final customAesKey = ref.read(customDecryptAesKeyProvider);

    if (!autoDetectTag &&
        useCustomAesKey &&
        (selectedEncryption == EncryptionMethod.aesGcm ||
            selectedEncryption == EncryptionMethod.aesCbc ||
            selectedEncryption == EncryptionMethod.aesCtr)) {
      if (customAesKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a custom AES key')),
        );
        return;
      }

      final validationError = validateAesKey(customAesKey);
      if (validationError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
        return;
      }
    }

    ref.read(isProcessingProvider.notifier).state = true;

    try {
      if (!autoDetectTag) {
        if (useCustomAesKey &&
            customAesKey.isNotEmpty &&
            (selectedEncryption == EncryptionMethod.aesGcm ||
                selectedEncryption == EncryptionMethod.aesCbc ||
                selectedEncryption == EncryptionMethod.aesCtr)) {
          ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(
            text: _decryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: selectedObfuscation,
            compression: selectedCompression,
            useTag: false,
          );
          ref.read(inputQryptProvider.notifier).state.customKey = customAesKey;
          ref.read(inputQryptProvider.notifier).state.useCustomKey =
              useCustomAesKey;
          ref.read(inputQryptProvider.notifier).state.useTag = false;
        } else {
          ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(
            text: _decryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: selectedObfuscation,
            compression: selectedCompression,
            useTag: false,
          );
        }

        if (selectedEncryption == EncryptionMethod.rsa ||
            selectedEncryption == EncryptionMethod.rsaSign) {
          ref.read(inputQryptProvider.notifier).state.rsaKeyPair = ref.read(
            selectedRSADecryptKeyPairProvider,
          )!;
        }
        ref.read(processedDecryptProvider.notifier).state = await ih
            .handleDeProcess(context, ref.read(inputQryptProvider), false);
      } else {
        ref.read(inputQryptProvider.notifier).state = Qrypt.autoDecrypt(
          text: _decryptTextController.text,
        );
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
