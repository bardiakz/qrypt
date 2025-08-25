import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/compression_method.dart';

import '../../models/encryption_method.dart';
import '../../models/obfuscation_method.dart';
import '../../models/sign_method.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<ObfuscationMethod>(
      initialValue: selectedObfuscation,
      items: ObfuscationMethod.values.map((obf) {
        return DropdownMenuItem(value: obf, child: Text(obf.displayName));
      }).toList(),
      onChanged: (val) =>
          ref.read(selectedObfuscationProvider.notifier).state = val!,
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
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<EncryptionMethod>(
      initialValue: ref.watch(selectedEncryptionProvider),
      items: EncryptionMethod.values.map((alg) {
        return DropdownMenuItem(value: alg, child: Text(alg.displayName));
      }).toList(),
      onChanged: (val) =>
          ref.read(selectedEncryptionProvider.notifier).state = val!,
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

class CompressionsDropdownButtonForm extends ConsumerWidget {
  const CompressionsDropdownButtonForm({
    super.key,
    required this.selectedCompression,
    required this.primaryColor,
  });

  final CompressionMethod selectedCompression;
  final Color primaryColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<CompressionMethod>(
      initialValue: selectedCompression,
      items: CompressionMethod.values.map((alg) {
        return DropdownMenuItem(
          value: alg,
          child: Text(alg.name.toUpperCase()),
        );
      }).toList(),
      onChanged: (val) =>
          ref.read(selectedCompressionProvider.notifier).state = val!,
      decoration: InputDecoration(
        labelText: 'Compression Algorithm',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}

class SignsDropdownButtonForm extends ConsumerWidget {
  const SignsDropdownButtonForm({
    super.key,
    required this.selectedSign,
    required this.primaryColor,
  });

  final SignMethod selectedSign;
  final Color primaryColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<SignMethod>(
      initialValue: selectedSign,
      items: SignMethod.values.map((alg) {
        return DropdownMenuItem(value: alg, child: Text(alg.displayName));
      }).toList(),
      onChanged: (val) => ref.read(selectedSignProvider.notifier).state = val!,
      decoration: InputDecoration(
        labelText: 'Sign Algorithm',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}
