import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import '../../providers/resource_providers.dart';

Widget modeSwitch(
  BuildContext context,
  AppMode selected,
  Color primaryColor,
  WidgetRef ref,
  TextEditingController encryptTextController,
  TextEditingController decryptTextController,
) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final trackColor = isDark
      ? theme.colorScheme.surfaceContainerHighest
      : Colors.grey.shade300;
  final inactiveTextColor = isDark
      ? theme.colorScheme.onSurface
      : Colors.black87;

  return Tooltip(
    message: 'Switch mode (Ctrl+M)',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth < 260.0 ? constraints.maxWidth : 260.0)
            : 260.0;
        final double halfWidth = width / 2;

        return SizedBox(
          height: 48,
          width: width,
          child: Stack(
            children: [
              // Background bar
              Container(
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),

              // Animated moving highlight (with dynamic primaryColor)
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: selected == AppMode.encrypt
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: halfWidth,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Text row
              Row(
                children: AppMode.values.map((mode) {
                  final isSelected = mode == selected;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        ref.read(appModeProvider.notifier).state = mode;
                        ref.read(inputTextProvider.notifier).state =
                            mode == AppMode.encrypt
                            ? encryptTextController.text
                            : decryptTextController.text;
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        height: 48,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            mode == AppMode.encrypt ? 'Encrypt' : 'Decrypt',
                            maxLines: 1,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : inactiveTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    ),
  );
}
