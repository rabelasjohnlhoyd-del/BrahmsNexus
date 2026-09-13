import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_assignment.dart';
import '../../models/staff_member.dart';
import '../../services/assignment_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

/// Assignments tab — Owner assigns each active staff member to a branch
/// and sets their work status (On Duty / Rest Day) for a chosen date.
/// This is what the Staff app reads for "Today's Assignment" and what
/// the Driver app reads to build the day's route.
class OwnerAssignmentsScreen extends StatefulWidget {
  const OwnerAssignmentsScreen({super.key});

  @override
  State<OwnerAssignmentsScreen> createState() =>
      _OwnerAssignmentsScreenState();
}

class _OwnerAssignmentsScreenState extends State<OwnerAssignmentsScreen> {
  final DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  // Mock per-date assignment records, keyed by "yyyy-M-d".
  final Map<String, List<BranchAssignment>> _assignmentsByDate = {};

  static String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  void initState() {
    super.initState();
    _initializeTodayAssignments();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentsChanged);
    super.dispose();
  }

  void _onAssignmentsChanged() {
    if (!mounted) return;
    final key = _dateKey(_selectedDate);
    final staffList = SupabaseService.getAllStaff()
        .where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook')
        .toList();
    setState(() {
      final list = _assignmentsByDate[key];
      if (list != null) {
        for (int i = 0; i < list.length; i++) {
          final a = list[i];
          final staff = staffList.firstWhere(
            (s) => s.id == a.employeeId,
            orElse: () => StaffMember(id: a.employeeId, firstName: '', lastName: '', username: '', branch: '', position: ''),
          );

          // AssignmentService.lockStatus() is called synchronously before any cloud writes,
          // so this cache is ALWAYS ahead of Supabase realtime. Use it as source of truth.
          // Fall back to a.workStatus (current on-screen status) — never revert the UI.
          final status = staff.username.isNotEmpty
              ? AssignmentService.getWorkStatus(staff.username,
                  fallback: AssignmentService.getWorkStatus(a.employeeId, fallback: a.workStatus))
              : AssignmentService.getWorkStatus(a.employeeId, fallback: a.workStatus);

          // Same for branch — keep a.branchName as fallback so branch never resets on toggle.
          final branchName = staff.username.isNotEmpty
              ? AssignmentService.getAssignedBranch(staff.username,
                  fallback: AssignmentService.getAssignedBranch(a.employeeId, fallback: a.branchName))
              : AssignmentService.getAssignedBranch(a.employeeId, fallback: a.branchName);

          final branch = kSampleBranches.firstWhere(
            (b) => b.fullName == branchName,
            orElse: () => kSampleBranches.first,
          );
          list[i] = a.copyWith(
            workStatus: status,
            branchId: branch.id,
            branchName: branch.fullName,
          );
        }
      }
    });
  }

  void _initializeTodayAssignments() async {
    final key = _dateKey(_selectedDate);
    if (!_assignmentsByDate.containsKey(key)) {
      final staffList = SupabaseService.getAllStaff()
          .where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook')
          .toList();
      _assignmentsByDate[key] = staffList.map((s) {
        final cachedStatus = AssignmentService.getWorkStatus(
          s.username,
          fallback: AssignmentService.getWorkStatus(
            s.id,
            fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
          ),
        );
        final cachedBranch = AssignmentService.getAssignedBranch(
          s.username,
          fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch),
        );
        final branch = kSampleBranches.firstWhere(
          (b) => b.fullName == cachedBranch,
          orElse: () => kSampleBranches.firstWhere((b) => b.fullName == s.branch, orElse: () => kSampleBranches.first),
        );
        return BranchAssignment(
          id: '${key}_${s.id}',
          employeeId: s.id,
          employeeName: s.fullName,
          branchId: branch.id,
          branchName: branch.fullName,
          date: _selectedDate,
          workStatus: cachedStatus,
        );
      }).toList();
    }

    // Refresh from AssignmentService (memory cache, local file, and Firestore cloud)
    try {
      await AssignmentService.ensureInitialized();
      if (mounted) {
        _onAssignmentsChanged();
      }
    } catch (_) {}
  }

  List<BranchAssignment> get _assignments {
    final list = _assignmentsByDate[_dateKey(_selectedDate)] ?? const [];
    if (_searchQuery.isEmpty) return list;
    return list
        .where((a) => a.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  /// Seeds default assignments for the currently selected date.
  void _generateForDate() {
    final key = _dateKey(_selectedDate);
    setState(() {
      final staffList = SupabaseService.getAllStaff()
          .where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook')
          .toList();
      _assignmentsByDate[key] = staffList.map((staff) {
        final cachedStatus = AssignmentService.getWorkStatus(
          staff.username,
          fallback: AssignmentService.getWorkStatus(staff.id, fallback: staff.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty),
        );
        final cachedBranch = AssignmentService.getAssignedBranch(
          staff.username,
          fallback: AssignmentService.getAssignedBranch(staff.id, fallback: staff.branch),
        );
        final branch = kSampleBranches.firstWhere(
          (b) => b.fullName == cachedBranch,
          orElse: () => kSampleBranches.firstWhere((b) => b.fullName == staff.branch, orElse: () => kSampleBranches.first),
        );
        return BranchAssignment(
          id: '${key}_${staff.id}',
          employeeId: staff.id,
          employeeName: staff.fullName,
          branchId: branch.id,
          branchName: branch.fullName,
          date: _selectedDate,
          workStatus: cachedStatus,
        );
      }).toList();
    });
  }

  void _updateBranch(int index, Branch branch) async {
    final list = _assignmentsByDate[_dateKey(_selectedDate)];
    if (list == null || index >= list.length) return;
    final a = list[index];

    // Lookup username synchronously first
    final allStaff = SupabaseService.getAllStaff();
    final staff = allStaff.firstWhere(
      (s) => s.id == a.employeeId || s.fullName.toLowerCase() == a.employeeName.toLowerCase(),
      orElse: () => StaffMember(id: a.employeeId, firstName: '', lastName: '', username: '', branch: '', position: ''),
    );
    final username = staff.username.isNotEmpty ? staff.username : a.employeeId;

    // ⚡ Lock branch cache BEFORE any await so realtime never reverts the branch.
    AssignmentService.lockBranch(
      username: username,
      employeeId: a.employeeId,
      branchName: branch.fullName,
    );

    setState(() {
      list[index] = a.copyWith(
        branchId: branch.id,
        branchName: branch.fullName,
      );
    });

    await AssignmentService.setAssignment(
      username: username,
      employeeId: a.employeeId,
      employeeName: a.employeeName,
      branchId: branch.id,
      branchName: branch.fullName,
      status: a.workStatus,
    );
  }

  void _updateStatus(int index, WorkStatus status) async {
    final list = _assignmentsByDate[_dateKey(_selectedDate)];
    if (list == null || index >= list.length) return;
    final a = list[index];

    // Lookup username synchronously first
    final allStaff = SupabaseService.getAllStaff();
    final staff = allStaff.firstWhere(
      (s) => s.id == a.employeeId || s.fullName.toLowerCase() == a.employeeName.toLowerCase(),
      orElse: () => StaffMember(id: a.employeeId, firstName: '', lastName: '', username: '', branch: '', position: ''),
    );
    final username = staff.username.isNotEmpty ? staff.username : a.employeeId;

    // ⚡ Lock cache IMMEDIATELY (synchronous, no await) — must happen before any async
    // cloud call, so the Supabase realtime listener never reads stale status and reverts the UI.
    AssignmentService.lockStatus(
      username: username,
      employeeId: a.employeeId,
      status: status,
      branchName: a.branchName,
    );

    // Optimistically update UI
    setState(() {
      list[index] = a.copyWith(workStatus: status);
    });

    // If setting to onDuty, reactivate staff account in Supabase
    if (status == WorkStatus.onDuty) {
      await SupabaseService.toggleStaffActive(a.employeeId, true);
    }

    // Save via AssignmentService (memory cache, local file, Supabase, and Firestore)
    await AssignmentService.setAssignment(
      username: username,
      employeeId: a.employeeId,
      employeeName: a.employeeName,
      branchId: a.branchId,
      branchName: a.branchName,
      status: status,
    );
  }

  Future<void> _pickBranch(int index, BranchAssignment current) async {
    var tempIndex =
        kSampleBranches.indexWhere((b) => b.id == current.branchId);
    if (tempIndex == -1) tempIndex = 0;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        height: 260,
        color: CupertinoColors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(popupContext).pop(),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () {
                    _updateBranch(index, kSampleBranches[tempIndex]);
                    Navigator.of(popupContext).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController:
                    FixedExtentScrollController(initialItem: tempIndex),
                onSelectedItemChanged: (i) => tempIndex = i,
                children: kSampleBranches
                    .map((b) => Center(child: Text(b.fullName)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAll() async {
    final list = _assignmentsByDate[_dateKey(_selectedDate)] ?? [];
    final allStaff = SupabaseService.getAllStaff();
    for (final a in list) {
      final staff = allStaff.firstWhere(
        (s) => s.id == a.employeeId || s.fullName.toLowerCase() == a.employeeName.toLowerCase(),
        orElse: () => StaffMember(id: a.employeeId, firstName: '', lastName: '', username: '', branch: '', position: ''),
      );
      final username = staff.username.isNotEmpty ? staff.username : a.employeeId;
      await AssignmentService.setAssignment(
        username: username,
        employeeId: a.employeeId,
        employeeName: a.employeeName,
        branchId: a.branchId,
        branchName: a.branchName,
        status: a.workStatus,
      );
    }
    _showSavedToast();
  }

  void _showSavedToast() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: SafeArea(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(CupertinoIcons.check_mark_circled_solid,
                    color: AppColors.success, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Assignments saved!',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    final assignments = _assignments;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Assignments',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: CupertinoSearchTextField(
                placeholder: 'Search staff by name...',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: assignments.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const StaffSectionHeader(
                          label:
                              'Assign each staff to a branch and set their work status today.',
                          icon: CupertinoIcons.person_2_fill,
                        ),
                        const SizedBox(height: 12),
                        // Summary KPI chips for mobile
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${assignments.length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Total Staff',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${assignments.where((a) => a.workStatus == WorkStatus.onDuty).length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '🟢 On Duty',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF065F46),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${assignments.where((a) => a.workStatus == WorkStatus.restDay).length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '🔴 Rest Day',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF991B1B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(assignments.length, (index) {
                          final a = assignments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AssignmentRow(
                              assignment: a,
                              onBranchTap: () => _pickBranch(index, a),
                              onStatusChanged: (status) =>
                                  _updateStatus(index, status),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        StaffButton(
                          label: 'Save All',
                          icon: CupertinoIcons.check_mark_circled,
                          onPressed: _saveAll,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.person_2_fill,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No assignments recorded for today.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            StaffButton(
              label: 'Assign Staff for Today',
              onPressed: _generateForDate,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.onBranchTap,
    required this.onStatusChanged,
  });

  final BranchAssignment assignment;
  final VoidCallback? onBranchTap;
  final ValueChanged<WorkStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final bool isOnDuty = assignment.workStatus == WorkStatus.onDuty;

    return StaffCard(
      backgroundColor: CupertinoColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isOnDuty
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : CupertinoColors.systemGrey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  assignment.employeeName.isNotEmpty
                      ? assignment.employeeName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: isOnDuty ? AppColors.accent : CupertinoColors.systemGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isOnDuty ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isOnDuty ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOnDuty ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.moon_fill,
                            size: 11,
                            color: isOnDuty ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnDuty ? 'May Duty Ngayon' : 'Naka-Rest Day (Day Off)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isOnDuty ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Branch selection container
          GestureDetector(
            onTap: onBranchTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isOnDuty ? AppColors.background : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOnDuty ? AppColors.border : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOnDuty ? CupertinoIcons.location_solid : CupertinoIcons.bed_double_fill,
                    size: 15,
                    color: isOnDuty ? AppColors.accent : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOnDuty
                          ? assignment.branchName
                          : '${assignment.branchName} (Naka-Rest Day)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isOnDuty ? AppColors.textPrimary : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 13,
                    color: isOnDuty ? AppColors.textSecondary : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Dual-pill Duty Status Toggle
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(3.5),
            child: Row(
              children: [
                // ON DUTY BUTTON
                Expanded(
                  child: GestureDetector(
                    onTap: () => onStatusChanged(WorkStatus.onDuty),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isOnDuty ? const Color(0xFF10B981) : CupertinoColors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isOnDuty
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isOnDuty ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                            size: 15,
                            color: isOnDuty ? CupertinoColors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ON DUTY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isOnDuty ? FontWeight.w800 : FontWeight.w600,
                              color: isOnDuty ? CupertinoColors.white : const Color(0xFF475569),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // REST DAY BUTTON
                Expanded(
                  child: GestureDetector(
                    onTap: () => onStatusChanged(WorkStatus.restDay),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !isOnDuty ? const Color(0xFFEF4444) : CupertinoColors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !isOnDuty
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            !isOnDuty ? CupertinoIcons.moon_fill : CupertinoIcons.circle,
                            size: 15,
                            color: !isOnDuty ? CupertinoColors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'REST DAY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !isOnDuty ? FontWeight.w800 : FontWeight.w600,
                              color: !isOnDuty ? CupertinoColors.white : const Color(0xFF475569),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Clear explanation note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOnDuty ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isOnDuty ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOnDuty ? CupertinoIcons.info_circle_fill : CupertinoIcons.exclamationmark_circle_fill,
                  size: 13,
                  color: isOnDuty ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOnDuty
                        ? 'Puwede mag-login sa POS app'
                        : 'Bawal mag-login sa POS app habang naka-rest day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOnDuty ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
