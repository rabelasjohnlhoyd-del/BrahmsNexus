import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shows a professional, standardized "About Brahms Nexus" information dialog.
void showAboutBrahmsNexusDialog(BuildContext context) {
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Column(
        children: const [
          Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF8B4513), size: 38),
          SizedBox(height: 8),
          Text(
            'About Brahms Nexus',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B2418),
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Version 1.0.0 (Release Build)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7A6556),
            ),
          ),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: const Text(
          'Brahms Nexus is an enterprise operations management platform engineered for Brahms Sisig & Bagnet.\n\n'
          'It coordinates central commissary meat processing, daily inventory portioning, stock dispatch logistics, and multi-branch communication across owners, cooks, meat cutters, and delivery drivers.\n\n'
          '© 2026 Brahms Sisig & Bagnet. All rights reserved.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF4A3428),
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          isDefaultAction: true,
          child: const Text(
            'Close',
            style: TextStyle(
              color: Color(0xFF8B4513),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shows a standardized "Help & Support" guidance and contact modal.
void showHelpAndSupportDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF8B4513),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.question_circle_fill, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Help & Operational Support',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Need assistance with your daily shift, delivery route, or inventory tasks? Refer to the operational channels below:',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF3B2418), height: 1.45),
                      ),
                      const SizedBox(height: 14),

                      _buildSupportSection(
                        icon: CupertinoIcons.phone_fill,
                        title: 'Management & Emergency Dispatch',
                        content: 'For urgent route adjustments, customer bilao address inquiries, or emergency stock replenishment:\n'
                            '• Store Administrator: 0912-345-6789\n'
                            '• Commissary Dispatch: Direct Store Line',
                      ),
                      const SizedBox(height: 12),

                      _buildSupportSection(
                        icon: CupertinoIcons.cube_box_fill,
                        title: 'Inventory & Stock Discrepancies',
                        content: '• Branch Cooks: If delivered stock does not match the transfer manifest, record the variance immediately in the Daily Report before confirming.\n'
                            '• Cutters: Verify portioning batch weights against central commissary allocation before submitting shift records.',
                      ),
                      const SizedBox(height: 12),

                      _buildSupportSection(
                        icon: CupertinoIcons.bell_fill,
                        title: 'Push Notification Alerts',
                        content: 'If alerts for new announcements or bilao orders do not sound when the app is closed, verify in phone settings that App Battery Usage is set to "Unrestricted" and notification banners are allowed.',
                      ),
                      const SizedBox(height: 12),

                      _buildSupportSection(
                        icon: CupertinoIcons.wrench_fill,
                        title: 'Technical & Account Inquiries',
                        content: 'For forgotten login credentials, RFID card re-linking, or mobile app bugs, submit an issue report through your designated Branch Manager.',
                      ),
                    ],
                  ),
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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

Widget _buildSupportSection({
  required IconData icon,
  required String title,
  required String content,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF6F0),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE8DED3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF8B4513), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D2E0C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3B2418),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
