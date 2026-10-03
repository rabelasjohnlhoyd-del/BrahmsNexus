import 'package:flutter/material.dart';

/// Shows a full-screen Terms and Conditions dialog.
///
/// The dialog is not dismissible by tapping outside (barrierDismissible: false).
/// Users must scroll through the content and tap the Accept button to close.
void showTermsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _TermsAndConditionsDialog(),
  );
}

class _TermsAndConditionsDialog extends StatelessWidget {
  const _TermsAndConditionsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFF8B4513),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Terms and Conditions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Effective Date
                  const Text(
                    'Effective Date: October 2026',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF7A6556),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'These Terms and Conditions govern the use of the BrahmsNexus employee management system operated by Brahms Sisig & Bagnet. By registering, you agree to be bound by these terms.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF3B2418), height: 1.45),
                  ),
                  const SizedBox(height: 16),

                  // Section 1
                  _buildSectionHeading('1. Acceptance of Terms'),
                  _buildSectionBody(
                    'By completing the registration process and creating an account, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions. If you do not agree, you must not register or use the system.',
                  ),

                  // Section 2
                  _buildSectionHeading('2. Employee Eligibility'),
                  _buildSectionBody(
                    'To register, you must:\n'
                    '• Be at least 18 years of age.\n'
                    '• Provide accurate, current, and complete personal information.\n'
                    '• Be a current or prospective employee of Brahms Sisig & Bagnet.\n\n'
                    'Providing false or misleading information is grounds for immediate rejection of your application or termination of your account.',
                  ),

                  // Section 3
                  _buildSectionHeading('3. Use of the System'),
                  _buildSectionBody(
                    'BrahmsNexus is intended exclusively for business operations, including but not limited to:\n'
                    '• Inventory management\n'
                    '• Sales recording and tracking\n'
                    '• Delivery coordination\n'
                    '• Employee attendance monitoring\n\n'
                    'You must not share your login credentials with any other person. Unauthorized sharing, misuse, or access of the system is strictly prohibited and subject to disciplinary action.',
                  ),

                  // Section 4
                  _buildSectionHeading('4. Data Privacy'),
                  _buildSectionBody(
                    'In the course of registration and system use, we collect the following personal data:\n'
                    '• Full name\n'
                    '• Contact number\n'
                    '• Home address\n'
                    '• Role and position\n\n'
                    'This information is used solely for internal business operations and is not shared with third parties without your explicit consent, except as required by law.',
                  ),

                  // Section 5
                  _buildSectionHeading('5. Attendance & RFID'),
                  _buildSectionBody(
                    'Your assigned RFID card is your official identification for time and attendance tracking. Each tap of your RFID card constitutes an official time record.\n\n'
                    'Falsification of attendance records — including but not limited to tapping another employee\'s RFID card or allowing others to tap yours — is considered a serious violation of company policy and may result in immediate disciplinary action or termination.',
                  ),

                  // Section 6
                  _buildSectionHeading('6. Accountability'),
                  _buildSectionBody(
                    'You are fully accountable for all actions performed and recorded under your account. This includes transactions, attendance entries, inventory adjustments, and any other system activity logged under your credentials. Do not leave your session unattended.',
                  ),

                  // Section 7
                  _buildSectionHeading('7. Termination of Access'),
                  _buildSectionBody(
                    'Management reserves the right to suspend, restrict, or permanently revoke your account access at any time, with or without prior notice, for reasons including but not limited to:\n'
                    '• Violation of these Terms and Conditions\n'
                    '• End of employment\n'
                    '• Unauthorized or suspicious system activity',
                  ),

                  // Section 8
                  _buildSectionHeading('8. Contact'),
                  _buildSectionBody(
                    'For questions, concerns, or disputes regarding these Terms and Conditions, please contact the business owner or system administrator directly.',
                  ),

                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFE8DED3)),
                  const SizedBox(height: 8),
                  const Text(
                    'By tapping "I Agree" and completing registration, you confirm that you have read and understood these Terms and Conditions.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF7A6556),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Accept button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'I Agree',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 5),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8B4513),
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String content) {
    return Text(
      content,
      style: const TextStyle(
        fontSize: 12.5,
        color: Color(0xFF3B2418),
        height: 1.5,
      ),
    );
  }
}
