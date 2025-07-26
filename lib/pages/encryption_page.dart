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
  final InputHandler ih = InputHandler();

  @override
  void dispose() {
    _encryptTextController.dispose();
    _decryptTextController.dispose();
    super.dispose();
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

  // void _onTextChanged() {
  //   final appMode = ref.read(appModeProvider);
  //   final defaultEncryption = ref.read(defaultEncryptionProvider);
  //   final selectedEncryption = ref.read(selectedEncryptionProvider);
  //   final selectedObfuscation = ref.read(selectedObfuscationProvider);
  //   final selectedCompression = ref.read(selectedCompressionProvider);
  //   final autoDetectTag = ref.read(autoDetectTagProvider);
  //   final useTagManually = ref.read(useTagProvider);
  //
  //   if (appMode == AppMode.encrypt) {
  //     _encrypt(
  //       defaultEncryption,
  //       selectedEncryption,
  //       selectedObfuscation,
  //       selectedCompression,
  //       useTagManually,
  //     );
  //   } else {
  //     _decrypt(
  //       autoDetectTag,
  //       selectedEncryption,
  //       selectedObfuscation,
  //       selectedCompression,
  //     );
  //   }
  // }

  @override
  void initState() {
    super.initState();
  }

  void _onSwipeLeft() {
    final currentMode = ref.read(appModeProvider);
    if (currentMode == AppMode.encrypt) {
      // Swipe left to go to decrypt mode
      ref.read(appModeProvider.notifier).state = AppMode.decrypt;
      ref.read(inputTextProvider.notifier).state = _decryptTextController.text;

      HapticFeedback.lightImpact();

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: const Text('Switched to Decrypt mode'),
      //     duration: const Duration(milliseconds: 800),
      //     backgroundColor: Colors.green,
      //   ),
      // );
    }
  }

  void _onSwipeRight() {
    final currentMode = ref.read(appModeProvider);
    if (currentMode == AppMode.decrypt) {
      // Swipe right to go to encrypt mode
      ref.read(appModeProvider.notifier).state = AppMode.encrypt;
      ref.read(inputTextProvider.notifier).state = _encryptTextController.text;

      HapticFeedback.lightImpact();

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: const Text('Switched to Encrypt mode'),
      //     duration: const Duration(milliseconds: 800),
      //     backgroundColor: ref.read(primaryColorProvider),
      //   ),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final appMode = ref.watch(appModeProvider);
    final isEncryptMode = appMode == AppMode.encrypt;
    final Color primaryColor = ref.watch(primaryColorProvider);
    final bool defaultEncryption = ref.watch(defaultEncryptionProvider);
    final autoDetectTag = ref.watch(autoDetectTagProvider);
    final useTagManually = ref.watch(useTagProvider);
    final isProcessing = ref.watch(isProcessingProvider);

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
                  // Swiped Right (decrypt -> encrypt)
                  _onSwipeRight();
                } else if (details.primaryVelocity! < -sensitivity) {
                  // Swiped Left (encrypt -> decrypt)
                  _onSwipeLeft();
                }
              }
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              ///TODO:Add visual feedback during drag
            },
            child: ListView(
              children: [
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
                          icon: Icon(Icons.settings),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    left: AppConstants.defaultPadding + 2,
                    top: 18,
                    right: AppConstants.defaultPadding,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Message",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        ref.watch(inputTextProvider).length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
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
                          borderRadius: BorderRadius.circular(
                            AppConstants.switchBorderRadius,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              AppConstants.smallPadding,
                            ),
                            child: Icon(
                              Icons.clear,
                              color: primaryColor,
                              size: AppConstants.iconSize,
                              semanticLabel: 'Clear text',
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
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
                          borderRadius: BorderRadius.circular(
                            AppConstants.switchBorderRadius,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              AppConstants.smallPadding,
                            ),
                            child: Icon(
                              Icons.content_paste,
                              color: primaryColor,
                              size: AppConstants.iconSize,
                              semanticLabel: 'Paste from clipboard',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                    decoration: InputDecoration(
                      hintText: "Enter or paste text...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                        borderSide: BorderSide(
                          color: primaryColor,
                          width: AppConstants.borderWidth,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.largePadding),

                if (isEncryptMode) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(
                        AppConstants.defaultPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Use Default Encryption",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Switch(
                            thumbColor: WidgetStateProperty.all(Colors.white),
                            trackColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return primaryColor;
                              }
                              return Colors.grey.shade300;
                            }),
                            value: defaultEncryption,
                            onChanged: (val) =>
                                ref
                                        .read(
                                          defaultEncryptionProvider.notifier,
                                        )
                                        .state =
                                    val,
                          ),
                        ],
                      ),
                    ),
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
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                          border: Border.all(
                            color: useTagManually
                                ? primaryColor.withOpacity(0.3)
                                : Colors.grey[300]!,
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
                    if (selectedEncryption == EncryptionMethod.rsa ||
                        selectedEncryption == EncryptionMethod.rsaSign) ...[
                      // const SizedBox(height: AppConstants.defaultPadding),
                      selectedEncryption == EncryptionMethod.rsaSign
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.defaultPadding,
                              ),
                              child: RSAEncryptKeySelector(
                                primaryColor: primaryColor,
                              ),
                            )
                          : SizedBox.shrink(),

                      const SizedBox(height: AppConstants.largePadding / 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: Stack(
                          children: [
                            TextField(
                              controller: _encryptPublicKeyController,
                              onChanged: (val) {
                                try {
                                  // Normalize the input PEM string
                                  String normalized = val.trim().replaceAll(
                                    RegExp(r'\r\n|\r|\n'),
                                    '\n',
                                  );
                                  ref.read(publicKeyProvider.notifier).state =
                                      normalized;
                                  // if (kDebugMode) {
                                  //   print('Saved normalized public key: $normalized');
                                  //   print('Key code units: ${normalized.codeUnits}');
                                  // }
                                } catch (e) {
                                  if (kDebugMode) {
                                    print('Error normalizing public key: $e');
                                  }
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Public Key',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.borderRadius,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.borderRadius,
                                  ),
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: AppConstants.borderWidth,
                                  ),
                                ),
                                errorText: ref.watch(publicKeyProvider).isEmpty
                                    ? null
                                    : (RegExp(
                                            r'^-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/=\n]+\n-----END PUBLIC KEY-----$',
                                          ).hasMatch(
                                            ref.watch(publicKeyProvider),
                                          )
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
                                  final pastedText =
                                      await _pasteFromClipboard();
                                  if (pastedText != null) {
                                    if (isEncryptMode) {
                                      _encryptPublicKeyController.text =
                                          pastedText;
                                      ref
                                          .read(
                                            receiverPublicKeyProvider.notifier,
                                          )
                                          .state = _encryptPublicKeyController
                                          .text;
                                    } else {
                                      _encryptPublicKeyController.text =
                                          pastedText;
                                      ref
                                          .read(
                                            receiverPublicKeyProvider.notifier,
                                          )
                                          .state = _encryptPublicKeyController
                                          .text;
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(
                                  AppConstants.switchBorderRadius,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppConstants.smallPadding,
                                  ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(
                        AppConstants.defaultPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Auto-detect Settings (from Tag)",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Switch(
                            thumbColor: WidgetStateProperty.all(Colors.white),
                            trackColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return primaryColor;
                              }
                              return Colors.grey.shade300;
                            }),
                            value: autoDetectTag,
                            onChanged: (val) =>
                                ref.read(autoDetectTagProvider.notifier).state =
                                    val,
                          ),
                        ],
                      ),
                    ),
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
                    if (selectedEncryption == EncryptionMethod.rsa ||
                        selectedEncryption == EncryptionMethod.rsaSign) ...[
                      // const SizedBox(height: AppConstants.defaultPadding),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: RSADecryptKeySelector(
                          primaryColor: primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      selectedEncryption == EncryptionMethod.rsaSign
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.defaultPadding,
                              ),
                              child: Stack(
                                children: [
                                  TextField(
                                    controller: _decryptPublicKeyController,
                                    onChanged: (val) {
                                      try {
                                        // Normalize the input PEM string
                                        String normalized = val
                                            .trim()
                                            .replaceAll(
                                              RegExp(r'\r\n|\r|\n'),
                                              '\n',
                                            );
                                        ref
                                                .read(
                                                  decryptPublicKeyProvider
                                                      .notifier,
                                                )
                                                .state =
                                            normalized;
                                        decryptPublicKeyGlobal = normalized;
                                        // if (kDebugMode) {
                                        //   print('Saved normalized public key: $normalized');
                                        //   print('Key code units: ${normalized.codeUnits}');
                                        // }
                                      } catch (e) {
                                        if (kDebugMode) {
                                          print(
                                            'Error normalizing public key: $e',
                                          );
                                        }
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Public Key',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppConstants.borderRadius,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppConstants.borderRadius,
                                        ),
                                        borderSide: BorderSide(
                                          color: primaryColor,
                                          width: AppConstants.borderWidth,
                                        ),
                                      ),
                                      errorText:
                                          ref
                                              .watch(decryptPublicKeyProvider)
                                              .isEmpty
                                          ? null
                                          : (RegExp(
                                                  r'^-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/=\n]+\n-----END PUBLIC KEY-----$',
                                                ).hasMatch(
                                                  ref.watch(
                                                    decryptPublicKeyProvider,
                                                  ),
                                                )
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
                                        final pastedText =
                                            await _pasteFromClipboard();
                                        if (pastedText != null) {
                                          if (isEncryptMode) {
                                            _decryptPublicKeyController.text =
                                                pastedText;
                                            ref
                                                    .read(
                                                      decryptPublicKeyProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                _decryptPublicKeyController
                                                    .text;
                                          } else {
                                            _decryptPublicKeyController.text =
                                                pastedText;
                                            ref
                                                    .read(
                                                      decryptPublicKeyProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                _decryptPublicKeyController
                                                    .text;
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.switchBorderRadius,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          AppConstants.smallPadding,
                                        ),
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
                            )
                          : SizedBox.shrink(),
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

                const SizedBox(height: AppConstants.xlargePadding),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding,
                  ),
                  child: const Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppConstants.defaultPadding + 2,
                    bottom: 5,
                    right: AppConstants.defaultPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Output",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isEncryptMode
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final outputText = isEncryptMode
                                ? ref.watch(processedEncryptProvider).text
                                : ref.watch(processedDecryptProvider).text;
                            if (outputText.isNotEmpty) {
                              _copyToClipboard(outputText);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No output to copy'),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(
                            AppConstants.switchBorderRadius,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              AppConstants.smallPadding,
                            ),
                            child: Icon(
                              Icons.content_copy,
                              color: primaryColor,
                              size: AppConstants.iconSize,
                              semanticLabel: 'Copy output to clipboard',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey.shade300),
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
                SizedBox(height: AppConstants.defaultPadding),
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

    ref.read(isProcessingProvider.notifier).state = true;

    try {
      if (!defaultEncryption) {
        final bool isRsaSign = selectedEncryption == EncryptionMethod.rsaSign;
        // Handle RSA encryption separately with proper validation
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
          // Non-RSA encryption
          ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(
            text: _encryptTextController.text,
            encryption: selectedEncryption,
            obfuscation: selectedObfuscation,
            compression: selectedCompression,
            useTag: useTagManually,
          );
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

    ref.read(isProcessingProvider.notifier).state = true;

    try {
      if (!autoDetectTag) {
        ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(
          text: _decryptTextController.text,
          encryption: selectedEncryption,
          obfuscation: selectedObfuscation,
          compression: selectedCompression,
          useTag: false,
        );
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
