import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/resource_providers.dart';

Widget modeSwitch(AppMode selected, Color primaryColor, WidgetRef ref) {
  return SizedBox(
    height: 48,
    width: 260,
    child: Stack(
      children: [
        // Background bar
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
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
            width: 130,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
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
                onTap: () =>
                ref.read(appModeProvider.notifier).state = mode,
                child: Container(
                  alignment: Alignment.center,
                  height: 48,
                  child: Text(
                    mode == AppMode.encrypt ? 'Encrypt' : 'Decrypt',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        )
      ],
    ),
  );
}
