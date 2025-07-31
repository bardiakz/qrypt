import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

Color getTextFieldBackgroundColor(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[50]!;
}

Color getContainerBackgroundColor(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark ? Colors.grey[850]! : Colors.grey[50]!;
}

Color getBorderColor(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[300]!;
}

InputDecoration buildInputDecoration({
  required BuildContext context,
  required Color primaryColor,
  String? hintText,
  String? labelText,
  String? errorText,
}) {
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    errorText: errorText,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      borderSide: BorderSide(
        color: primaryColor,
        width: AppConstants.borderWidth,
      ),
    ),
    filled: true,
    fillColor: getTextFieldBackgroundColor(context),
  );
}

String? validateAesKey(String key) {
  if (key.isEmpty) return null;

  final keyLength = key.length;
  if (keyLength != 16 && keyLength != 24 && keyLength != 32) {
    return 'AES key must be 16, 24, or 32 characters long';
  }
  return null;
}

String generateRandomAesKey() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()';
  final random = DateTime.now().millisecondsSinceEpoch;
  var result = '';
  for (var i = 0; i < 32; i++) {
    result += chars[(random + i) % chars.length];
  }
  return result;
}

void copyToClipboard(String text, BuildContext context) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy: ${e.toString()}')),
      );
    }
  }
}

Future<String?> pasteFromClipboard(BuildContext context) async {
  try {
    final clipboardData = await Clipboard.getData('text/plain');
    return clipboardData?.text;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to paste: ${e.toString()}')),
      );
    }
    return null;
  }
}

Widget buildActionButton({
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  required String semanticLabel,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.switchBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.smallPadding),
        child: Icon(
          icon,
          color: color,
          size: AppConstants.iconSize,
          semanticLabel: semanticLabel,
        ),
      ),
    ),
  );
}

Widget buildSectionHeader({
  required String title,
  required String characterCount,
  required List<Widget> actions,
}) {
  return Padding(
    padding: const EdgeInsets.only(
      left: AppConstants.defaultPadding + 2,
      top: 18,
      right: AppConstants.defaultPadding,
    ),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          characterCount,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(width: 12),
        ...actions,
      ],
    ),
  );
}

Widget buildSwitchContainer({
  required BuildContext context,
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
  required Color primaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.defaultPadding,
    ),
    child: Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: getContainerBackgroundColor(context),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Switch(
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return primaryColor;
              }
              return Colors.grey.shade300;
            }),
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

Widget buildPublicKeyField({
  required BuildContext context,
  required TextEditingController controller,
  required Color primaryColor,
  required ValueChanged<String> onChanged,
  required String validationPattern,
  required bool isEncryptMode,
  String? labelText,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.defaultPadding,
    ),
    child: Stack(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: buildInputDecoration(
            context: context,
            primaryColor: primaryColor,
            labelText: labelText ?? 'Public Key',
            errorText: controller.text.isEmpty
                ? null
                : (RegExp(validationPattern).hasMatch(controller.text)
                      ? null
                      : 'Invalid key format'),
          ),
          maxLines: 3,
        ),
        Positioned(
          top: 25,
          right: 5,
          child: InkWell(
            onTap: () async {
              final pastedText = await pasteFromClipboard(context);
              if (pastedText != null) {
                controller.text = pastedText;
                onChanged(pastedText);
              }
            },
            borderRadius: BorderRadius.circular(
              AppConstants.switchBorderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.smallPadding),
              child: Icon(
                Icons.content_paste_go,
                color: Colors.blueGrey,
                size: AppConstants.iconSize + 5,
                semanticLabel: 'Paste from clipboard',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
