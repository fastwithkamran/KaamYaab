import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Shared reusable input widgets used across all auth screens.

// ── Pakistan phone helpers ──────────────────────────────────────────────────
// FIX: kept as top-level so they remain accessible across auth screens, but
// named with a clear prefix so they don't pollute the global namespace.
final RegExp pakistanPhoneRegex = RegExp(r'^03\d{9}$');

// LengthLimitingTextInputFormatter cannot be const (it's not a const
// constructor), so `final` is correct here.
final List<TextInputFormatter> pakistanPhoneInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(11),
];

// ── Glass-style text input ──────────────────────────────────────────────────
class AuthGlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final Color accentColor;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  // FIX: renamed to `lines` to make the field-level intent clearer:
  // the widget always enforces maxLines=1 for password fields, so exposing
  // the raw `maxLines` name was misleading. `lines` conveys "visible lines
  // when not obscured".
  final int lines;
  final String? Function(String?)? validator;

  const AuthGlassInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.accentColor,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.lines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          // Password fields must always be single-line regardless of `lines`.
          maxLines: obscureText ? 1 : lines,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            // Hide the character counter — auth inputs rely on inline error
            // messages, not a running count.
            counterText: '',
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
            prefixIcon: Icon(prefixIcon, color: accentColor, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppTheme.redError, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppTheme.redError, width: 1.5),
            ),
            errorStyle: const TextStyle(color: AppTheme.redError),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ── Dropdown field ──────────────────────────────────────────────────────────
class AuthDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final Color accentColor;
  final ValueChanged<String?> onChanged;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;

  const AuthDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.accentColor,
    required this.onChanged,
    this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // FIX: removed the stale `// ignore: deprecated_member_use` comment.
        // The `value` parameter on DropdownButtonFormField<String> is not
        // deprecated in current Flutter; the ignore was left over from an
        // earlier SDK version.
        DropdownButtonFormField<String>(
          initialValue: value,
          validator: validator,
          hint: Text(
            hint,
            style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
          ),
          dropdownColor: AppTheme.cardDark,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          icon: Icon(Icons.keyboard_arrow_down, color: accentColor),
          decoration: InputDecoration(
            prefixIcon: Icon(
              prefixIcon ?? Icons.arrow_drop_down_circle_outlined,
              color: accentColor,
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppTheme.redError, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppTheme.redError, width: 1.5),
            ),
            errorStyle: const TextStyle(color: AppTheme.redError),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Error banner ────────────────────────────────────────────────────────────
class AuthErrorBox extends StatelessWidget {
  final String message;
  const AuthErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.redError.withValues(alpha: 0.1),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.redError.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppTheme.redError, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppTheme.redError, fontSize: 13),
          ),
        ),
      ]),
    ).animate().shake(duration: 400.ms);
  }
}

// ── Section header ──────────────────────────────────────────────────────────
class AuthSectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const AuthSectionHeader({
    super.key,
    required this.title,
    this.color = AppTheme.tealPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ]);
  }
}