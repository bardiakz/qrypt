import 'package:flutter/material.dart';
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
