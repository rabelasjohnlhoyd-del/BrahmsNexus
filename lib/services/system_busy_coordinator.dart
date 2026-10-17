import 'dart:async';
import 'package:flutter/foundation.dart';

/// Centralized coordinator for global system-wide busy/processing state.
///
/// When [isBusy] is true:
/// - Admin Web Shell: Sidebar, TopBar, Drawer, and Messenger Dock absorb all pointers.
/// - Mobile Shells (Staff, Driver, Production): Bottom navigation bars absorb all pointers.
///
/// This prevents any navigation or button clicks anywhere in the outer shells
/// while an operation is processing.
class SystemBusyCoordinator {
  const SystemBusyCoordinator._();

  static final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);
  static int _activeProcesses = 0;

  static void setBusy(bool busy) {
    if (busy) {
      _activeProcesses++;
      if (!isBusy.value) {
        isBusy.value = true;
      }
    } else {
      if (_activeProcesses > 0) _activeProcesses--;
      if (_activeProcesses == 0 && isBusy.value) {
        isBusy.value = false;
      }
    }
  }

  /// Executes an asynchronous operation while guaranteeing that [isBusy]
  /// is true from start to finish.
  static Future<T> run<T>(Future<T> Function() action) async {
    setBusy(true);
    try {
      return await action();
    } finally {
      setBusy(false);
    }
  }

  /// Emergency reset if ever needed.
  static void reset() {
    _activeProcesses = 0;
    isBusy.value = false;
  }
}
