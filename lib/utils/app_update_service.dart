import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  /// Check for app updates when app opens.
  ///
  /// - If **immediate** update is allowed  → Play Store forced update screen.
  /// - If only **flexible** update is allowed → show a custom popup dialog
  ///   so the user can choose to update now or later.
  ///
  /// Pass a [context] to enable the flexible-update popup.
  /// Safe to call without context — flexible popup is simply skipped.
  static Future<void> checkForUpdate({BuildContext? context}) async {
    try {
      // in_app_update only works on Android / Play Store builds
      if (defaultTargetPlatform != TargetPlatform.android) {
        debugPrint('⚠️ In-app updates only supported on Android');
        return;
      }

      debugPrint('🔍 Checking for app updates...');

      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      debugPrint('📊 Update availability : ${info.updateAvailability}');
      debugPrint('📊 Immediate allowed   : ${info.immediateUpdateAllowed}');
      debugPrint('📊 Flexible allowed    : ${info.flexibleUpdateAllowed}');
      debugPrint('📊 Available version   : ${info.availableVersionCode}');

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        debugPrint('✅ App is up to date');
        return;
      }

      // ── Immediate update (forced) ────────────────────────────────────────
      if (info.immediateUpdateAllowed) {
        debugPrint('🚀 Starting immediate update...');
        await InAppUpdate.performImmediateUpdate();
        debugPrint('✅ Immediate update completed');
        return;
      }

      // ── Flexible update (optional popup) ────────────────────────────────
      if (info.flexibleUpdateAllowed && context != null && context.mounted) {
        debugPrint('📦 Flexible update available — showing popup');
        await _showFlexibleUpdateDialog(context);
        return;
      }

      debugPrint('⚠️ Update available but neither immediate nor flexible is allowed');
    } catch (e) {
      // Never block app launch because of an update-check failure
      debugPrint('❌ Error checking for updates: $e');
    }
  }

  /// Shows a dialog asking the user to update.
  /// Starts the flexible update download if they agree.
  static Future<void> _showFlexibleUpdateDialog(BuildContext context) async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.system_update_alt,
                  color: Color(0xFF4CAF50), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Update Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'A new version of the app is available on the Play Store.\n\n'
          'Update now to get the latest features and improvements.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Later',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Update Now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (shouldUpdate == true) {
      try {
        debugPrint('📦 Starting flexible update download...');
        await InAppUpdate.startFlexibleUpdate();

        // After download completes, prompt to install
        await InAppUpdate.completeFlexibleUpdate();
        debugPrint('✅ Flexible update installed');
      } catch (e) {
        debugPrint('❌ Flexible update error: $e');
      }
    } else {
      debugPrint('ℹ️ User chose to update later');
    }
  }

  /// Call on app resume to complete any pending flexible update that was
  /// downloaded in the background.
  static Future<void> completeFlexibleUpdate() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return;
      debugPrint('🔍 Checking for pending flexible updates...');
      await InAppUpdate.completeFlexibleUpdate();
      debugPrint('✅ Pending flexible update completed (if any)');
    } catch (e) {
      debugPrint('❌ Error completing flexible update: $e');
    }
  }
}
