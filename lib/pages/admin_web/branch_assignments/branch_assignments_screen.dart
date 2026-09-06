import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../theme/admin_theme.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Padding(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isWide
                  ? Row(
                      children: [
                        const Expanded(child: _TitleText()),
                        _DateButton(
                          date: _selectedDate,
                          onPressed: _pickDate,
                        ),
                        const SizedBox(width: 12),
                        _SaveButton(onPressed: _saveAll),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TitleText(),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _DateButton(
                                date: _selectedDate,
                                onPressed: _pickDate,
                                fullWidth: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SaveButton(
                                onPressed: _saveAll,
                                fullWidth: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
              const SizedBox(height: 4),
              const Text(
                'Assign each employee to a branch and set their work status '
                'for the selected date.',
                style: TextStyle(color: AdminColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final a = _assignments[index];
                    return _AssignmentCard(
                      assignment: a,
                      isWide: isWide,
                      onBranchChanged: (branch) => _updateBranch(index, branch),
                      onStatusChanged: (status) =>
                          _updateStatus(index, status),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Branch Assignments',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AdminColors.textPrimary,
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.date,
    required this.onPressed,
    this.fullWidth = false,
  });

  final DateTime date;
  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_rounded, size: 18),
      label: Text('${date.month}/${date.day}/${date.year}'),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed, this.fullWidth = false});

  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save_rounded, size: 18),
      label: const Text('Save All'),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
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
        CircleAvatar(
          backgroundColor: AdminColors.primary,
          child: Text(
            assignment.employeeName.substring(0, 1),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            assignment.employeeName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
      ],
    );

    final branchDropdown = DropdownButtonFormField<String>(
      value: assignment.branchId,
      decoration: const InputDecoration(
        labelText: 'Branch',
        isDense: true,
      ),
      items: kSampleBranches
          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.fullName)))
          .toList(),
      onChanged: (branchId) {
        final branch = kSampleBranches.firstWhere((b) => b.id == branchId);
        onBranchChanged(branch);
      },
    );

    final statusSelector = SegmentedButton<WorkStatus>(
      segments: const [
        ButtonSegment(value: WorkStatus.onDuty, label: Text('On Duty')),
        ButtonSegment(value: WorkStatus.restDay, label: Text('Rest Day')),
      ],
      selected: {assignment.workStatus},
      onSelectionChanged: (value) => onStatusChanged(value.first),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
                children: [
                  Expanded(flex: 2, child: avatarAndName),
                  Expanded(flex: 2, child: branchDropdown),
                  const SizedBox(width: 16),
                  statusSelector,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  avatarAndName,
                  const SizedBox(height: 12),
                  branchDropdown,
                  const SizedBox(height: 12),
                  Center(child: statusSelector),
                ],
              ),
      ),
    );
  }
}
