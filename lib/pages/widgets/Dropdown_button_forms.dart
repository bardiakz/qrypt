import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/encryption.dart';
import '../../models/obfuscation.dart';
import '../../providers/encryption_providers.dart';

class ObfsDropdownButtonForm extends ConsumerWidget {
  const ObfsDropdownButtonForm({
    super.key,
    required this.selectedObfuscation,
    required this.primaryColor,

  });

  final ObfuscationMethod selectedObfuscation;
  final Color primaryColor;

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    return DropdownButtonFormField<ObfuscationMethod>(
      value: selectedObfuscation,
      items: ObfuscationMethod.values.map((obf) {
        return DropdownMenuItem(
          value: obf,
          child: Text(obf.name.toUpperCase()),
        );
      }).toList(),
      onChanged: (val) => ref.read(selectedObfuscationProvider.notifier).state = val!,
      decoration: InputDecoration(
        labelText: 'Obfuscation Method',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}

class EncryptionsDropdownButtonForm extends ConsumerWidget {
  const EncryptionsDropdownButtonForm({
    super.key,
    required this.selectedEncryption,
    required this.primaryColor,
  });

  final EncryptionMethod selectedEncryption;
  final Color primaryColor;

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    return DropdownButtonFormField<EncryptionMethod>(
      value: selectedEncryption,
      items: EncryptionMethod.values.map((alg) {
        return DropdownMenuItem(
          value: alg,
          child: Text(alg.name.toUpperCase()),
        );
      }).toList(),
      onChanged: (val) => ref.read(selectedEncryptionProvider.notifier).state = val!,
      decoration: InputDecoration(
        labelText: 'Encryption Algorithm',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}