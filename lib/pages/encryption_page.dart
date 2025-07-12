import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/obfuscation.dart';
import 'package:qrypt/pages/widgets/Dropdown_button_forms.dart';
import 'package:qrypt/pages/widgets/mode_switch.dart';
import 'package:qrypt/providers/encryption_providers.dart';

import '../models/encryption.dart';
import '../providers/resource_providers.dart';
import '../services/input_handler.dart';

class EncryptionPage extends ConsumerStatefulWidget {
  const EncryptionPage({super.key});

  @override
  ConsumerState<EncryptionPage> createState() => _EncryptionPageState();
}

class _EncryptionPageState extends ConsumerState<EncryptionPage> {
  final inputTextController = TextEditingController();
  final InputHandler ih = InputHandler();

  @override
  void dispose() {
    inputTextController.dispose(); // Proper cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final AppMode appMode = ref.watch(appModeProvider);
    final Color primaryColor = ref.watch(primaryColorProvider);
    final bool defaultEncryption = ref.watch(defaultEncryptionProvider);
    final autoDetectTag = ref.watch(autoDetectTagProvider);
    final useTagManually = ref.watch(useTagProvider);



    final selectedEncryption = ref.watch(selectedEncryptionProvider);
    final selectedObfuscation = ref.watch(selectedObfuscationProvider);
    final publicKey = ref.watch(publicKeyProvider);

    return SafeArea(
      child: Scaffold(
        // appBar: AppBar(title: const Text('Qrypt')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: modeSwitch(appMode, primaryColor, ref),
                ),
              ),

              const SizedBox(height: 32),

              const Align(alignment: Alignment.centerLeft,
                  child: Text("Message", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              const SizedBox(height: 12),
              TextField(
                controller: inputTextController,
                maxLines: 4,
                decoration: InputDecoration(

                  hintText: "Enter or paste text...",
                  border: OutlineInputBorder(

                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),

              const SizedBox(height: 24),

              if (appMode == AppMode.encrypt) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Use Default Encryption", style: TextStyle(fontWeight: FontWeight.w500)),
                      Switch(
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        trackColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return primaryColor;
                          }
                          return Colors.grey.shade300;
                        }),

                        value: defaultEncryption,
                        onChanged: (val) => ref
                            .read(defaultEncryptionProvider.notifier)
                            .state = val,
                      ),
                    ],
                  ),
                ),
                if (!defaultEncryption) ...[
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: useTagManually ? primaryColor.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: useTagManually ? primaryColor.withOpacity(0.3) : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon(
                        //   Icons.local_offer_rounded,
                        //   color: useTagManually ? primaryColor : Colors.grey[600],
                        //   size: 20,
                        // ),
                        const SizedBox(width: 12),
                        Expanded(
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
                          onChanged: (val) => ref.read(useTagProvider.notifier).state = val,
                          activeColor: primaryColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  EncryptionsDropdownButtonForm(
                    selectedEncryption: selectedEncryption,
                    primaryColor: primaryColor,
                  ),

                  const SizedBox(height: 16),
                  ObfsDropdownButtonForm(
                    selectedObfuscation: selectedObfuscation,
                    primaryColor: primaryColor,
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) =>
                    ref.read(publicKeyProvider.notifier).state = val,
                    decoration: InputDecoration(
                      labelText: 'Public Key (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                  ),
                ],


                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Encrypt
                      ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(text: inputTextController.text, encryption: selectedEncryption, obfuscation: selectedObfuscation,useTag: defaultEncryption);
                      ref.read(processedCryptProvider.notifier).state = ih.handleEncrypt(ref.read(inputQryptProvider));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Encrypt", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Auto-detect Settings (from Tag)", style: TextStyle(fontWeight: FontWeight.w500)),
                      Switch(
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        trackColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return primaryColor;
                          }
                          return Colors.grey.shade300;
                        }),
                        value: autoDetectTag,
                        onChanged: (val) => ref.read(autoDetectTagProvider.notifier).state = val,
                      ),
                    ],
                  ),
                ),

                if (!autoDetectTag) ...[
                  const SizedBox(height: 16),
                  EncryptionsDropdownButtonForm(
                    selectedEncryption: selectedEncryption,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  ObfsDropdownButtonForm(
                    selectedObfuscation: selectedObfuscation,
                    primaryColor: primaryColor,
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Decrypt
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Decrypt",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],



              const SizedBox(height: 32),
              const Divider(),
              const Align(alignment: Alignment.centerLeft,
                  child: Text("Output", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              const SizedBox(height: 12),
              Container(
                height: screenHeight*0.25,
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 120),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  ref.watch(processedCryptProvider).text,
                  style: TextStyle(fontSize: 16),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

