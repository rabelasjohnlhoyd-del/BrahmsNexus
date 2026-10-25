import 'package:flutter/material.dart';

/// Shows a responsive, properly constrained Terms of Service and Privacy Policy dialog.
///
/// Designed with standard max-width constraints (640px) so it renders as a
/// dignified, centered modal on Web/Desktop rather than stretching edge-to-edge.
void showTermsDialog(BuildContext context, {bool isReviewOnly = false}) {
  showDialog<void>(
    context: context,
    barrierDismissible: isReviewOnly,
    builder: (context) => _TermsAndConditionsDialog(isReviewOnly: isReviewOnly),
  );
}

class _TermsAndConditionsDialog extends StatelessWidget {
  final bool isReviewOnly;
  const _TermsAndConditionsDialog({this.isReviewOnly = false});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.82;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 640,
        ),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.hardEdge,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  color: const Color(0xFF8B4513),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Terms & Privacy Policy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (isReviewOnly)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Effective Date: October 2026',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF7A6556),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildParagraph(
                          'These Terms of Service and Privacy Policy govern the operational use of the Brahms Nexus platform for Brahms Sisig & Bagnet. All authorized personnel—including Store Owners, System Administrators, Branch Cooks, Meat Cutters, and Delivery Drivers—must comply with these operational guidelines.',
                        ),
                        const SizedBox(height: 10),

                        // Section 1
                        _buildSectionHeading('1. Authorized Operational Scope'),
                        _buildParagraph(
                          'Brahms Nexus is developed strictly for Brahms Sisig & Bagnet business operations. Authorized activities are limited to:',
                        ),
                        _buildBulletItem('Central Commissary meat portioning, raw pork batching, and yield auditing'),
                        _buildBulletItem('Inter-branch stock transfer manifest generation and driver delivery dispatches'),
                        _buildBulletItem('Special Bilao customer order recording, payment verification, and fulfillment'),
                        _buildBulletItem('Branch daily sales summaries, portion consumption, and stock level logging'),
                        _buildBulletItem('Staff shift attendance monitoring, scheduling, and operational announcements'),

                        // Section 2
                        _buildSectionHeading('2. Employee Accountability & Meat Inventory Integrity'),
                        _buildParagraph(
                          'Personnel and branch accounts are directly accountable for the accuracy of meat allocations recorded under their credentials. Deliberate misrepresentation of meat weights (sisig/bagnet portions), unauthorized stock transfers, or fraudulent confirmation of delivery manifests constitutes serious misconduct.',
                        ),

                        // Section 3
                        _buildSectionHeading('3. RFID Attendance & Credential Security'),
                        _buildParagraph(
                          'Your login credentials and designated RFID card serve as your official operational signature. Tapping an RFID card on behalf of another employee ("buddy punching"), sharing account credentials, or accessing administrative functions without authorization is strictly prohibited.',
                        ),

                        // Section 4
                        _buildSectionHeading('4. Data Privacy Policy (RA 10173 Compliance)'),
                        _buildParagraph(
                          'In adherence to the Philippine Data Privacy Act of 2012 (RA 10173), Brahms Sisig & Bagnet protects all collected operational and customer information:',
                        ),
                        _buildBulletItem(
                          'Employee full name, phone number, assigned branch role, RFID attendance logs, delivery route timestamps, and proof-of-delivery photos.',
                          boldPrefix: 'Data Collected: ',
                        ),
                        _buildBulletItem(
                          'Internal shift scheduling, meat inventory reconciliation, delivery tracking, and administrative store audits.',
                          boldPrefix: 'Operational Purpose: ',
                        ),
                        _buildBulletItem(
                          'Operational records are secured within encrypted cloud storage, accessible solely by authorized management, and never sold or disclosed to external parties.',
                          boldPrefix: 'Confidentiality: ',
                        ),

                        // Section 5
                        _buildSectionHeading('5. Camera Permissions & Delivery Documentation'),
                        _buildParagraph(
                          'The mobile application accesses the device camera solely for capturing legitimate operational records: physical stock transfer handovers, damaged shipment documentation, and customer payment receipts.',
                        ),

                        // Section 6
                        _buildSectionHeading('6. Operational Push Notifications'),
                        _buildParagraph(
                          'Real-time push notifications are transmitted to deliver critical business alerts, including new delivery assignments, stock replenishment requests, and owner announcements. Staff must ensure app notifications remain active while on shift.',
                        ),

                        // Section 7
                        _buildSectionHeading('7. Account Suspension & Administrative Oversight'),
                        _buildParagraph(
                          'Store management reserves the right to audit activity logs, restrict permissions, or deactivate system access upon investigation of operational violations or separation of employment.',
                        ),

                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFE8DED3)),
                        const SizedBox(height: 8),
                        Text(
                          isReviewOnly
                              ? 'This operational policy is maintained and enforced by Brahms Sisig & Bagnet management.'
                              : 'By tapping "I Agree", you confirm that you have read and agree to comply with these Terms of Service and Privacy Policy.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF7A6556),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Action button
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
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
                      child: Text(
                        isReviewOnly ? 'Close' : 'I Agree',
                        style: const TextStyle(
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
          ),
        ),
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
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF3B2418),
          height: 1.55,
        ),
      ),
    );
  }

  Widget _buildBulletItem(String text, {String? boldPrefix}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 5, color: Color(0xFF8B4513)),
          ),
          Expanded(
            child: boldPrefix != null
                ? RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF3B2418),
                        height: 1.55,
                      ),
                      children: [
                        TextSpan(
                          text: boldPrefix,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B2418),
                          ),
                        ),
                        TextSpan(text: text),
                      ],
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF3B2418),
                      height: 1.55,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
