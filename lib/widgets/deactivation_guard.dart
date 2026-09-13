import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/auth/login_screen.dart';
import '../services/auth_service.dart';

/// Wraps any staff/driver/production shell and listens to the
/// `deactivated_staff/{username}` Firestore document in real-time.
///
/// If the Owner deactivates OR archives the logged-in staff's account,
/// this widget automatically signs them out and redirects to [LoginScreen]
/// — even while the staff is actively using the app on another device.
///
/// Usage: Wrap the root widget of each staff/driver/production shell with
/// this widget in its build method.
class DeactivationGuard extends StatefulWidget {
  const DeactivationGuard({super.key, required this.child});

  final Widget child;

  @override
  State<DeactivationGuard> createState() => _DeactivationGuardState();
}

class _DeactivationGuardState extends State<DeactivationGuard> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _isHandlingLogout = false;

  @override
  void initState() {
    super.initState();
    _startWatching();
  }

  void _startWatching() {
    final username = AuthService.currentAppUser?.username;
    if (username == null || username.isEmpty) return;

    final usernameKey = username.trim().toLowerCase();

    // Watch the deactivated_staff/{username} document in real-time.
    // This fires immediately on open AND whenever the document changes.
    _sub = FirebaseFirestore.instance
        .collection('deactivated_staff')
        .doc(usernameKey)
        .snapshots()
        .listen((snap) {
      if (!mounted || _isHandlingLogout) return;

      // If the document exists and isDeactivated is true → force logout
      if (snap.exists) {
        final isDeactivated = snap.data()?['isDeactivated'] as bool? ?? false;
        if (isDeactivated) {
          _forceLogout();
        }
      }
    });
  }

  Future<void> _forceLogout() async {
    if (_isHandlingLogout) return;
    _isHandlingLogout = true;

    // Cancel the watcher first so it doesn't fire again during logout
    await _sub?.cancel();
    _sub = null;

    // Sign out from Firebase Auth
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // Clear in-memory current user
    AuthService.currentAppUser = null;

    if (!mounted) return;

    // Show a brief notice then redirect to login screen
    _showLoggedOutDialog();
  }

  void _showLoggedOutDialog() {
    // Use a post-frame callback to avoid calling navigator during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Account Deactivated'),
          content: const Text(
            'Ang iyong account ay na-DEACTIVATE ng Owner. '
            'Makipag-ugnayan sa Owner para ma-reactivate ang iyong account.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Navigate to login, clearing the entire navigation stack
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
