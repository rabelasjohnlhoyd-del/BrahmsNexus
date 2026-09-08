import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';
import '../../../widgets/admin_page_header.dart';

/// Owner assigns each employee to a branch for a chosen date, and
/// marks them On Duty or on a Rest Day. This is what Staff read for
/// "Today's Assignment" and what Driver reads to build the route.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads/
/// writes the real `branch_assignments` table (rarely-changing branch
/// list lives in Supabase; the daily assignment records could live in
/// either store depending on how often they're queried).
class BranchAssignmentsScreen extends StatefulWidget {
  const BranchAssignmentsScreen({super.key});

  @override
  State<BranchAssignmentsScreen> createState() =>
      _BranchAssignmentsScreenState();
}

class _BranchAssignmentsScreenState extends State<BranchAssignmentsScreen> {
  DateTime _selectedDate = DateTime.now();

  static const double _wideBreakpoint = 700;

  final List<BranchAssignment> _assignments = [
    BranchAssignment(
      id: 'a1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      workStatus: WorkStatus.onDuty,
    ),
    BranchAssignment(
      id: 'a2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      workStatus: WorkStatus.onDuty,
    ),
    BranchAssignment(
      id: 'a3',
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      workStatus: WorkStatus.restDay,
    ),
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _updateBranch(int index, Branch branch) {
    setState(() {
      final a = _assignments[index];
      _assignments[index] = BranchAssignment(
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
      final a = _assignments[index];
      _assignments[index] = BranchAssignment(
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

  void _saveAll() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Branch assignments saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Branch Assignments',
            subtitle:
                'Assign each employee to a branch and set their work status for the day.',
            actions: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                    '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}'),
              ),
              ElevatedButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('SAVE ASSIGNMENTS'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _assignments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final a = _assignments[index];
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
        ],
      ),
    );
  }
}

/// Isang employee row — Row (magkatabi) sa malawak na screen, Column
/// (nakapatong) sa makitid na screen (phone browser) para hindi
/// masiksik ang dropdown at segmented button.
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

    final branchDropdown = DropdownButtonFormField<String>(
      value: assignment.branchId,
      decoration: const InputDecoration(
        labelText: 'BRANCH',
        isDense: true,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.0,
          color: AdminWebColors.textSecondary,
        ),
        prefixIcon:
            Icon(Icons.storefront_rounded, size: 20, color: AdminWebColors.accent),
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
        final branch = kSampleBranches.firstWhere((b) => b.id == branchId);
        onBranchChanged(branch);
      },
    );

    final statusSelector = SegmentedButton<WorkStatus>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AdminWebColors.accent,
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
