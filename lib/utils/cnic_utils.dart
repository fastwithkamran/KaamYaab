import 'package:flutter/services.dart';

class CnicUtils {
  static final RegExp _cnicRegex = RegExp(r'^\d{13}$');

  static final List<TextInputFormatter> inputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(13),
  ];

  static bool isValid(String value) => _cnicRegex.hasMatch(value);

  static String? validator(String? value) {
    if (value == null || value.isEmpty) return 'CNIC is required';
    if (!isValid(value)) return 'Enter 13 digits without dashes';
    return null;
  }
}
