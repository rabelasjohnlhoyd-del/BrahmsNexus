import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../theme/app_theme.dart';

/// Shown when the account is not yet [AccountStatus.approved].
/// - Pending: waiting on Owner/Admin approval.
/// - Rejected: registration was declined; refer the person to the
///   Owner/Admin for details.
class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key, required this.status});

  final AccountStatus status;

  bool get _isRejected => status == AccountStatus.rejected;

  Color get _statusColor => _isRejected ? AppColors.error : AppColors.warning;

  IconData get _statusIcon =>
      _isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded;

  String get _title =>
      _isRejected ? 'Account Not Approved' : 'Your Account Is Pending';

  String get _message => _isRejected
      ? 'Your registration was declined by the Owner/Admin. Please '
          'get in touch with them for more details.'
      : 'Your registration is waiting for approval from the '
          'Owner/Admin. You\'ll be able to log in as soon as it\'s '
          'approved.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: _statusColor.withValues(alpha: 0.18),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(_statusIcon, size: 44, color: _statusColor),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Back to Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
