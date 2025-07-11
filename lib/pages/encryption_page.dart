import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/providers/encryption_providers.dart';
class EncryptionPage extends ConsumerWidget {
  const EncryptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultEncryption = ref.watch(defaultEncryptionProvider);
    final autoDetectTag = ref.watch(autoDetectTagProvider);
    final selectedEncryption = ref.watch(selectedEncryptionProvider);
    final selectedObfuscation = ref.watch(selectedObfuscationProvider);
    final publicKey = ref.watch(publicKeyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Qrypt')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text("Enter your message"),
            const SizedBox(height: 8),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Use Default Encryption (Recommended)"),
                Switch(
                  value: defaultEncryption,
                  onChanged: (val) =>
                  ref.read(defaultEncryptionProvider.notifier).state = val,
                ),
              ],
            ),

            if (!defaultEncryption) ...[
              DropdownButtonFormField<String>(
                value: selectedEncryption,
                items: ['Kyber', 'AES', 'XOR'].map((alg) {
                  return DropdownMenuItem(value: alg, child: Text(alg));
                }).toList(),
                onChanged: (val) =>
                ref.read(selectedEncryptionProvider.notifier).state = val!,
                decoration: const InputDecoration(labelText: 'Encryption'),
              ),
              DropdownButtonFormField<String>(
                value: selectedObfuscation,
                items: ['None', 'Persian', 'Emoji'].map((obf) {
                  return DropdownMenuItem(value: obf, child: Text(obf));
                }).toList(),
                onChanged: (val) =>
                ref.read(selectedObfuscationProvider.notifier).state =
                val!,
                decoration: const InputDecoration(labelText: 'Obfuscation'),
              ),
              TextField(
                onChanged: (val) =>
                ref.read(publicKeyProvider.notifier).state = val,
                decoration: const InputDecoration(labelText: 'Public Key'),
              ),
            ],

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Trigger encryption
              },
              child: const Text("Encrypt Message"),
            ),

            const Divider(height: 40),

            const Text("Decryption"),
            const SizedBox(height: 8),
            const TextField(
              maxLines: 4,
              decoration:
              InputDecoration(hintText: "Paste encrypted message", border: OutlineInputBorder()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Auto-detect settings"),
                Switch(
                  value: autoDetectTag,
                  onChanged: (val) =>
                  ref.read(autoDetectTagProvider.notifier).state = val,
                ),
              ],
            ),

            if (!autoDetectTag) ...[
              DropdownButtonFormField<String>(
                value: selectedEncryption,
                items: ['Kyber', 'AES', 'XOR'].map((alg) {
                  return DropdownMenuItem(value: alg, child: Text(alg));
                }).toList(),
                onChanged: (val) =>
                ref.read(selectedEncryptionProvider.notifier).state = val!,
                decoration: const InputDecoration(labelText: 'Encryption'),
              ),
              DropdownButtonFormField<String>(
                value: selectedObfuscation,
                items: ['None', 'Persian', 'Emoji'].map((obf) {
                  return DropdownMenuItem(value: obf, child: Text(obf));
                }).toList(),
                onChanged: (val) =>
                ref.read(selectedObfuscationProvider.notifier).state =
                val!,
                decoration: const InputDecoration(labelText: 'Obfuscation'),
              ),
            ],

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Trigger decryption
              },
              child: const Text("Decrypt Message"),
            ),
          ],
        ),
      ),
    );
  }
}
