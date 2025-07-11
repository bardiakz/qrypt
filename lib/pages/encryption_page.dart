import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/providers/encryption_providers.dart';

class EncryptionPage extends ConsumerWidget {
  const EncryptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appMode = ref.watch(appModeProvider);
    final defaultEncryption = ref.watch(defaultEncryptionProvider);
    final autoDetectTag = ref.watch(autoDetectTagProvider);

    final selectedEncryption = ref.watch(selectedEncryptionProvider);
    final selectedObfuscation = ref.watch(selectedObfuscationProvider);
    final publicKey = ref.watch(publicKeyProvider);

    return SafeArea(
      child: Scaffold(
        // appBar: AppBar(title: const Text('Qrypt')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              modeSwitch(appMode,ref),

              const SizedBox(height: 24),

              const Align(alignment: Alignment.centerLeft, child: Text("Message")),
              const SizedBox(height: 8),
              const TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Enter or paste text...",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              if (appMode == AppMode.encrypt) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Use Default Encryption"),
                    Switch(
                      value: defaultEncryption,
                      onChanged: (val) => ref
                          .read(defaultEncryptionProvider.notifier)
                          .state = val,
                    ),
                  ],
                ),
                if (!defaultEncryption) ...[
                  DropdownButtonFormField<String>(
                    value: selectedEncryption,
                    items: ['Kyber', 'AES', 'XOR'].map((alg) {
                      return DropdownMenuItem(value: alg, child: Text(alg));
                    }).toList(),
                    onChanged: (val) => ref
                        .read(selectedEncryptionProvider.notifier)
                        .state = val!,
                    decoration:
                    const InputDecoration(labelText: 'Encryption Algorithm'),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedObfuscation,
                    items: ['None', 'Persian', 'Emoji'].map((obf) {
                      return DropdownMenuItem(value: obf, child: Text(obf));
                    }).toList(),
                    onChanged: (val) => ref
                        .read(selectedObfuscationProvider.notifier)
                        .state = val!,
                    decoration:
                    const InputDecoration(labelText: 'Obfuscation Method'),
                  ),
                  TextField(
                    onChanged: (val) =>
                    ref.read(publicKeyProvider.notifier).state = val,
                    decoration:
                    const InputDecoration(labelText: 'Public Key (optional)'),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Encrypt
                  },
                  child: const Text("Encrypt"),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Auto-detect Settings (from Tag)"),
                    Switch(
                      value: autoDetectTag,
                      onChanged: (val) => ref
                          .read(autoDetectTagProvider.notifier)
                          .state = val,
                    ),
                  ],
                ),
                if (!autoDetectTag) ...[
                  DropdownButtonFormField<String>(
                    value: selectedEncryption,
                    items: ['Kyber', 'AES', 'XOR'].map((alg) {
                      return DropdownMenuItem(value: alg, child: Text(alg));
                    }).toList(),
                    onChanged: (val) => ref
                        .read(selectedEncryptionProvider.notifier)
                        .state = val!,
                    decoration:
                    const InputDecoration(labelText: 'Encryption Algorithm'),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedObfuscation,
                    items: ['None', 'Persian', 'Emoji'].map((obf) {
                      return DropdownMenuItem(value: obf, child: Text(obf));
                    }).toList(),
                    onChanged: (val) => ref
                        .read(selectedObfuscationProvider.notifier)
                        .state = val!,
                    decoration:
                    const InputDecoration(labelText: 'Obfuscation Method'),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Decrypt
                  },
                  child: const Text("Decrypt"),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const Align(alignment: Alignment.centerLeft, child: Text("Output")),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SelectableText(
                  "Your encrypted or decrypted output will appear here.",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Widget modeSwitch(AppMode selected, WidgetRef ref) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: AppMode.values.map((mode) {
        final isSelected = mode == selected;
        return GestureDetector(
          onTap: () =>
          ref.read(appModeProvider.notifier).state = mode,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              mode == AppMode.encrypt ? 'Encrypt' : 'Decrypt',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

