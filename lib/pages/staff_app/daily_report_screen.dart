import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../models/branch.dart';
import '../../models/daily_report.dart';
import '../auth/mock_accounts.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/rate_limiter.dart';
import '../../services/tutorial_service.dart';
import '../../theme/app_theme.dart';
import '../../services/input_validators.dart';
import '../../widgets/app_pagination_bar.dart';
import '../../widgets/guided_tour_overlay.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  static final GlobalKey<DailyReportScreenState> globalKey = GlobalKey();

  @override
  State<DailyReportScreen> createState() => DailyReportScreenState();
}

class DailyReportScreenState extends State<DailyReportScreen> {
  final GlobalKey _quickReportKey = GlobalKey();
  final GlobalKey _sendButtonKey = GlobalKey();
  final GlobalKey _recentReportsKey = GlobalKey();
  bool _mayoTorn = false;
  bool _gasEmpty = false;
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';
  StreamSubscription<List<DailyReport>>? _reportsSub;
  final List<DailyReport> _myRecentReports = [];
  int _currentPage = 0;
  static const int _pageSize = 5;

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
    String assignedBranchName = AssignmentService.getAssignedBranch(AuthService.currentUsername);
    if (assignedBranchName.isEmpty) {
      final mock = kMockAccounts[AuthService.currentUsername.toLowerCase()];
      if (mock != null && mock.branchName.isNotEmpty) {
        assignedBranchName = mock.branchName;
      }
    }
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

  bool get _canSubmit {
    final hasIssue = _mayoTorn || _gasEmpty;
    final msg = _messageController.text.trim();
    if (!hasIssue && msg.isEmpty) return false;
    if (msg.isNotEmpty) {
      final res = InputValidators.validateMessage(
        msg,
        fieldName: 'Additional Message',
        required: !hasIssue,
        minLength: 10,
        maxLength: 300,
      );
      if (!res.isValid) return false;
    }
    return true;
  }

  Future<void> _confirmSubmit() async {
    final hasIssue = _mayoTorn || _gasEmpty;
    final msg = _messageController.text.trim();
    if (!hasIssue && msg.isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Nothing to Report'),
          content: const Text('Please check at least one issue or type a message before sending.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (msg.isNotEmpty) {
      final res = InputValidators.validateMessage(
        msg,
        fieldName: 'Additional Message',
        required: !hasIssue,
        minLength: 10,
        maxLength: 300,
      );
      if (!res.isValid) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Invalid Message'),
            content: Text(res.errorMessage ?? 'Please enter a valid message.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

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
    final reportKey = 'daily_report_${AuthService.currentUserId}_$_currentBranchId';
    if (!RateLimiter.tryAction(key: reportKey, cooldown: const Duration(minutes: 15))) {
      final secs = RateLimiter.remainingCooldownSeconds(reportKey);
      final mins = (secs / 60).ceil();
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Report Already Sent'),
          content: Text(
            'You recently sent a report. To prevent spamming the Owner, please wait $mins minute(s) before sending another report.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final parts = <String>[];
    if (_mayoTorn) parts.add('The mayo we brought got punctured');
    if (_gasEmpty) parts.add("We're out of gas (LPG)");
    final msg = _messageController.text.trim();
    if (msg.isNotEmpty) {
      final res = InputValidators.validateMessage(
        msg,
        fieldName: 'Additional Message',
        required: false,
        minLength: 10,
        maxLength: 300,
      );
      parts.add(res.sanitizedText.isNotEmpty ? res.sanitizedText : msg);
    }
    final content = parts.isEmpty ? 'Normal operational report.' : parts.join('\n');

    final hasIncident = _mayoTorn || _gasEmpty;
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

  void startTour() {
    if (!mounted) return;
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _quickReportKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '14. Quick Incident & Issue Report',
          instruction: 'PINDUTIN: Pumili ng usapin o mag-type ng mensahe.',
          explanation:
              'Sa tuwing may problema sa branch habang nagluluto (hal. nabutas na mayo, naubusang LPG, o sirang kalan), mag-select ng usapin o mag-type sa box.',
          tip: 'Ang pag-select ng usapin ay mag-e-enable agad sa Send to Owner button.',
          onTargetTapped: () {
            setState(() => _mayoTorn = true);
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: _sendButtonKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '15. Pagpapadala ng Ulat sa Owner',
          instruction: 'PINDUTIN: I-tap ang "Send to Owner" button.',
          explanation:
              'I-tap ang button na ito upang agad na ma-alertuhan ang telepono ng Owner sa pamamagitan ng real-time notification.',
          tip: 'Real-time alert sa telepono ni Owner para mabilis maaksyunan.',
          onTargetTapped: () {
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: _recentReportsKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '16. Recently Submitted Reports & Owner Replies',
          instruction: 'TINGNAN: Dito makikita ang mga ulat at sagot ng Owner.',
          explanation:
              'Dito mo mababasa ang lahat ng iyong mga naisumiteng report, inventory discrepancy records, at ang mga sagot o tugon ng Owner.',
          tip: 'I-check dito kung nabasa at na-confirm na ni Owner o Driver ang iyong ulat.',
          onTargetTapped: () {
            HapticFeedback.lightImpact();
          },
        ),
      ],
      onCompleted: () {
        TutorialService.markTutorialSeen('cook_report_spotlight');
        _showCompletionDialog();
      },
      onSkipped: () {
        TutorialService.markTutorialSeen('cook_report_spotlight');
        _showCompletionDialog();
      },
    );
  }

  void _showCompletionDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('🎉 Onboarding Walkthrough Complete!'),
        content: const Text(
          'Magaling! Natapos mo ang buong Branch Cook Walkthrough Tutorial!\n\n'
          'Na-master mo na ang:\n'
          '• Home Tab & Inventory Verification\n'
          '• Quick POS Sales & Spoilage\n'
          '• Bilao Package Orders\n'
          '• Quick Reports & Owner Messaging\n\n'
          'Handa ka nang maglingkod sa Brahms Nexus!',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Magsimula Na!'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReportDelivered(DailyReport report) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Confirm Delivery Arrival'),
        content: const Text(
          'Have you received the requested items or meat from the driver? Confirming will mark this report as completed and notify the owner.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Yet'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Received'),
          ),
        ],
      ),
    );

    if (confirmed == true && report.id.isNotEmpty) {
      await FirestoreService.confirmReportReceived(
        reportId: report.id,
        branchName: report.branchName,
        employeeName: report.employeeName,
      );
      if (mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Delivery Confirmed'),
            content: const Text('The owner has been notified that the delivery was received. This item has been removed from the pending list.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
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
            KeyedSubtree(
              key: _quickReportKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
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
              maxLength: 300,
              inputFormatters: [
                LengthLimitingTextInputFormatter(300),
              ],
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_messageController.text.trim().isNotEmpty &&
                          !InputValidators.validateMessage(
                            _messageController.text,
                            fieldName: 'Message',
                            required: false,
                            minLength: 10,
                            maxLength: 300,
                          ).isValid)
                      ? AppColors.error
                      : AppColors.border,
                ),
              ),
              placeholderStyle: const TextStyle(color: AppColors.textSecondary),
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_messageController.text.length} / 300 characters',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _messageController.text.length >= 300
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (_messageController.text.trim().isNotEmpty) ...[
              Builder(builder: (context) {
                final validation = InputValidators.validateMessage(
                  _messageController.text,
                  fieldName: 'Message',
                  required: false,
                  minLength: 10,
                  maxLength: 300,
                );
                if (!validation.isValid && validation.errorMessage != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      validation.errorMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],

            if (_mayoTorn || _gasEmpty || _messageController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 22),
              
              // DYNAMIC BUTTON LOGIC
              SizedBox(
                key: _sendButtonKey,
                width: double.infinity,
                child: StaffButton(
                  label: _isSubmitting ? 'Sending...' : 'Send to Owner',
                  icon: _isSubmitting ? null : CupertinoIcons.paperplane_fill,
                  onPressed: (_isSubmitting || !_canSubmit) ? null : _confirmSubmit,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // RECENT SUBMISSIONS BY THIS STAFF/BRANCH
            if (_myRecentReports.isNotEmpty) ...[
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _recentReportsKey,
                child: const StaffSectionHeader(
                  label: 'Recently Submitted Reports',
                  icon: CupertinoIcons.clock_fill,
                  subtitle: 'Track your sent reports and Owner responses',
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final total = _myRecentReports.length;
                  final totalPages = (total / _pageSize).ceil();
                  final effectivePage = totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
                  final pagedReports = _myRecentReports.skip(effectivePage * _pageSize).take(_pageSize).toList();

                  return Column(
                    children: [
                      for (final r in pagedReports) ...[
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
                              if (r.status != ReportSubmissionStatus.submitted) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    color: AppColors.success,
                                    borderRadius: BorderRadius.circular(8),
                                    onPressed: () => _confirmReportDelivered(r),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(CupertinoIcons.checkmark_alt_circle_fill, color: CupertinoColors.white, size: 15),
                                        SizedBox(width: 6),
                                        Text(
                                          'Received? (Confirm)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: CupertinoColors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      AppPaginationBar(
                        currentPage: effectivePage,
                        totalItems: total,
                        pageSize: _pageSize,
                        onPageChanged: (page) => setState(() => _currentPage = page),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 100),
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
    bool enabled = true,
    String? subtitle,
    VoidCallback? onDisabledTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: enabled ? null : onDisabledTap,
        child: StaffCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          highlighted: value && enabled,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !enabled
                      ? AppColors.background.withValues(alpha: 0.5)
                      : (value
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.pastelBrown.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled ? AppColors.accent : AppColors.textSecondary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: enabled ? AppColors.textSecondary : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value && enabled,
                activeTrackColor: AppColors.accent,
                onChanged: enabled
                    ? onChanged
                    : (_) {
                        if (onDisabledTap != null) onDisabledTap();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
