import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/daily_report.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

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

  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';
  StreamSubscription<List<DailyReport>>? _reportsSub;
  final List<DailyReport> _myRecentReports = [];

  @override
  void initState() {
    super.initState();
    _setupBranch();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
    _reportsSub = FirestoreService.watchDailyReports().listen((allReports) {
      if (mounted) {
        final mine = allReports.where((r) =>
            r.branchId == _currentBranchId ||
            r.employeeId == AuthService.currentUserId ||
            r.employeeName == AuthService.currentUsername).toList();
        setState(() {
          _myRecentReports
            ..clear()
            ..addAll(mine);
        });
      }
    });
  }

  void _onAssignmentChanged() {
    if (mounted) _setupBranch();
  }

  void _setupBranch() {
    final assignedBranchName = AssignmentService.getAssignedBranch(AuthService.currentUsername);
    Branch? matchedBranch;
    if (assignedBranchName.isNotEmpty) {
      for (final b in kSampleBranches) {
        if (b.fullName.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            b.name.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            assignedBranchName.toLowerCase().contains(b.name.toLowerCase())) {
          matchedBranch = b;
          break;
        }
      }
    }
    matchedBranch ??= kSampleBranches.first;
    setState(() {
      _currentBranchId = matchedBranch!.id;
      _currentBranchName = matchedBranch.fullName;
    });
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentChanged);
    _reportsSub?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _mayoTorn ||
      _gasEmpty ||
      _needMoreMeat ||
      _messageController.text.trim().isNotEmpty;

  Future<void> _confirmSubmit() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Send This Report?'),
        content: const Text("The Owner's phone will be alerted right away once you send this."),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    _submit();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final parts = <String>[];
    if (_mayoTorn) parts.add('The mayo we brought got punctured');
    if (_gasEmpty) parts.add("We're out of gas (LPG)");
    if (_needMoreMeat) parts.add('Need additional Karne (meat)');
    final msg = _messageController.text.trim();
    if (msg.isNotEmpty) {
      parts.add(msg);
    }
    final content = parts.isEmpty ? 'Normal operational report.' : parts.join('\n');

    final hasIncident = _mayoTorn || _gasEmpty || _needMoreMeat;
    final status = hasIncident
        ? ReportSubmissionStatus.incomplete
        : ReportSubmissionStatus.submitted;

    final empName = AuthService.currentUser?.fullName.isNotEmpty == true
        ? AuthService.currentUser!.fullName
        : AuthService.currentUsername;

    final report = DailyReport(
      id: '',
      employeeId: AuthService.currentUserId,
      employeeName: empName,
      branchId: _currentBranchId,
      branchName: _currentBranchName,
      date: DateTime.now(),
      content: content,
      status: status,
    );

    final success = await FirestoreService.submitDailyReport(report);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _mayoTorn = false;
      _gasEmpty = false;
      _needMoreMeat = false;
      _messageController.clear();
    });

    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(success ? 'Report Sent!' : 'Notice'),
        content: Text(success
            ? "Your report has been sent to the Owner and recorded in real-time."
            : "Report saved locally. Please check your internet connection."),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Daily Report',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StaffSectionHeader(
              label: 'Quick Report',
              icon: CupertinoIcons.exclamationmark_bubble_fill,
              subtitle: 'Select an issue below, or write your own message',
              large: true,
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
            
            // DYNAMIC BUTTON LOGIC
            if (_canSubmit)
              SizedBox(
                width: double.infinity,
                child: StaffButton(
                  key: const ValueKey('send_report_btn'),
                  label: _isSubmitting ? 'Sending...' : 'Send to Owner',
                  icon: _isSubmitting ? null : CupertinoIcons.paperplane_fill,
                  onPressed: _isSubmitting ? null : _confirmSubmit,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Note: Pakipili ang issue sa itaas o mag-type ng message para lumabas ang send button.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // RECENT SUBMISSIONS BY THIS STAFF/BRANCH
            if (_myRecentReports.isNotEmpty) ...[
              const SizedBox(height: 16),
              const StaffSectionHeader(
                label: 'Recently Submitted Reports',
                icon: CupertinoIcons.clock_fill,
                subtitle: 'Track your sent reports and Owner responses',
              ),
              const SizedBox(height: 12),
              for (final r in _myRecentReports.take(5)) ...[
                StaffCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${r.date.month}/${r.date.day}/${r.date.year}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (r.status == ReportSubmissionStatus.submitted
                                      ? AppColors.success
                                      : AppColors.warning)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r.status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: r.status == ReportSubmissionStatus.submitted
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(r.content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      if (r.ownerReply != null && r.ownerReply!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(CupertinoIcons.reply, size: 12, color: AppColors.accent),
                                  SizedBox(width: 6),
                                  Text(
                                    'OWNER RESPONSE',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.ownerReply!,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 30),
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
                borderRadius: BorderRadius.circular(12),
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
