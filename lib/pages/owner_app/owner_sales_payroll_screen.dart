import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/sales_record.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

/// Sales & Payroll tab — Owner monitors daily sales per branch/
/// employee; wage/commission and expected cash remittance are
/// auto-computed from what Staff submit (see the Sales and
/// Auto-Payroll flowchart).
///
/// Migrated from the old `admin_web/sales_payroll` screen. That
/// screen hardcoded each record's `branchName` as a retyped string
/// (e.g. 'Brgy. Gatid, Sta. Cruz') instead of sourcing it from
/// [kSampleBranches] — the same duplicate-data gap already fixed in
/// the Inventory tab. Fixed here the same way: every record below
/// only stores a `branchId`, and both the branch name shown and the
/// branch filter resolve through [kSampleBranches].
///
/// NOTE: Mock data for now — once Supabase/Firebase are wired up,
/// this reads the real `sales_records` table.
class OwnerSalesPayrollScreen extends StatefulWidget {
  const OwnerSalesPayrollScreen({super.key});

  @override
  State<OwnerSalesPayrollScreen> createState() =>
      _OwnerSalesPayrollScreenState();
}

class _OwnerSalesPayrollScreenState extends State<OwnerSalesPayrollScreen> {
  double _commissionRate = 5;
  String? _branchFilter; // branch id, null = all branches
  int _dateRangeFilter = 0; // 0 = Today, 1 = Yesterday, 2 = This Week

  static String _branchName(String id) =>
      kSampleBranches.firstWhere((b) => b.id == id).fullName;

  final List<SalesRecord> _records = [
    SalesRecord(
      id: 's1',
      branchId: 'br1',
      branchName: _branchName('br1'),
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
      branchName: _branchName('br2'),
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      date: DateTime.now(),
      portionsSold: 35,
      commissionRatePerPortion: 5,
      totalSalesAmount: 3500,
    ),
    SalesRecord(
      id: 's3',
      branchId: 'br3',
      branchName: _branchName('br3'),
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      date: DateTime.now().subtract(const Duration(days: 1)),
      portionsSold: 28,
      commissionRatePerPortion: 5,
      totalSalesAmount: 2800,
    ),
  ];

  List<SalesRecord> get _visibleRecords {
    final now = DateTime.now();
    return _records.where((r) {
      // Branch filter
      if (_branchFilter != null && r.branchId != _branchFilter) return false;

      // Date range filter
      final recordDate = DateTime(r.date.year, r.date.month, r.date.day);
      final today = DateTime(now.year, now.month, now.day);

      if (_dateRangeFilter == 0) {
        return recordDate.isAtSameMomentAs(today);
      } else if (_dateRangeFilter == 1) {
        final yesterday = today.subtract(const Duration(days: 1));
        return recordDate.isAtSameMomentAs(yesterday);
      } else if (_dateRangeFilter == 2) {
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return recordDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            recordDate.isBefore(today.add(const Duration(days: 1)));
      }
      return true;
    }).toList();
  }

  double get _totalSales =>
      _visibleRecords.fold(0, (sum, r) => sum + r.totalSalesAmount);
  double get _totalWages =>
      _visibleRecords.fold(0, (sum, r) => sum + r.computedWage);
  double get _totalRemittance =>
      _visibleRecords.fold(0, (sum, r) => sum + r.expectedCashRemittance);

  /// Same small numeric-input dialog style as Inventory's
  /// Set Total Stock / Allocate dialogs, reworded for currency.
  Future<void> _showSetRateDialog() async {
    final controller =
        TextEditingController(text: _commissionRate.toStringAsFixed(2));
    final value = await showCupertinoDialog<double>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Set Commission Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            const Text(
              'Rate paid to staff per portion sold (₱).',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              autofocus: true,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() => _commissionRate = value);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Sales & Payroll',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            StaffCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StaffSectionHeader(
                    label: 'Commission Rate',
                    icon: CupertinoIcons.tag_fill,
                  ),
                  const SizedBox(height: 16),
                  _statRow('Rate per Portion',
                      '₱${_commissionRate.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  StaffButton(
                    label: 'Set Commission Rate',
                    icon: CupertinoIcons.pencil,
                    onPressed: _showSetRateDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _summaryCard('Total Sales', '₱${_totalSales.toStringAsFixed(0)}',
                CupertinoIcons.money_dollar_circle_fill),
            const SizedBox(height: 10),
            _summaryCard('Total Wages', '₱${_totalWages.toStringAsFixed(0)}',
                CupertinoIcons.person_2_fill),
            const SizedBox(height: 10),
            _summaryCard(
                'Expected Remittance',
                '₱${_totalRemittance.toStringAsFixed(0)}',
                CupertinoIcons.archivebox_fill),
            const SizedBox(height: 20),
            const StaffSectionHeader(
              label: 'Historical View',
              icon: CupertinoIcons.calendar,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _dateRangeFilter,
                backgroundColor: AppColors.border.withValues(alpha: 0.15),
                thumbColor: CupertinoColors.white,
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _dateRangeFilter == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _dateRangeFilter == 0
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Yesterday',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _dateRangeFilter == 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _dateRangeFilter == 1
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _dateRangeFilter == 2
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _dateRangeFilter == 2
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                },
                onValueChanged: (v) {
                  if (v != null) setState(() => _dateRangeFilter = v);
                },
              ),
            ),
            const SizedBox(height: 20),
            const StaffSectionHeader(
              label: 'Sales Records',
              icon: CupertinoIcons.list_bullet,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(
                    label: 'All Branches',
                    selected: _branchFilter == null,
                    onTap: () => setState(() => _branchFilter = null),
                  ),
                  const SizedBox(width: 8),
                  for (final b in kSampleBranches) ...[
                    _filterChip(
                      label: b.fullName,
                      selected: _branchFilter == b.id,
                      onTap: () => setState(() => _branchFilter = b.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_visibleRecords.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Walang sales record na tumutugma.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              for (final r in _visibleRecords) ...[
                _buildRecordCard(r),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return StaffCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : CupertinoColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? CupertinoColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(SalesRecord r) {
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
                decoration: const BoxDecoration(
                  color: AppColors.accentDark,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  r.employeeName.substring(0, 1),
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.branchName} · '
                      '${r.date.month}/${r.date.day}/${r.date.year}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniStat('Portions', '${r.portionsSold}')),
              Expanded(
                child: _miniStat(
                    'Total Sales', '₱${r.totalSalesAmount.toStringAsFixed(0)}'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                    'Wage', '₱${r.computedWage.toStringAsFixed(0)}'),
              ),
              Expanded(
                child: _miniStat(
                  'Remittance',
                  '₱${r.expectedCashRemittance.toStringAsFixed(0)}',
                  highlight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
