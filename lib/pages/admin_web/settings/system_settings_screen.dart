import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../../../services/tutorial_service.dart';
import '../../../widgets/terms_and_conditions_dialog.dart';
import '../../../widgets/app_info_modals.dart';

/// Clean, professional, and fully functional System Settings & Operations Directory
/// screen for the Owner Web portal.
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(SystemSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. SYSTEM HELP & GUIDED TOURS ────────────────────────────
                _buildSectionHeader('System Help & Guided Tours'),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildActionRow(
                        icon: Icons.school_outlined,
                        title: 'Owner Interactive Guided Tour',
                        description:
                            'Replay the step-by-step interactive walkthrough explaining each operational module of the Admin Web portal.',
                        actionLabel: 'Replay Tour',
                        actionIcon: Icons.play_circle_outline_rounded,
                        onTap: () => _replayOwnerTour(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 2. LEGAL, COMPLIANCE & POLICIES ──────────────────────────
                _buildSectionHeader('Legal, Compliance & Operational Policies'),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildActionRow(
                        icon: Icons.gavel_rounded,
                        title: 'Terms of Service & Operational Guidelines',
                        description:
                            'Standard enterprise usage terms, employee accountability rules, and inventory management guidelines.',
                        actionLabel: 'View Terms',
                        actionIcon: Icons.visibility_outlined,
                        onTap: () => showTermsDialog(context, isReviewOnly: true),
                      ),
                      const Divider(height: 28),
                      _buildActionRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Data Privacy Policy (RA 10173 Compliance)',
                        description:
                            'Guidelines governing the lawful collection, processing, and protection of employee records and operational data.',
                        actionLabel: 'View Policy',
                        actionIcon: Icons.shield_outlined,
                        onTap: () => showTermsDialog(context, isReviewOnly: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 3. OPERATIONAL DIRECTORY & SUPPORT ───────────────────────
                _buildSectionHeader('Operational Support & Store Directory'),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildActionRow(
                        icon: Icons.support_agent_rounded,
                        title: 'Operational Support & Emergency Directory',
                        description:
                            'Emergency contacts for delivery logistics, commissary dispatch lines, and technical administration.',
                        actionLabel: 'Open Directory',
                        actionIcon: Icons.contact_phone_outlined,
                        onTap: () => showHelpAndSupportDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 4. ABOUT BRAHMS NEXUS ────────────────────────────────────
                _buildSectionHeader('About Brahms Nexus'),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildActionRow(
                        icon: Icons.info_outline_rounded,
                        title: 'Platform Information & Release Details',
                        description:
                            'Version 1.0.0 (Release Build 2026). Engineered specifically for Brahms Sisig & Bagnet multi-branch operations.',
                        actionLabel: 'View Details',
                        actionIcon: Icons.open_in_new_rounded,
                        onTap: () => showAboutBrahmsNexusDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1.1,
          color: AdminWebColors.accent,
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String description,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AdminWebColors.accent, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AdminWebColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(actionIcon, size: 16),
          label: Text(actionLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminWebColors.accent,
            side: const BorderSide(color: AdminWebColors.accent, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Future<void> _replayOwnerTour(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replay Guided Tour?'),
        content: const Text(
          'This will restart the interactive step-by-step guided tour explaining all modules of the Owner Web portal. Would you like to start now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Tour'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    await TutorialService.resetTutorial('owner_spotlight');
    shell?.showTutorial();
  }
}
