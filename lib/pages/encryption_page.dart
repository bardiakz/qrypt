import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/pages/settings_page.dart';
import 'package:qrypt/pages/widgets/Dropdown_button_forms.dart';
import 'package:qrypt/pages/widgets/mode_switch.dart';
import 'package:qrypt/pages/widgets/rsa_key_selector.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:flutter/services.dart';
import 'package:qrypt/providers/rsa_providers.dart';
import '../models/encryption_method.dart';
import '../models/rsa_key_pair.dart';
import '../providers/resource_providers.dart';
import '../services/input_handler.dart';

// Constants
class AppConstants {
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double verySmallPadding = 4.0;
  static const double largePadding = 24.0;
  static const double xlargePadding = 32.0;
  static const double borderRadius = 12.0;
  static const double iconSize = 20.0;
  static const int maxInputLines = 4;
  static const double outputHeightRatio = 0.25;
  static const double borderWidth = 2.0;
  static const double switchBorderRadius = 20.0;
}

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
  final InputHandler ih = InputHandler();

  @override
  void dispose() {
    _encryptTextController.dispose();
    _decryptTextController.dispose();
    _encryptPublicKeyController.dispose();
    _decryptPublicKeyController.dispose();
    _customAesKeyController.dispose();
    super.dispose();
  }

  Color _getTextFieldBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[50]!;
  }

  Color _getContainerBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? Colors.grey[850]! : Colors.grey[50]!;
  }

  Color _getBorderColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[300]!;
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required Color primaryColor,
    String? hintText,
    String? labelText,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: BorderSide(
          color: primaryColor,
          width: AppConstants.borderWidth,
        ),
      ),
      filled: true,
      fillColor: _getTextFieldBackgroundColor(context),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.switchBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.smallPadding),
          child: Icon(
            icon,
            color: color,
            size: AppConstants.iconSize,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String characterCount,
    required List<Widget> actions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.defaultPadding + 2,
        top: 18,
        right: AppConstants.defaultPadding,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            characterCount,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(width: 12),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildSwitchContainer({
    required BuildContext context,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: BoxDecoration(
          color: _getContainerBackgroundColor(context),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: _getBorderColor(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            Switch(
              thumbColor: WidgetStateProperty.all(Colors.white),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return Colors.grey.shade300;
              }),
              value: value,
              onChanged: onChanged,
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
            decoration: _buildInputDecoration(
              context: context,
              primaryColor: primaryColor,
              labelText: 'Public Key',
              errorText: controller.text.isEmpty
                  ? null
                  : (RegExp(validationPattern).hasMatch(controller.text)
                        ? null
                        : 'Invalid PEM format'),
            ),
            maxLines: 3,
          ),
          Positioned(
            top: 25,
            right: 5,
            child: InkWell(
              onTap: () async {
                final pastedText = await _pasteFromClipboard();
                if (pastedText != null) {
                  controller.text = pastedText;
                  if (isEncryptMode) {
                    ref.read(receiverPublicKeyProvider.notifier).state =
                        pastedText;
                  } else {
                    ref.read(decryptPublicKeyProvider.notifier).state =
                        pastedText;
                    decryptPublicKeyGlobal = pastedText;
                  }
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Stack(
        children: [
          TextField(
            controller: _customAesKeyController,
            onChanged: (value) {
              ref.read(customAesKeyProvider.notifier).state = value;
            },
            decoration: _buildInputDecoration(
              context: context,
              primaryColor: primaryColor,
              labelText: 'Custom AES Key',
              hintText: 'Enter your custom AES key (16, 24, or 32 bytes)',
              errorText: _customAesKeyController.text.isEmpty
                  ? null
                  : _validateAesKey(_customAesKeyController.text),
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
                    final pastedText = await _pasteFromClipboard();
                    if (pastedText != null) {
                      _customAesKeyController.text = pastedText;
                      ref.read(customAesKeyProvider.notifier).state =
                          pastedText;
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
                    final randomKey = _generateRandomAesKey();
                    _customAesKeyController.text = randomKey;
                    ref.read(customAesKeyProvider.notifier).state = randomKey;
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

  String? _validateAesKey(String key) {
    if (key.isEmpty) return null;

    final keyLength = key.length;
    if (keyLength != 16 && keyLength != 24 && keyLength != 32) {
      return 'AES key must be 16, 24, or 32 characters long';
    }
    return null;
  }

  String _generateRandomAesKey() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()';
    final random = DateTime.now().millisecondsSinceEpoch;
    var result = '';
    for (var i = 0; i < 32; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }

  void _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      return clipboardData?.text;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to paste: ${e.toString()}')),
        );
      }
      return null;
    }
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
    final useCustomAesKey = ref.watch(useCustomAesKeyProvider);

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

                // Message input section
                _buildSectionHeader(
                  title: "Message",
                  characterCount: ref
                      .watch(inputTextProvider)
                      .length
                      .toString(),
                  actions: [
                    _buildActionButton(
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
                    _buildActionButton(
                      icon: Icons.content_paste,
                      color: primaryColor,
                      onTap: () async {
                        final pastedText = await _pasteFromClipboard();
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
                    decoration: _buildInputDecoration(
                      context: context,
                      primaryColor: primaryColor,
                      hintText: "Enter or paste text...",
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.largePadding),

                // Mode-specific configuration sections
                if (isEncryptMode) ...[
                  // Encrypt mode configurations
                  _buildSwitchContainer(
                    context: context,
                    title: "Use Default Encryption",
                    value: defaultEncryption,
                    onChanged: (val) =>
                        ref.read(defaultEncryptionProvider.notifier).state =
                            val,
                    primaryColor: primaryColor,
                  ),

                  if (!defaultEncryption) ...[
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
                              : _getContainerBackgroundColor(context),
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                          border: Border.all(
                            color: useTagManually
                                ? primaryColor.withOpacity(0.3)
                                : _getBorderColor(context),
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
                                  ref.read(useTagProvider.notifier).state = val,
                              activeColor: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.defaultPadding),
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

                    // Custom AES Key Section - Show only for AES encryption methods
                    if (selectedEncryption == EncryptionMethod.aesGcm ||
                        selectedEncryption == EncryptionMethod.aesCbc ||
                        selectedEncryption == EncryptionMethod.aesCtr) ...[
                      _buildSwitchContainer(
                        context: context,
                        title: "Use Custom AES Key",
                        value: useCustomAesKey,
                        onChanged: (val) {
                          ref.read(useCustomAesKeyProvider.notifier).state =
                              val;
                          if (!val) {
                            _customAesKeyController.clear();
                            ref.read(customAesKeyProvider.notifier).state = '';
                          }
                        },
                        primaryColor: primaryColor,
                      ),

                      if (useCustomAesKey) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildCustomAesKeyField(
                          context: context,
                          primaryColor: primaryColor,
                        ),
                      ],

                      const SizedBox(height: AppConstants.defaultPadding),
                    ],

                    if (selectedEncryption == EncryptionMethod.rsa ||
                        selectedEncryption == EncryptionMethod.rsaSign) ...[
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
                            r'^-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/=\n]+\n-----END PUBLIC KEY-----$',
                        isEncryptMode: true,
                      ),
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
                              _encrypt(
                                defaultEncryption,
                                selectedEncryption,
                                selectedObfuscation,
                                selectedCompression,
                                useTagManually,
                              );
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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock),
                                SizedBox(width: 5),
                                Text(
                                  "Encrypt",
                                  style: TextStyle(
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
                  _buildSwitchContainer(
                    context: context,
                    title: "Auto-detect Settings (from Tag)",
                    value: autoDetectTag,
                    onChanged: (val) =>
                        ref.read(autoDetectTagProvider.notifier).state = val,
                    primaryColor: primaryColor,
                  ),

                  if (!autoDetectTag) ...[
                    const SizedBox(height: AppConstants.defaultPadding),
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

                    // Custom AES Key Section for Decrypt - Show only for AES encryption methods
                    if (selectedEncryption == EncryptionMethod.aesGcm ||
                        selectedEncryption == EncryptionMethod.aesCbc ||
                        selectedEncryption == EncryptionMethod.aesCtr) ...[
                      _buildSwitchContainer(
                        context: context,
                        title: "Use Custom AES Key",
                        value: useCustomAesKey,
                        onChanged: (val) {
                          ref.read(useCustomAesKeyProvider.notifier).state =
                              val;
                          if (!val) {
                            _customAesKeyController.clear();
                            ref.read(customAesKeyProvider.notifier).state = '';
                          }
                        },
                        primaryColor: primaryColor,
                      ),

                      if (useCustomAesKey) ...[
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildCustomAesKeyField(
                          context: context,
                          primaryColor: primaryColor,
                        ),
                      ],

                      const SizedBox(height: AppConstants.defaultPadding),
                    ],

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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_open),
                                SizedBox(width: 5),
                                Text(
                                  "Decrypt",
                                  style: TextStyle(
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

                _buildSectionHeader(
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
                    _buildActionButton(
                      icon: Icons.content_copy,
                      color: primaryColor,
                      onTap: () async {
                        final outputText = isEncryptMode
                            ? ref.watch(processedEncryptProvider).text
                            : ref.watch(processedDecryptProvider).text;
                        if (outputText.isNotEmpty) {
                          _copyToClipboard(outputText);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No output to copy')),
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
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    constraints: const BoxConstraints(minHeight: 120),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _getTextFieldBackgroundColor(context),
                      border: Border.all(color: _getBorderColor(context)),
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
    final useCustomAesKey = ref.read(useCustomAesKeyProvider);
    final customAesKey = ref.read(customAesKeyProvider);

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

      final validationError = _validateAesKey(customAesKey);
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
    final useCustomAesKey = ref.read(useCustomAesKeyProvider);
    final customAesKey = ref.read(customAesKeyProvider);

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

      final validationError = _validateAesKey(customAesKey);
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
