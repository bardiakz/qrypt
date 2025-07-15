import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/pages/widgets/Dropdown_button_forms.dart';
import 'package:qrypt/pages/widgets/mode_switch.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:flutter/services.dart';
import '../models/encryption_method.dart';
import '../providers/resource_providers.dart';
import '../services/input_handler.dart';

class EncryptionPage extends ConsumerStatefulWidget {
  const EncryptionPage({super.key});

  @override
  ConsumerState<EncryptionPage> createState() => _EncryptionPageState();
}

class _EncryptionPageState extends ConsumerState<EncryptionPage> {
  final _encryptTextController = TextEditingController();
  final _decryptTextController = TextEditingController();
  final InputHandler ih = InputHandler();

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
  void dispose() {
    _encryptTextController.dispose();
    _decryptTextController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<String?> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    return clipboardData?.text;
  }

  @override
  void initState() {
    super.initState();
    // _inputTextController.addListener(_onTextChanged);
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
    final selectedCompression = ref.watch(selectedCompressionProvider);
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

              // const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.only(left: 2,top: 18),
                child: Row(
                  children: [
                    Text("Message", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Spacer(),
                    Text(ref.watch(inputTextProvider).length.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300,color: Colors.blueGrey)),
                    SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (){
                          if(appModeIsEncrypt()){
                          _encryptTextController.clear();
                          ref.read(inputTextProvider.notifier).state = _encryptTextController.text;
                          }else{
                          _decryptTextController.clear();
                          ref.read(inputTextProvider.notifier).state = _decryptTextController.text;
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.clear, color: primaryColor, size: 20),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final pastedText = await _pasteFromClipboard();
                          if (pastedText != null) {
                            if(appModeIsEncrypt()){
                              _encryptTextController.text = pastedText;
                              ref.read(inputTextProvider.notifier).state = _encryptTextController.text;
                            }else{
                              _decryptTextController.text = pastedText;
                              ref.read(inputTextProvider.notifier).state = _decryptTextController.text;
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.content_paste, color: primaryColor, size: 20),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              // const SizedBox(height: 12),
              TextField(
                onChanged: (text){ ref.read(inputTextProvider.notifier).state = text;},
                controller: appModeIsEncrypt()?_encryptTextController:_decryptTextController,
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
                  CompressionsDropdownButtonForm(
                    selectedCompression: selectedCompression,
                    primaryColor: primaryColor,
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
                      _encrypt(defaultEncryption, selectedEncryption, selectedObfuscation, selectedCompression, useTagManually);
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
                  CompressionsDropdownButtonForm(
                    selectedCompression: selectedCompression,
                    primaryColor: primaryColor,
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
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _decrypt(autoDetectTag, selectedEncryption, selectedObfuscation, selectedCompression);
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
              Padding(
                padding: const EdgeInsets.only(left: 2,bottom: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text("Output", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),

                  Spacer(),
                  Text(appModeIsEncrypt()?ref.watch(processedEncryptProvider).text.length.toString():ref.watch(processedDecryptProvider).text.length.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300,color: Colors.blueGrey)),
                    SizedBox(width: 12,),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: ()async{
                          _copyToClipboard(appModeIsEncrypt()?ref.watch(processedEncryptProvider).text:ref.watch(processedDecryptProvider).text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied to clipboard!')),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.content_copy, color: primaryColor, size: 20),
                        ),
                      ),
                    ),
                ],),
              ),
              // const SizedBox(height: 2),
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
                  appModeIsEncrypt()?ref.watch(processedEncryptProvider).text:ref.watch(processedDecryptProvider).text,
                  style: TextStyle(fontSize: 16),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  bool appModeIsEncrypt() => ref.read(appModeProvider) == AppMode.encrypt;

  void _decrypt(bool autoDetectTag, EncryptionMethod selectedEncryption, ObfuscationMethod selectedObfuscation, CompressionMethod selectedCompression) {
    if(!autoDetectTag){
      ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(text: _decryptTextController.text, encryption: selectedEncryption, obfuscation: selectedObfuscation,compression: selectedCompression,useTag: false);
      ref.read(processedDecryptProvider.notifier).state = ih.handleDeProcess(ref.read(inputQryptProvider),false);
    }else{
      ref.read(inputQryptProvider.notifier).state = Qrypt.autoDecrypt(text:_decryptTextController.text);
      ref.read(processedDecryptProvider.notifier).state = ih.handleDeProcess(ref.read(inputQryptProvider),true);
    }
  }

  void _encrypt(bool defaultEncryption, EncryptionMethod selectedEncryption, ObfuscationMethod selectedObfuscation, CompressionMethod selectedCompression, bool useTagManually) {
    if(!defaultEncryption){
      ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(text: _encryptTextController.text, encryption: selectedEncryption, obfuscation: selectedObfuscation,compression: selectedCompression,useTag: useTagManually);
      ref.read(processedEncryptProvider.notifier).state = ih.handleProcess(ref.read(inputQryptProvider));
    }else{
      ref.read(inputQryptProvider.notifier).state = Qrypt.withTag(text: _encryptTextController.text, encryption: EncryptionMethod.aesCbc, obfuscation: ObfuscationMethod.fa2,compression: CompressionMethod.gZip,useTag: true);
      ref.read(processedEncryptProvider.notifier).state = ih.handleProcess(ref.read(inputQryptProvider));
    }
  }
}

