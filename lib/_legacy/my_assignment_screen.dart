import 'package:flutter/material.dart';
import '../models/branch_assignment.dart';
import '../theme/app_theme.dart';

/// Shows the logged-in Staff member's assignment for today: which
/// branch, and whether they're On Duty or on a Rest Day.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads
/// the current user's [BranchAssignment] record for today's date.
class MyAssignmentScreen extends StatelessWidget {
  const MyAssignmentScreen({super.key});

  static final _mockAssignment = BranchAssignment(
    id: 'a1',
    employeeId: 'emp1',
    employeeName: 'Juan Dela Cruz',
    branchId: 'br2',
    branchName: 'Sta. Cruz',
    date: DateTime.now(),
    workStatus: WorkStatus.onDuty,
  );

  @override
  Widget build(BuildContext context) {
    final assignment = _mockAssignment;
    final isOnDuty = assignment.workStatus == WorkStatus.onDuty;

    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Assignment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.pastelBrown.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.store_mall_directory_rounded,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Assigned Branch',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  assignment.branchName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Icon(
                            isOnDuty
                                ? Icons.check_circle_rounded
                                : Icons.bedtime_rounded,
                            color: isOnDuty
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            assignment.workStatus.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isOnDuty
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${assignment.date.month}/${assignment.date.day}/'
                        '${assignment.date.year}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
