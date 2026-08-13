import 'package:flutter/foundation.dart';

/// Logs an info message to the debug console.
void printI(Object? message) {
  debugPrint('[INFO] $message');
}

/// Logs an error message to the debug console.
void printE(Object? message, {Object? error, StackTrace? stacktrace}) {
  debugPrint('[ERROR] $message');
  if (error != null) {
    debugPrint('Error details: $error');
  }
  if (stacktrace != null) {
    debugPrint('Stacktrace:\n$stacktrace');
  }
}

/// Logs a warning message to the debug console.
void printW(Object? message) {
  debugPrint('[WARN] $message');
}

/// Logs a debug message to the debug console.
void printD(Object? message) {
  debugPrint('[DEBUG] $message');
}
