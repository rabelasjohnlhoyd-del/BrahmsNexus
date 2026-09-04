import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../theme/app_theme.dart';

/// Lalabas kapag ang account ay hindi pa [AccountStatus.approved].
/// - Pending: hintayin munang aprubahan ni Owner.
/// - Rejected: sabihin na hindi na-approve, at i-refer sa Owner.
class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key, required this.status});

  final AccountStatus status;

  bool get _isRejected => status == AccountStatus.rejected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (_isRejected ? AppColors.error : AppColors.warning)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRejected
                        ? Icons.cancel_outlined
                        : Icons.hourglass_top_rounded,
                    size: 48,
                    color: _isRejected ? AppColors.error : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isRejected
                      ? 'Hindi Na-approve ang Account'
                      : 'Naka-pending ang Account Mo',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRejected
                      ? 'Na-reject ng Owner/Admin ang registration mo. '
                          'Makipag-ugnayan sa kanya para sa detalye.'
                      : 'Hintayin munang aprubahan ng Owner/Admin ang '
                          'registration mo bago ka makapag-login.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Balik sa Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
