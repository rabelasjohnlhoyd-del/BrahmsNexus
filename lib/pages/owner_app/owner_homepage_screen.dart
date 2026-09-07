import 'package:flutter/cupertino.dart';
import '../../models/branch_assignment.dart';
import '../../models/daily_report.dart';
import '../../models/inventory_item.dart';
import '../../models/sales_record.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_stat_tile.dart';

/// Homepage tab of the Owner app — an at-a-glance overview of today's
/// operations across all branches: staff on duty, low-stock alerts,
/// today's sales, and pending reports.
///
/// NOTE: Mock data for now, matching the same shapes already used by
/// the Branch Assignments / Inventory / Sales & Payroll / Employee
/// Reports screens. Once Supabase/Firebase are wired up, these four
/// numbers are simple aggregate queries over the real tables.
class OwnerHomepageScreen extends StatelessWidget {
  const OwnerHomepageScreen({super.key});

  // Same mock shape as branch_assignments — will be replaced by a
  // real query once these screens share one data source.
  static final List<BranchAssignment> _assignments = [
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

  static final List<BranchStock> _branchStocks = [
    BranchStock(
      branchId: 'br6',
      branchName: 'Brgy. Dayap, Calauan',
      date: DateTime.now(),
      allocatedKg: 20,
      remainingKg: 14,
    ),
    BranchStock(
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      allocatedKg: 25,
      remainingKg: 3,
    ),
    BranchStock(
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 1,
    ),
  ];

  static final List<SalesRecord> _salesRecords = [
    SalesRecord(
      id: 's1',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      date: DateTime.now(),
      portionsSold: 42,
      commissionRatePerPortion: 5,
      totalSalesAmount: 4200,
    ),
    SalesRecord(
      id: 's2',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      date: DateTime.now(),
      portionsSold: 35,
      commissionRatePerPortion: 5,
      totalSalesAmount: 3500,
    ),
  ];

  static final List<DailyReport> _reports = [
    DailyReport(
      id: 'r1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      content: 'Kumpleto ang benta ngayong araw, walang isyu sa stock.',
      status: ReportSubmissionStatus.submitted,
    ),
    DailyReport(
      id: 'r2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      content: '',
      status: ReportSubmissionStatus.missing,
    ),
  ];

  int get _onDutyCount =>
      _assignments.where((a) => a.workStatus == WorkStatus.onDuty).length;

  int get _lowStockCount => _branchStocks.where((s) => s.isRunningLow).length;

  double get _todaysSales =>
      _salesRecords.fold(0, (sum, r) => sum + r.totalSalesAmount);

  int get _pendingReportsCount => _reports
      .where((r) => r.status != ReportSubmissionStatus.submitted)
      .length;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Owner',
        mode: StaffHeaderMode.greeting,
        greetingName: 'Owner',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StaffSectionHeader(
              label: "Today's Overview",
              icon: CupertinoIcons.chart_bar_alt_fill,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StaffDisplayTile(
                    label: 'On Duty',
                    value: '$_onDutyCount/${_assignments.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaffDisplayTile(
                    label: 'Low Stock',
                    value: '$_lowStockCount',
                    dark: _lowStockCount > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StaffDisplayTile(
                    label: "Today's Sales",
                    value: '₱${_todaysSales.toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaffDisplayTile(
                    label: 'Pending Reports',
                    value: '$_pendingReportsCount',
                    dark: _pendingReportsCount > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const StaffSectionHeader(
              label: 'Quick Links',
              icon: CupertinoIcons.square_grid_2x2_fill,
            ),
            const SizedBox(height: 12),
            StaffCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _QuickLinkRow(
                    icon: CupertinoIcons.person_2_fill,
                    label: 'Assign staff to a branch',
                    hint: 'Assign tab',
                  ),
                  SizedBox(height: 12),
                  _QuickLinkRow(
                    icon: CupertinoIcons.cube_box_fill,
                    label: 'Check branch stock levels',
                    hint: 'Inventory tab',
                  ),
                  SizedBox(height: 12),
                  _QuickLinkRow(
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    label: 'Review sales and payroll',
                    hint: 'Sales tab',
                  ),
                  SizedBox(height: 12),
                  _QuickLinkRow(
                    icon: CupertinoIcons.ellipsis_circle_fill,
                    label: 'Orders, reports, announcements',
                    hint: 'More tab',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkRow extends StatelessWidget {
  const _QuickLinkRow({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: AppColors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          hint,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
