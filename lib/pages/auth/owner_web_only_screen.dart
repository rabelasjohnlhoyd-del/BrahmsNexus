import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

/// Lalabas kapag nag-login bilang Owner mula sa NAKA-INSTALL na app
/// (hindi browser). Hindi dapat dito bumukas ang Admin Dashboard mismo
/// sa loob ng app — ang tanging paraan para maka-access ng admin side
/// ay sa pagbukas ng website sa isang browser (Chrome, Safari, atbp.).
class OwnerWebOnlyScreen extends StatelessWidget {
  const OwnerWebOnlyScreen({super.key});

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
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Admin ay Web-Only',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Buksan ang Brahms Nexus website sa browser ng iyong '
                  'phone (Chrome, Safari, atbp.) para ma-access ang Admin '
                  'Dashboard. Ang app na ito ay para lang sa Staff at '
                  'Driver accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
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
