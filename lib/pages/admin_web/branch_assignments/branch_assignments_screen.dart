import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../models/staff_member.dart';
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
    // Only include Branch Cooks
    final branchCooks = kSampleStaff.where((s) => s.position == 'Branch Cook').toList();
    
    _assignments = branchCooks.map((s) {
      return BranchAssignment(
        id: 'ba-${s.id}',
        employeeId: s.id,
        employeeName: s.fullName,
        branchId: s.branch != 'N/A' ? kSampleBranches.firstWhere((b) => b.fullName == s.branch, orElse: () => kSampleBranches.first).id : kSampleBranches.first.id,
        branchName: s.branch != 'N/A' ? s.branch : kSampleBranches.first.fullName,
        date: _today,
        workStatus: s.isActive ? WorkStatus.onDuty : WorkStatus.restDay,
      );
    }).toList();
  }

  @override
  void didUpdateWidget(BranchAssignmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]); 
  }

  void _updateBranch(int index, Branch branch) {
    setState(() {
      final a = _filteredAssignments[index];
      // find original index in _assignments
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
    setState(() {
      final a = _filteredAssignments[index];
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
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;
                          return _AssignmentCard(
                            assignment: a,
                            isWide: isWide,
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
    required this.onBranchChanged,
    required this.onStatusChanged,
  });

  final BranchAssignment assignment;
  final bool isWide;
  final ValueChanged<Branch> onBranchChanged;
  final ValueChanged<WorkStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final bool isRestDay = assignment.workStatus == WorkStatus.restDay;

    final avatarAndName = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AdminWebColors.accent.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            assignment.employeeName.substring(0, 1),
            style: const TextStyle(
              color: AdminWebColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            assignment.employeeName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AdminWebColors.textPrimary,
            ),
          ),
        ),
      ],
    );

    final branchDropdown = IgnorePointer(
      ignoring: isRestDay,
      child: Opacity(
        opacity: isRestDay ? 0.5 : 1.0,
        child: DropdownButtonFormField<String>(
          value: assignment.branchId,
          decoration: const InputDecoration(
            labelText: 'ASSIGNED BRANCH',
            isDense: true,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.0,
              color: AdminWebColors.textSecondary,
            ),
            prefixIcon: Icon(Icons.storefront_rounded, size: 20, color: AdminWebColors.accent),
          ),
          items: kSampleBranches
              .map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(
                      b.fullName.toUpperCase(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ))
              .toList(),
          onChanged: (branchId) {
            if (branchId != null) {
              final branch = kSampleBranches.firstWhere((b) => b.id == branchId);
              onBranchChanged(branch);
            }
          },
        ),
      ),
    );

    final statusSelector = SegmentedButton<WorkStatus>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: isRestDay ? AdminWebColors.error : AdminWebColors.success,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AdminWebColors.border),
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
      selected: {assignment.workStatus},
      onSelectionChanged: (value) => onStatusChanged(value.first),
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
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
