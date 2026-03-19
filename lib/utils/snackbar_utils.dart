import 'package:flutter/material.dart';

class SnackbarUtils {
  /// Shows a success snackbar with an icon.
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.green.shade800,
      icon: Icons.check_circle_outline,
    );
  }

  /// Shows an error snackbar with a friendly message and an icon.
  static void showError(BuildContext context, dynamic error) {
    final friendlyMessage = _mapErrorToFriendlyMessage(error);
    _showSnackBar(
      context,
      friendlyMessage,
      backgroundColor: Colors.red.shade800,
      icon: Icons.error_outline,
    );
  }

  /// Shows an info snackbar with an icon.
  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.blue.shade800,
      icon: Icons.info_outline,
    );
  }

  /// Shows a progressive snackbar that updates in real-time.
  static void showLoadingWithProgress(
    BuildContext context,
    String message,
    Stream<double> progressStream,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: StreamBuilder<double>(
          stream: progressStream,
          initialData: 0.0,
          builder: (context, snapshot) {
            final progress = snapshot.data ?? 0.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.blueGrey.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(minutes: 5), // Keep open until finished
      ),
    );
  }

  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static String _mapErrorToFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred.';
    
    final errorStr = error.toString().toLowerCase();

    // TMDB / General Network Errors
    if (errorStr.contains('failed to load data from tmdb')) {
      return 'Could not reach movie database. Please check your internet connection.';
    }
    if (errorStr.contains('socketexception') || errorStr.contains('httpexception')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Firebase Auth Errors
    if (errorStr.contains('user-not-found')) {
      return 'No account found with this email.';
    }
    if (errorStr.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    }
    if (errorStr.contains('network-request-failed') ||
        errorStr.contains('network error') ||
        errorStr.contains('timeout')) {
      return 'Network connection issue. Please check your internet and try again.';
    }
    if (errorStr.contains('sign in aborted')) {
      return 'Sign in was cancelled.';
    }
    if (errorStr.contains('requires-recent-login')) {
      return 'For security, please sign out and back in before deleting your account.';
    }

    // Cloudinary / Upload Errors
    if (errorStr.contains('upload failed')) {
      return 'Failed to upload video. Please try again.';
    }
    if (errorStr.contains('not configured')) {
      return 'Service is temporarily unavailable. Please contact support.';
    }

    // Default Fallback
    if (errorStr.startsWith('exception: ')) {
      return error.toString().replaceFirst('exception: ', '');
    }

    // If it's a reasonably long string, it's likely a descriptive error already
    if (error is String && error.length > 10) {
      return error;
    }

    return 'Something went wrong. Please try again later.';
  }
}
