import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/auth/login_screen.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_cache.dart';
import '../services/supabase_service.dart';

/// Wraps any staff/driver/production shell and listens to the
/// `deactivated_staff/{username}` Firestore document and Supabase profile in real-time.
///
/// If the Owner deactivates OR archives the logged-in staff's account, or puts them on
/// Rest Day, this widget automatically signs them out and redirects to [LoginScreen]
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _assignmentSub;
  StreamSubscription<List<dynamic>>? _supabaseSub;
  VoidCallback? _assignmentListener;
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

    // 1) Watch Supabase profiles in real-time
    _supabaseSub = SupabaseService.watchStaffProfiles().listen((staffList) {
      if (!mounted || _isHandlingLogout) return;
      for (final s in staffList) {
        if (s.username.toLowerCase() == usernameKey || s.id.toLowerCase() == usernameKey) {
          if (!s.isActive || s.isArchived) {
            _forceLogout(isRestDay: false);
            return;
          }
          // Production staff are exempt from rest day kick-out.
          if (s.isRestDay && !AuthService.isProductionPosition(s.position)) {
            _forceLogout(isRestDay: true);
            return;
          }
        }
      }
    });

    // 2) Listen to AssignmentService change notifier
    _assignmentListener = () {
      if (!mounted || _isHandlingLogout) return;
      // Production staff are never part of branch assignments — skip rest day check.
      final pos = AuthService.currentAppUser?.position ?? '';
      if (AuthService.isProductionPosition(pos)) return;
      if (AssignmentService.isRestDay(usernameKey)) {
        _forceLogout(isRestDay: true);
      }
    };
    AssignmentService.changeNotifier.addListener(_assignmentListener!);

    // 3) Watch the deactivated_staff/{username} document in real-time (Firestore).
    _sub = FirestoreListenCache.doc(
      'deactivated_staff:$usernameKey',
      FirebaseFirestore.instance
          .collection('deactivated_staff')
          .doc(usernameKey),
    ).listen((snap) {
      if (!mounted || _isHandlingLogout) return;

      if (snap.exists) {
        final isDeactivated = snap.data()?['isDeactivated'] as bool? ?? false;
        if (isDeactivated) {
          _forceLogout(isRestDay: false);
        }
      }
    });

    // 4) Watch the staff_assignments/{username} document in real-time for Rest Day.
    _assignmentSub = FirestoreListenCache.doc(
      'staff_assignments:$usernameKey',
      FirebaseFirestore.instance
          .collection('staff_assignments')
          .doc(usernameKey),
    ).listen((snap) {
      if (!mounted || _isHandlingLogout) return;

      if (snap.exists) {
        final isRestDay = snap.data()?['isRestDay'] as bool? ?? (snap.data()?['workStatus'] == 'restDay');
        if (isRestDay) {
          _forceLogout(isRestDay: true);
        }
      }
    });
  }

  Future<void> _forceLogout({bool isRestDay = false}) async {
    if (_isHandlingLogout) return;
    _isHandlingLogout = true;

    // Cancel watchers first
    if (_assignmentListener != null) {
      AssignmentService.changeNotifier.removeListener(_assignmentListener!);
      _assignmentListener = null;
    }
    await _supabaseSub?.cancel();
    _supabaseSub = null;
    await _sub?.cancel();
    _sub = null;
    await _assignmentSub?.cancel();
    _assignmentSub = null;

    // Sign out from Firebase Auth
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // Clear in-memory current user
    AuthService.currentAppUser = null;

    if (!mounted) return;

    // Show notice then redirect to login screen
    _showLoggedOutDialog(isRestDay: isRestDay);
  }

  void _showLoggedOutDialog({bool isRestDay = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(isRestDay ? 'Naka-Rest Day Ka Ngayon' : 'Account Deactivated'),
          content: Text(
            isRestDay
                ? 'Naka-REST DAY po kayo ngayon ayon sa iskedyul ng Owner. '
                    'Mag-log out muna ang app upang makapagpahinga kayo. Salamat!'
                : 'Ang iyong account ay na-DEACTIVATE ng Owner. '
                    'Makipag-ugnayan sa Owner para ma-reactivate ang iyong account.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
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
    if (_assignmentListener != null) {
      AssignmentService.changeNotifier.removeListener(_assignmentListener!);
      _assignmentListener = null;
    }
    _supabaseSub?.cancel();
    _sub?.cancel();
    _assignmentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
