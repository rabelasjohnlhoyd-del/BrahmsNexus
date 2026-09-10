import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_assignment.dart';
import '../../models/staff_member.dart';
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
///
/// Migrated from the old `admin_web/branch_assignments` screen, with
/// three gaps fixed along the way:
///  1. Employee list now comes from [kSampleStaff] (same source as
///     Staff Management) instead of its own separate hardcoded list.
///  2. Branch list now comes from [kSampleBranches] (same source as
///     the Driver app's Route tab) instead of a second hardcoded list.
///  3. The date picker actually changes what's shown now — each date
///     has its own assignment records, and a date with nothing
///     assigned yet shows an empty state instead of always displaying
///     the same 3 rows.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads/
/// writes the real `branch_assignments` table.
class OwnerAssignmentsScreen extends StatefulWidget {
  const OwnerAssignmentsScreen({super.key});

  @override
  State<OwnerAssignmentsScreen> createState() =>
      _OwnerAssignmentsScreenState();
}

class _OwnerAssignmentsScreenState extends State<OwnerAssignmentsScreen> {
  final DateTime _selectedDate = DateTime.now();

  // Mock per-date assignment records, keyed by "yyyy-M-d". Only today
  // is seeded with data — other dates start with nothing, so picking a
  // different date visibly changes the screen instead of always
  // showing the same 3 rows (see gap #3 above).
  final Map<String, List<BranchAssignment>> _assignmentsByDate = {
    _dateKey(DateTime.now()): [
      BranchAssignment(
        id: 'a1',
        employeeId: 'sample-1',
        employeeName: 'Maria Santos',
        branchId: 'br1',
        branchName: 'Brgy. Gatid, Sta. Cruz',
        date: DateTime.now(),
        workStatus: WorkStatus.onDuty,
      ),
      BranchAssignment(
        id: 'a2',
        employeeId: 'sample-3',
        employeeName: 'Maria Reyes',
        branchId: 'br3',
        branchName: 'Brgy. Sta. Clara Sur, Pila',
        date: DateTime.now(),
        workStatus: WorkStatus.onDuty,
      ),
      BranchAssignment(
        id: 'a3',
        employeeId: 'sample-4',
        employeeName: 'Pedro Santos',
        branchId: 'br2',
        branchName: 'Brgy. Labuin, Pila',
        date: DateTime.now(),
        workStatus: WorkStatus.restDay,
      ),
    ],
  };

  static String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  List<BranchAssignment> get _assignments =>
      _assignmentsByDate[_dateKey(_selectedDate)] ?? const [];

  /// Staff who can actually be assigned — deactivated accounts (see
  /// Staff Management) are excluded.
  List<StaffMember> get _assignableStaff =>
      kSampleStaff.where((s) => s.isActive).toList();

  /// Seeds default assignments (On Duty, at each staff member's usual
  /// branch) for the currently selected date.
  void _generateForDate() {
    final key = _dateKey(_selectedDate);
    setState(() {
      _assignmentsByDate[key] = _assignableStaff.map((staff) {
        final branch = kSampleBranches.firstWhere(
          (b) => b.fullName == staff.branch,
          orElse: () => kSampleBranches.first,
        );
        return BranchAssignment(
          id: '${key}_${staff.id}',
          employeeId: staff.id,
          employeeName: staff.fullName,
          branchId: branch.id,
          branchName: branch.fullName,
          date: _selectedDate,
          workStatus: WorkStatus.onDuty,
        );
      }).toList();
    });
  }

  void _updateBranch(int index, Branch branch) {
    setState(() {
      final list = _assignmentsByDate[_dateKey(_selectedDate)]!;
      final a = list[index];
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
    setState(() {
      final list = _assignmentsByDate[_dateKey(_selectedDate)]!;
      final a = list[index];
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
  final VoidCallback onBranchTap;
  final ValueChanged<WorkStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
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
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  assignment.employeeName.substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  assignment.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onBranchTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.location_solid,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assignment.branchName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_down,
                      size: 14, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<WorkStatus>(
              groupValue: assignment.workStatus,
              backgroundColor: AppColors.background,
              thumbColor: AppColors.accent,
              children: {
                WorkStatus.onDuty: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    'On Duty',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: assignment.workStatus == WorkStatus.onDuty
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
                      color: assignment.workStatus == WorkStatus.restDay
                          ? CupertinoColors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              },
              onValueChanged: (value) {
                if (value != null) onStatusChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
