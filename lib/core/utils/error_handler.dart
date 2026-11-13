import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts raw exceptions into friendly one-line messages.
String friendlyError(Object e) {
  if (e is PostgrestException) {
    // In debug mode expose the real message so we can diagnose issues
    if (kDebugMode) {
      return 'DB error [${e.code}]: ${e.message}${e.details != null ? ' — ${e.details}' : ''}';
    }
    // Map Postgres error codes to human-readable messages
    final msg = e.message.toLowerCase();
    if (msg.contains('infinite recursion')) {
      return 'Something went wrong on our end. Please try again.';
    }
    if (msg.contains('duplicate') || msg.contains('unique')) {
      return 'This already exists.';
    }
    if (msg.contains('foreign key') || msg.contains('violates')) {
      return 'Invalid data — please try again.';
    }
    if (msg.contains('permission') || msg.contains('rls') || msg.contains('policy')) {
      return 'You don\'t have permission to do that.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'Server error. Please try again.';
  }

  if (e is AuthException) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (msg.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('weak password')) {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return e.message;
  }

  final str = e.toString().toLowerCase();
  if (str.contains('network') ||
      str.contains('socketexception') ||
      str.contains('connection refused') ||
      str.contains('failed host lookup')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (str.contains('timeout')) {
    return 'Request timed out. Please try again.';
  }
  if (str.contains('cancelled') || str.contains('google sign-in cancelled')) {
    return 'Sign-in was cancelled.';
  }

  // Generic fallback — don't show raw stack traces
  if (kDebugMode) return 'Error: $e';
  return 'Something went wrong. Please try again.';
}

/// Shows a styled error snackbar at the bottom of the screen.
void showErrorSnackBar(BuildContext context, Object error) {
  final msg = friendlyError(error);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFD93025),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Shows a success snackbar.
void showSuccessSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF31A24C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ),
  );
}
