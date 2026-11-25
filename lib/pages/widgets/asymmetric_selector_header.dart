import 'package:flutter/material.dart';

import '../../resources/constants.dart';
import '../../resources/global_resources.dart';

/// Deduplicates [keyPairs] by ID and resolves the effective selection, falling
/// back to the first item when [selectedKeyPair] is null or missing.
({List<T> items, T? selected, bool defaultedToFirst}) resolveSelectedKeyPair<T>(
  List<T> keyPairs,
  T? selectedKeyPair,
  String Function(T) getId,
) {
  final uniqueById = <String, T>{};
  for (final item in keyPairs) {
    uniqueById[getId(item)] = item;
  }
  final deduplicated = uniqueById.values.toList();

  T? current;
  if (selectedKeyPair != null) {
    final targetId = getId(selectedKeyPair);
    for (final item in deduplicated) {
      if (getId(item) == targetId) {
        current = item;
        break;
      }
    }
  }

  var defaulted = false;
  if (current == null && deduplicated.isNotEmpty) {
    current = deduplicated.first;
    defaulted = true;
  }

  return (items: deduplicated, selected: current, defaultedToFirst: defaulted);
}

/// Formats a creation date concisely for key picker subtitles.
String formatPublicKeyCreatedDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

/// Opens a clean modal list dialog allowing the user to select an active key pair.
Future<T?> showPublicKeyChoiceDialog<T>({
  required BuildContext context,
  required Color primaryColor,
  required String title,
  required List<T> keyPairs,
  required String Function(T) getId,
  required String Function(T) getName,
  required String Function(T) getSubtitle,
  T? selectedKeyPair,
  VoidCallback? onManageKeys,
}) {
  final resolved = resolveSelectedKeyPair<T>(keyPairs, selectedKeyPair, getId);
  if (resolved.items.isEmpty) {
    return Future<T?>.value();
  }

  final selectedId = resolved.selected != null
      ? getId(resolved.selected as T)
      : null;

  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: resolved.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final kp = resolved.items[index];
                final isSelected = selectedId != null && getId(kp) == selectedId;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryColor : null,
                  ),
                  title: Text(
                    getName(kp),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    getSubtitle(kp),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(kp),
                );
              },
            ),
          ),
        ),
        actions: [
          if (onManageKeys != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onManageKeys();
              },
              child: const Text('Manage Keys'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

/// Expandable card container used by `EncryptionPage` to display one or more
/// public-key sharing shortcut rows with uniform Material 3 hierarchy.
class PublicKeyShareCard extends StatefulWidget {
  final String title;
  final String? collapsedSummary;
  final Widget? trailingAction;
  final List<Widget> rows;
  final bool initiallyExpanded;

  const PublicKeyShareCard({
    super.key,
    required this.title,
    this.collapsedSummary,
    this.trailingAction,
    required this.rows,
    this.initiallyExpanded = false,
  });

  @override
  State<PublicKeyShareCard> createState() => _PublicKeyShareCardState();
}

class _PublicKeyShareCardState extends State<PublicKeyShareCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    final bodyChildren = <Widget>[];
    for (var i = 0; i < widget.rows.length; i++) {
      if (i > 0) {
        bodyChildren.add(const Divider(height: 12, thickness: 0.6));
      }
      bodyChildren.add(widget.rows[i]);
    }

    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: getContainerBackgroundColor(context),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius - 1),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: mutedColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_isExpanded &&
                                  widget.collapsedSummary != null &&
                                  widget.collapsedSummary!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '• ${widget.collapsedSummary!}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mutedColor?.withValues(alpha: 0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.trailingAction != null) ...[
                          const SizedBox(width: 4),
                          widget.trailingAction!,
                        ],
                        const SizedBox(width: 4),
                        Tooltip(
                          message: _isExpanded ? 'Collapse' : 'Expand',
                          child: AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.expand_more,
                              size: 20,
                              color: mutedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 8, thickness: 0.6),
                        const SizedBox(height: 2),
                        ...bodyChildren,
                      ],
                    ),
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  sizeCurve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single aligned row displaying an algorithm badge, active key name (with an
/// inline switcher pill when multiple keys exist), and a tonal Share/Create button.
class PublicKeyShareRow extends StatelessWidget {
  final Color primaryColor;
  final String algorithmLabel;
  final String? selectedKeyName;
  final bool canSwitch;
  final VoidCallback? onChooseKey;
  final VoidCallback? onSharePublicKey;
  final VoidCallback? onCreateKey;

  const PublicKeyShareRow({
    super.key,
    required this.primaryColor,
    required this.algorithmLabel,
    required this.selectedKeyName,
    this.canSwitch = false,
    this.onChooseKey,
    this.onSharePublicKey,
    this.onCreateKey,
  });

  @override
  Widget build(BuildContext context) {
    final keyName = selectedKeyName;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              algorithmLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: keyName == null
                ? Text(
                    'No keys saved',
                    style: TextStyle(fontSize: 13, color: mutedColor),
                    overflow: TextOverflow.ellipsis,
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: canSwitch && onChooseKey != null
                        ? Tooltip(
                            message: 'Change $algorithmLabel key pair',
                            child: Material(
                              color: getTextFieldBackgroundColor(context),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: onChooseKey,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: getBorderColor(context),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          keyName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.unfold_more,
                                        size: 16,
                                        color: mutedColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            keyName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
          ),
          const SizedBox(width: 8),
          if (keyName != null)
            Tooltip(
              message: 'Share $algorithmLabel public key ($keyName)',
              child: FilledButton.tonalIcon(
                onPressed: onSharePublicKey,
                icon: const Icon(Icons.qr_code_2, size: 16),
                label: const Text('Share'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: primaryColor.withValues(alpha: 0.14),
                  foregroundColor: primaryColor,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            FilledButton.tonalIcon(
              onPressed: onCreateKey,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: primaryColor.withValues(alpha: 0.14),
                foregroundColor: primaryColor,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared card header row for asymmetric key selectors with a 1-tap public key
/// share shortcut alongside the key management action.
class AsymmetricSelectorHeader extends StatelessWidget {
  final String title;
  final Color primaryColor;
  final String manageTooltip;
  final String shareTooltip;
  final VoidCallback onManagePressed;
  final VoidCallback? onSharePublicKey;

  const AsymmetricSelectorHeader({
    super.key,
    required this.title,
    required this.primaryColor,
    required this.manageTooltip,
    this.shareTooltip = 'Share Public Key',
    required this.onManagePressed,
    this.onSharePublicKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSharePublicKey != null)
          IconButton(
            onPressed: onSharePublicKey,
            icon: Icon(Icons.qr_code_2, color: primaryColor),
            tooltip: shareTooltip,
          ),
        IconButton(
          onPressed: onManagePressed,
          icon: Icon(Icons.key, color: primaryColor),
          tooltip: manageTooltip,
        ),
      ],
    );
  }
}
