import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../theme/app_theme.dart';

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

  final List<BranchAssignment> _assignments = [
    BranchAssignment(
      id: 'a1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br2',
      branchName: 'Sta. Cruz',
      date: DateTime.now(),
      workStatus: WorkStatus.onDuty,
    ),
    BranchAssignment(
      id: 'a2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Pila',
      date: DateTime.now(),
      workStatus: WorkStatus.onDuty,
    ),
    BranchAssignment(
      id: 'a3',
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      branchId: 'br4',
      branchName: 'Labuin',
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
        branchName: branch.name,
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Branch Assignments',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                  '${_selectedDate.month}/${_selectedDate.day}/'
                  '${_selectedDate.year}',
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save All'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Assign each employee to a branch and set their work status '
            'for the selected date.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _assignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final a = _assignments[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.pastelBrown,
                          child: Text(
                            a.employeeName.substring(0, 1),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: Text(
                            a.employeeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: a.branchId,
                            decoration: const InputDecoration(
                              labelText: 'Branch',
                              isDense: true,
                            ),
                            items: kSampleBranches
                                .map((b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text(b.name),
                                    ))
                                .toList(),
                            onChanged: (branchId) {
                              final branch = kSampleBranches
                                  .firstWhere((b) => b.id == branchId);
                              _updateBranch(index, branch);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        SegmentedButton<WorkStatus>(
                          segments: const [
                            ButtonSegment(
                              value: WorkStatus.onDuty,
                              label: Text('On Duty'),
                            ),
                            ButtonSegment(
                              value: WorkStatus.restDay,
                              label: Text('Rest Day'),
                            ),
                          ],
                          selected: {a.workStatus},
                          onSelectionChanged: (value) {
                            _updateStatus(index, value.first);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
