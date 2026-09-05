import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

/// Daily Report tab — a quick way to report common issues (torn mayo
/// bag, out of gas, need more karne) to Owner, plus an optional
/// free-text message.
///
/// NOTE: In the backend phase, this should trigger a HIGH-PRIORITY
/// push notification (Firebase Cloud Messaging) to Owner's phone, even
/// if their screen is locked or the app is backgrounded.
class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  bool _mayoTorn = false;
  bool _gasEmpty = false;
  bool _needMoreMeat = false;
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _mayoTorn ||
      _gasEmpty ||
      _needMoreMeat ||
      _messageController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _mayoTorn = false;
      _gasEmpty = false;
      _needMoreMeat = false;
      _messageController.clear();
    });

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: const Text(
          "Your report has been sent — the Owner's phone will be "
          'alerted right away.',
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Daily Report',
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StaffCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Quick Report',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Select an issue below, or write your own message.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _checklistTile(
              icon: CupertinoIcons.exclamationmark_bubble_fill,
              label: 'The mayo we brought got punctured',
              value: _mayoTorn,
              onChanged: (v) => setState(() => _mayoTorn = v),
            ),
            _checklistTile(
              icon: CupertinoIcons.flame_fill,
              label: "We're out of gas (LPG)",
              value: _gasEmpty,
              onChanged: (v) => setState(() => _gasEmpty = v),
            ),
            _checklistTile(
              icon: CupertinoIcons.cube_box_fill,
              label: 'Need additional Karne (meat)',
              value: _needMoreMeat,
              onChanged: (v) => setState(() => _needMoreMeat = v),
            ),
            const SizedBox(height: 18),
            const StaffSectionHeader(
              label: 'Additional Message (optional)',
              icon: CupertinoIcons.chat_bubble_text_fill,
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _messageController,
              placeholder: 'Type the details here...',
              maxLines: 5,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              placeholderStyle: const TextStyle(color: AppColors.textSecondary),
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 22),
            StaffButton(
              label: _isSubmitting ? 'Sending...' : 'Send to Owner',
              icon: _isSubmitting ? null : CupertinoIcons.paperplane_fill,
              onPressed: _canSubmit && !_isSubmitting ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklistTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StaffCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        highlighted: value,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : AppColors.pastelBrown.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
            ),
            CupertinoSwitch(
              value: value,
              activeTrackColor: AppColors.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
