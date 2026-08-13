import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../theme/app_theme.dart';

/// Centralized toast notification utility adapted to the sleek Linear/Raycast-inspired dark theme.
///
/// All user-facing notifications MUST go through this class.
/// Never use `Get.snackbar()`, `Get.rawSnackbar()`, `ScaffoldMessenger`,
/// or raw `toastification.show()` directly.
class Notify {
  Notify._();

  static void success(String title, {String? description}) {
    _show(
      type: ToastificationType.success,
      title: title,
      description: description,
      accentColor: AppTheme.accent,
      icon: const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 19),
    );
  }

  static void error(String title, {String? description}) {
    _show(
      type: ToastificationType.error,
      title: title,
      description: description,
      accentColor: AppTheme.danger,
      icon: const Icon(Icons.error_rounded, color: AppTheme.danger, size: 19),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  static void warning(String title, {String? description}) {
    _show(
      type: ToastificationType.warning,
      title: title,
      description: description,
      accentColor: AppTheme.warning,
      icon: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 19),
    );
  }

  static void info(String title, {String? description}) {
    _show(
      type: ToastificationType.info,
      title: title,
      description: description,
      accentColor: const Color(0xFF38BDF8),
      icon: const Icon(Icons.info_rounded, color: Color(0xFF38BDF8), size: 19),
    );
  }

  static void _show({
    required ToastificationType type,
    required String title,
    String? description,
    required Color accentColor,
    required Widget icon,
    Duration autoCloseDuration = const Duration(seconds: 3),
  }) {
    toastification.show(
      type: type,
      style: ToastificationStyle.flat,
      icon: icon,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          fontSize: 13,
          letterSpacing: AppTheme.trackingTight,
        ),
      ),
      description: description != null && description.isNotEmpty
          ? Text(
              description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                height: 1.3,
              ),
            )
          : null,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: autoCloseDuration,
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
        color: AppTheme.borderStrong,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(180),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: accentColor.withAlpha(20),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
      primaryColor: accentColor,
      backgroundColor: AppTheme.surfaceElevated,
      foregroundColor: AppTheme.textPrimary,
      showProgressBar: false,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }
}
