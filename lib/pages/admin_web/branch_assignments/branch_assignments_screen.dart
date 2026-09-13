import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

/// Owner assigns each Branch Cook to a branch for the current day.
/// Drivers and Production staff are excluded from this list.
class BranchAssignmentsScreen extends StatefulWidget {
  const BranchAssignmentsScreen({super.key});

  @override
  State<BranchAssignmentsScreen> createState() =>
      _BranchAssignmentsScreenState();
}

class _BranchAssignmentsScreenState extends State<BranchAssignmentsScreen> {
  // Current date (auto-updates on rebuild/init)
  final DateTime _today = DateTime.now();
  
  final _searchController = TextEditingController();
  String _query = '';

  // derive assignments from staff list, filtered to show only Branch Cooks
  late List<BranchAssignment> _assignments;

  @override
  void initState() {
    super.initState();
    _initializeAssignments();
    _updateShellActions();
  }

  void _initializeAssignments() {
    // Read from live/in-memory staff profiles to always reflect active/deactivated status
    final allStaff = SupabaseService.getAllStaff();
    final branchCooks = allStaff.where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook').toList();
    
    _assignments = branchCooks.map((s) {
      final isDeactivated = !s.isActive || s.isArchived;
      return BranchAssignment(
        id: 'ba-${s.id}',
        employeeId: s.id,
        employeeName: s.fullName,
        branchId: s.branch != 'N/A' ? kSampleBranches.firstWhere((b) => b.fullName == s.branch, orElse: () => kSampleBranches.first).id : kSampleBranches.first.id,
        branchName: isDeactivated ? 'NOT ASSIGNABLE (FROZEN)' : (s.branch != 'N/A' ? s.branch : kSampleBranches.first.fullName),
        date: _today,
        workStatus: isDeactivated ? WorkStatus.restDay : (s.isActive ? WorkStatus.onDuty : WorkStatus.restDay),
      );
    }).toList();
  }

  @override
  void didUpdateWidget(BranchAssignmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeAssignments();
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]); 
  }

  void _updateBranch(int index, Branch branch) {
    final a = _filteredAssignments[index];
    if (!SupabaseService.isStaffActive(staffId: a.employeeId, fullName: a.employeeName)) {
      return; // Locked if deactivated / frozen
    }
    setState(() {
      final originalIndex = _assignments.indexWhere((item) => item.id == a.id);
      if (originalIndex != -1) {
        _assignments[originalIndex] = a.copyWith(
          branchId: branch.id,
          branchName: branch.fullName,
        );
      }
    });
  }

  void _updateStatus(int index, WorkStatus status) {
    final a = _filteredAssignments[index];
    if (!SupabaseService.isStaffActive(staffId: a.employeeId, fullName: a.employeeName)) {
      return; // Locked if deactivated / frozen
    }
    setState(() {
      final originalIndex = _assignments.indexWhere((item) => item.id == a.id);
      if (originalIndex != -1) {
        _assignments[originalIndex] = a.copyWith(workStatus: status);
      }
    });
  }

  void _saveAll() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Branch assignments saved successfully!')),
    );
  }

  List<BranchAssignment> get _filteredAssignments {
    if (_query.trim().isEmpty) return _assignments;
    final q = _query.toLowerCase().trim();
    return _assignments.where((a) => a.employeeName.toLowerCase().contains(q)).toList();
  }

  String _formatToday() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[_today.month - 1]} ${_today.day}, ${_today.year}';
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAssignments;

    return Container(
      color: AdminWebColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 18, color: AdminWebColors.accent),
                        const SizedBox(width: 10),
                        Text(
                          'ASSIGNMENT DATE: ${_formatToday().toUpperCase()}',
                          style: const TextStyle(
                            color: AdminWebColors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                    label: const Text('SAVE ASSIGNMENTS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminWebColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            GlassCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'SEARCH STAFF BY NAME...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminWebColors.accent),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Assignments List
            Expanded(
              child: list.isEmpty
                ? const Center(child: Text('No matching staff found.', style: TextStyle(color: AdminWebColors.textSecondary)))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = list[index];
                      final isDeactivated = !SupabaseService.isStaffActive(
                        staffId: a.employeeId,
                        fullName: a.employeeName,
                      );
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;
                          return _AssignmentCard(
                            assignment: a,
                            isWide: isWide,
                            isDeactivated: isDeactivated,
                            onBranchChanged: (branch) => _updateBranch(index, branch),
                            onStatusChanged: (status) => _updateStatus(index, status),
                          );
                        },
                      );
                    },
                  ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.isWide,
    required this.isDeactivated,
    required this.onBranchChanged,
    required this.onStatusChanged,
  });

  final BranchAssignment assignment;
  final bool isWide;
  final bool isDeactivated;
  final ValueChanged<Branch> onBranchChanged;
  final ValueChanged<WorkStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final bool isRestDay = isDeactivated || assignment.workStatus == WorkStatus.restDay;

    final avatarAndName = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDeactivated
                ? Colors.grey.withValues(alpha: 0.15)
                : AdminWebColors.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDeactivated
                  ? Colors.grey.withValues(alpha: 0.3)
                  : AdminWebColors.accent.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            assignment.employeeName.substring(0, 1),
            style: TextStyle(
              color: isDeactivated ? Colors.grey : AdminWebColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                assignment.employeeName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDeactivated
                      ? AdminWebColors.textSecondary
                      : AdminWebColors.textPrimary,
                ),
              ),
              if (isDeactivated) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminWebColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AdminWebColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_clock_outlined,
                          size: 12, color: AdminWebColors.error),
                      SizedBox(width: 4),
                      Text(
                        'FROZEN / DEACTIVATED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AdminWebColors.error,
                          letterSpacing: 0.4,
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
    );

    final branchDropdown = IgnorePointer(
      ignoring: isRestDay || isDeactivated,
      child: Opacity(
        opacity: isDeactivated ? 0.35 : (isRestDay ? 0.5 : 1.0),
        child: DropdownButtonFormField<String>(
          initialValue: assignment.branchId,
          decoration: InputDecoration(
            labelText: isDeactivated
                ? 'ASSIGNED BRANCH (FROZEN - CANNOT ASSIGN)'
                : 'ASSIGNED BRANCH',
            isDense: true,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.0,
              color: AdminWebColors.textSecondary,
            ),
            prefixIcon: Icon(
              Icons.storefront_rounded,
              size: 20,
              color: isDeactivated ? Colors.grey : AdminWebColors.accent,
            ),
          ),
          items: kSampleBranches
              .map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(
                      isDeactivated
                          ? 'NOT ASSIGNABLE (ACCOUNT FROZEN)'
                          : b.fullName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDeactivated ? Colors.grey : null,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: isDeactivated
              ? null
              : (branchId) {
                  if (branchId != null) {
                    final branch =
                        kSampleBranches.firstWhere((b) => b.id == branchId);
                    onBranchChanged(branch);
                  }
                },
        ),
      ),
    );

    final statusSelector = IgnorePointer(
      ignoring: isDeactivated,
      child: Opacity(
        opacity: isDeactivated ? 0.4 : 1.0,
        child: SegmentedButton<WorkStatus>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: isDeactivated
                ? Colors.grey.shade400
                : (isRestDay ? AdminWebColors.error : AdminWebColors.success),
            selectedForegroundColor: Colors.white,
            side: BorderSide(
                color: isDeactivated
                    ? Colors.grey.shade300
                    : AdminWebColors.border),
          ),
          segments: const [
            ButtonSegment(
              value: WorkStatus.onDuty,
              label: Text('ON DUTY'),
            ),
            ButtonSegment(
              value: WorkStatus.restDay,
              label: Text('REST DAY'),
            ),
          ],
          selected: {isDeactivated ? WorkStatus.restDay : assignment.workStatus},
          onSelectionChanged: isDeactivated
              ? null
              : (value) => onStatusChanged(value.first),
        ),
      ),
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      color: isDeactivated
          ? const Color(0xFFF1F5F9).withValues(alpha: 0.9)
          : null,
      borderColor: isDeactivated
          ? Colors.grey.withValues(alpha: 0.35)
          : null,
      child: isWide
          ? Row(
              children: [
                Expanded(flex: 3, child: avatarAndName),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: branchDropdown),
                const SizedBox(width: 24),
                statusSelector,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                avatarAndName,
                const SizedBox(height: 16),
                branchDropdown,
                const SizedBox(height: 12),
                Center(child: statusSelector),
              ],
            ),
    );
  }
}
