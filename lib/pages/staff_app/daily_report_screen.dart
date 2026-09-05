import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_top_actions.dart';

/// Daily Report tab — mabilis na paraan para mag-report ng mga
/// karaniwang isyu (butas na mayo, ubos na gasul, kailangan ng dagdag
/// na karne) papunta kay Owner, plus optional na free-text message.
///
/// NOTE: Sa backend phase, dapat mag-trigger ito ng HIGH-PRIORITY push
/// notification (Firebase Cloud Messaging) papunta sa phone ni Owner,
/// kahit naka-lock ang screen o naka-background ang app niya.
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
          'Naipadala na ang report — mag-a-alert agad ang phone ni Owner.',
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Daily Report'),
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Mabilis na Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Piliin ang isyu, o magsulat ng sariling message sa ibaba.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _checklistTile(
              icon: CupertinoIcons.exclamationmark_bubble_fill,
              label: 'Nabutas ang mayo na dala namin',
              value: _mayoTorn,
              onChanged: (v) => setState(() => _mayoTorn = v),
            ),
            _checklistTile(
              icon: CupertinoIcons.flame_fill,
              label: 'Ubos na ang gasul',
              value: _gasEmpty,
              onChanged: (v) => setState(() => _gasEmpty = v),
            ),
            _checklistTile(
              icon: CupertinoIcons.cube_box_fill,
              label: 'Kailangan ng dagdag na karne',
              value: _needMoreMeat,
              onChanged: (v) => setState(() => _needMoreMeat = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Karagdagang Mensahe (opsyonal)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _messageController,
              placeholder: 'I-type dito ang detalye...',
              maxLines: 5,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
              onPressed: _canSubmit && !_isSubmitting ? _submit : null,
              child: Text(_isSubmitting ? 'Sending...' : 'Send to Owner'),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
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
    );
  }
}
