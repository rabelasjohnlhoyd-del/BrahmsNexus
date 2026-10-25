import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/permission_disclosure_dialog.dart';

/// Central coordinator for mobile device permission onboarding and security
/// disclosures in Brahms Nexus.
class PermissionService {
  const PermissionService._();

  /// Checks if the mobile device has previously acknowledged the operational
  /// permissions disclosure. If not, displays the formal disclosure dialog.
  static Future<void> checkAndShowOnboarding(BuildContext context) async {
    if (kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen =
          prefs.getBool(PermissionDisclosureDialog.prefKey) ?? false;
      if (hasSeen) return;

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PermissionDisclosureDialog(),
      );
    } catch (_) {
      // Graceful failure: do not block app execution on preference errors
    }
  }

  /// Manually launches the permissions disclosure dialog (e.g. from Profile or Settings).
  static Future<void> showDisclosureManually(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const PermissionDisclosureDialog(),
    );
  }
}
