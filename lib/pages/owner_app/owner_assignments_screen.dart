import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_assignment.dart';
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
  }

  void _initializeTodayAssignments() {
    final key = _dateKey(_selectedDate);
    if (!_assignmentsByDate.containsKey(key)) {
      final staffList = SupabaseService.getAllStaff()
          .where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook')
          .toList();
      _assignmentsByDate[key] = staffList.map((s) {
        final isDeactivated = !SupabaseService.isStaffActive(staffId: s.id, fullName: s.fullName);
        final branch = kSampleBranches.firstWhere(
          (b) => b.fullName == s.branch,
          orElse: () => kSampleBranches.first,
        );
        return BranchAssignment(
          id: '${key}_${s.id}',
          employeeId: s.id,
          employeeName: s.fullName,
          branchId: branch.id,
          branchName: isDeactivated ? 'NOT ASSIGNABLE (ACCOUNT FROZEN)' : branch.fullName,
          date: _selectedDate,
          workStatus: isDeactivated ? WorkStatus.restDay : WorkStatus.onDuty,
        );
      }).toList();
    }
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
        final isDeactivated = !SupabaseService.isStaffActive(staffId: staff.id, fullName: staff.fullName);
        final branch = kSampleBranches.firstWhere(
          (b) => b.fullName == staff.branch,
          orElse: () => kSampleBranches.first,
        );
        return BranchAssignment(
          id: '${key}_${staff.id}',
          employeeId: staff.id,
          employeeName: staff.fullName,
          branchId: branch.id,
          branchName: isDeactivated ? 'NOT ASSIGNABLE (ACCOUNT FROZEN)' : branch.fullName,
          date: _selectedDate,
          workStatus: isDeactivated ? WorkStatus.restDay : WorkStatus.onDuty,
        );
      }).toList();
    });
  }

  void _updateBranch(int index, Branch branch) {
    final list = _assignmentsByDate[_dateKey(_selectedDate)];
    if (list == null || index >= list.length) return;
    final a = list[index];
    if (!SupabaseService.isStaffActive(staffId: a.employeeId, fullName: a.employeeName)) {
      return; // Frozen: non-modifiable
    }
    setState(() {
      list[index] = BranchAssignment(
        id: a.id,
        employeeId: a.employeeId,
        employeeName: a.employeeName,
        branchId: branch.id,
        branchName: branch.fullName,
        date: a.date,
        workStatus: a.workStatus,
      );
    });
  }

  void _updateStatus(int index, WorkStatus status) {
    final list = _assignmentsByDate[_dateKey(_selectedDate)];
    if (list == null || index >= list.length) return;
    final a = list[index];
    if (!SupabaseService.isStaffActive(staffId: a.employeeId, fullName: a.employeeName)) {
      return; // Frozen: non-modifiable
    }
    setState(() {
      list[index] = BranchAssignment(
        id: a.id,
        employeeId: a.employeeId,
        employeeName: a.employeeName,
        branchId: a.branchId,
        branchName: a.branchName,
        date: a.date,
        workStatus: status,
      );
    });
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

  void _saveAll() => _showSavedToast();

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
                        const SizedBox(height: 16),
                        ...List.generate(assignments.length, (index) {
                          final a = assignments[index];
                          final isDeactivated = !SupabaseService.isStaffActive(staffId: a.employeeId, fullName: a.employeeName);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AssignmentRow(
                              assignment: a,
                              isDeactivated: isDeactivated,
                              onBranchTap: (isDeactivated || a.workStatus == WorkStatus.restDay)
                                  ? null
                                  : () => _pickBranch(index, a),
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
    required this.isDeactivated,
    required this.onBranchTap,
    required this.onStatusChanged,
  });

  final BranchAssignment assignment;
  final bool isDeactivated;
  final VoidCallback? onBranchTap;
  final ValueChanged<WorkStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = isDeactivated ? WorkStatus.restDay : assignment.workStatus;
    final isRestDay = effectiveStatus == WorkStatus.restDay;

    return StaffCard(
      backgroundColor: isDeactivated ? const Color(0xFFF1F5F9) : CupertinoColors.white,
      borderColor: isDeactivated ? const Color(0xFFCBD5E1) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDeactivated
                      ? CupertinoColors.systemGrey.withValues(alpha: 0.18)
                      : AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  assignment.employeeName.isNotEmpty ? assignment.employeeName.substring(0, 1) : '?',
                  style: TextStyle(
                    color: isDeactivated ? CupertinoColors.systemGrey : AppColors.accent,
                    fontWeight: FontWeight.bold,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDeactivated
                            ? CupertinoColors.systemGrey
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (isDeactivated) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.lock_fill, size: 10, color: CupertinoColors.systemGrey),
                            SizedBox(width: 3),
                            Text(
                              'FROZEN / DEACTIVATED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.systemGrey,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Branch selection container
          IgnorePointer(
            ignoring: isDeactivated,
            child: Opacity(
              opacity: isDeactivated ? 0.35 : (isRestDay ? 0.4 : 1.0),
              child: GestureDetector(
                onTap: onBranchTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDeactivated
                        ? const Color(0xFFE2E8F0)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDeactivated
                          ? const Color(0xFFCBD5E1)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDeactivated ? CupertinoIcons.lock : CupertinoIcons.location_solid,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isDeactivated ? 'NOT ASSIGNABLE (ACCOUNT FROZEN)' : assignment.branchName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isDeactivated ? FontWeight.w600 : FontWeight.normal,
                            color: isDeactivated ? CupertinoColors.systemGrey : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isDeactivated)
                        const Icon(CupertinoIcons.chevron_down,
                            size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Duty status toggle
          IgnorePointer(
            ignoring: isDeactivated,
            child: Opacity(
              opacity: isDeactivated ? 0.45 : 1.0,
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<WorkStatus>(
                  groupValue: effectiveStatus,
                  backgroundColor: AppColors.background,
                  thumbColor: isDeactivated
                      ? CupertinoColors.systemGrey
                      : AppColors.accent,
                  children: {
                    WorkStatus.onDuty: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        'On Duty',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: effectiveStatus == WorkStatus.onDuty
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    WorkStatus.restDay: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        'Rest Day',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: effectiveStatus == WorkStatus.restDay
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (value) {
                    if (!isDeactivated && value != null) onStatusChanged(value);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
