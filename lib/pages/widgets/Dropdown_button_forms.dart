import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';

import '../../models/custom_obfuscation_profile.dart';
import '../../models/encryption_method.dart';
import '../../models/obfuscation_method.dart';
import '../../models/sign_method.dart';
import '../../providers/encryption_providers.dart';
import '../../services/obfuscation/custom_map_storage_service.dart';
import 'custom_map_picker_dialog.dart';

class ObfsDropdownButtonForm extends ConsumerWidget {
  const ObfsDropdownButtonForm({
    super.key,
    required this.selectedObfuscation,
    required this.primaryColor,
    this.isDecryptMode = false,
  });

  final ObfuscationMethod selectedObfuscation;
  final Color primaryColor;
  final bool isDecryptMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = isDecryptMode
        ? ObfuscationService.selectableForDecrypt
        : ObfuscationService.selectableForEncrypt;

    final targetValue = isDecryptMode
        ? selectedObfuscation
        : selectedObfuscation.v2Equivalent;

    final effectiveValue = available.contains(targetValue)
        ? targetValue
        : (available.contains(ObfuscationService.defaultMethod)
            ? ObfuscationService.defaultMethod
            : available.first);

    return DropdownButtonFormField<ObfuscationMethod>(
      value: effectiveValue,
      items: available.map((obf) {
        return DropdownMenuItem(value: obf, child: Text(obf.displayName));
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          ref.read(selectedObfuscationProvider.notifier).state = val;
        }
      },
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

class CustomMapDropdownButtonForm extends ConsumerWidget {
  const CustomMapDropdownButtonForm({
    super.key,
    required this.primaryColor,
  });

  final Color primaryColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProfile = ref.watch(selectedCustomMapProvider);
    final profiles = CustomMapStorageService.instance.profiles;

    if (profiles.isEmpty) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('No Custom Maps — Create or Import'),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          final chosen = await showCustomMapPickerDialog(context);
          if (chosen != null) {
            ref.read(selectedCustomMapProvider.notifier).state = chosen;
          }
        },
      );
    }

    final effectiveProfile = (selectedProfile != null &&
            profiles.any((p) => p.id == selectedProfile.id))
        ? profiles.firstWhere((p) => p.id == selectedProfile.id)
        : profiles.first;

    if (selectedProfile == null && profiles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedCustomMapProvider.notifier).state = effectiveProfile;
      });
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<CustomObfuscationProfile>(
            value: effectiveProfile,
            items: profiles.map((p) {
              return DropdownMenuItem(value: p, child: Text(p.name));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(selectedCustomMapProvider.notifier).state = val;
              }
            },
            decoration: InputDecoration(
              labelText: 'Select Custom Map',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add / Import Map',
          onPressed: () async {
            final chosen = await showCustomMapPickerDialog(context);
            if (chosen != null) {
              ref.read(selectedCustomMapProvider.notifier).state = chosen;
            }
          },
        ),
      ],
    );
  }
}
