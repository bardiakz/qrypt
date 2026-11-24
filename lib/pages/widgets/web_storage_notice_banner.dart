import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/providers/simple_state_provider.dart';

/// Tracks whether the user dismissed the Flutter Web non-hardware storage notice
/// for the current session.
final webStorageNoticeDismissedProvider = simpleStateProvider<bool>(false);

/// Subtle dismissible notice displayed only on Flutter Web (`kIsWeb`) explaining
/// that browser storage is not hardware-backed Keystore/Keychain storage.
class WebStorageNoticeBanner extends ConsumerWidget {
  /// Allows overriding `kIsWeb` in widget tests.
  final bool showOnCurrentPlatform;

  const WebStorageNoticeBanner({
    super.key,
    this.showOnCurrentPlatform = kIsWeb,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showOnCurrentPlatform) return const SizedBox.shrink();

    final dismissed = ref.watch(webStorageNoticeDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.amber.shade900.withValues(alpha: 0.25)
              : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.amber.shade700 : Colors.amber.shade300,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Web preview stores keys in browser storage rather than hardware-backed Keystore/Keychain. Use native desktop or mobile builds for sensitive keys.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Dismiss web storage notice',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                ref.read(webStorageNoticeDismissedProvider.notifier).state =
                    true;
              },
            ),
          ],
        ),
      ),
    );
  }
}
