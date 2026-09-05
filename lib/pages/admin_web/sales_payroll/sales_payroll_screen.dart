import 'package:flutter/material.dart';
import '../../../models/sales_record.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';

/// Admin monitors daily sales per branch/employee here. Wage/commission
/// and expected cash remittance are auto-computed from the values
/// Staff submit (see Sales and Auto-Payroll flowchart).
///
/// NOTE: Mock data for now — once Supabase/Firebase are wired up, this
/// reads the real `sales_records` table.
class SalesPayrollScreen extends StatefulWidget {
  const SalesPayrollScreen({super.key});

  @override
  State<SalesPayrollScreen> createState() => _SalesPayrollScreenState();
}

class _SalesPayrollScreenState extends State<SalesPayrollScreen> {
  double _commissionRate = 5;

  final List<SalesRecord> _records = [
    SalesRecord(
      id: 's1',
      branchId: 'br1',
      branchName: 'Dayap, Calauan',
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
      branchName: 'Sta. Cruz',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      date: DateTime.now(),
      portionsSold: 35,
      commissionRatePerPortion: 5,
      totalSalesAmount: 3500,
    ),
    SalesRecord(
      id: 's3',
      branchId: 'br4',
      branchName: 'Labuin',
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      date: DateTime.now().subtract(const Duration(days: 1)),
      portionsSold: 28,
      commissionRatePerPortion: 5,
      totalSalesAmount: 2800,
    ),
  ];

  String? _branchFilter;

  List<SalesRecord> get _visibleRecords {
    if (_branchFilter == null) return _records;
    return _records.where((r) => r.branchName == _branchFilter).toList();
  }

  double get _totalSales =>
      _visibleRecords.fold(0, (sum, r) => sum + r.totalSalesAmount);
  double get _totalWages =>
      _visibleRecords.fold(0, (sum, r) => sum + r.computedWage);
  double get _totalRemittance =>
      _visibleRecords.fold(0, (sum, r) => sum + r.expectedCashRemittance);

  Future<void> _showSetRateDialog() async {
    final controller =
        TextEditingController(text: _commissionRate.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Commission Rate'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Rate per portion (₱)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                setState(() => _commissionRate = value);
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branches = _records.map((r) => r.branchName).toSet().toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales & Payroll',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: PrimaryButton(
                  label: 'COMMISSION RATE: ₱${_commissionRate.toStringAsFixed(2)}',
                  icon: Icons.tune_rounded,
                  onPressed: _showSetRateDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Total Sales',
                  '₱${_totalSales.toStringAsFixed(0)}',
                  Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  'Total Wages',
                  '₱${_totalWages.toStringAsFixed(0)}',
                  Icons.badge_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  'Expected Remittance',
                  '₱${_totalRemittance.toStringAsFixed(0)}',
                  Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Branches'),
                  selected: _branchFilter == null,
                  onSelected: (_) => setState(() => _branchFilter = null),
                ),
                const SizedBox(width: 8),
                ...branches.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(b),
                      selected: _branchFilter == b,
                      onSelected: (_) => setState(() => _branchFilter = b),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _visibleRecords.isEmpty
                ? const Center(
                    child: Text(
                      'No matching sales records.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _visibleRecords.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = _visibleRecords[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.pastelBrown,
                                child: Text(
                                  r.employeeName.substring(0, 1),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.employeeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${r.branchName} · '
                                      '${r.date.month}/${r.date.day}/${r.date.year}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _miniStat(
                                  'Portions',
                                  '${r.portionsSold}',
                                ),
                              ),
                              Expanded(
                                child: _miniStat(
                                  'Total Sales',
                                  '₱${r.totalSalesAmount.toStringAsFixed(0)}',
                                ),
                              ),
                              Expanded(
                                child: _miniStat(
                                  'Wage',
                                  '₱${r.computedWage.toStringAsFixed(0)}',
                                ),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pastelBrown.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: highlight ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
