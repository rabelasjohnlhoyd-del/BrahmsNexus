import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/sales_record.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class OwnerSalesPayrollScreen extends StatefulWidget {
  const OwnerSalesPayrollScreen({super.key});

  @override
  State<OwnerSalesPayrollScreen> createState() => _OwnerSalesPayrollScreenState();
}

class _OwnerSalesPayrollScreenState extends State<OwnerSalesPayrollScreen> {
  String? _branchFilter; // null means "All Branches"
  StreamSubscription<List<SalesRecord>>? _salesSub;

  final List<SalesRecord> _records = [
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

  List<SalesRecord> get _visibleRecords {
    if (_branchFilter == null) return _records;
    return _records.where((r) => r.branchId == _branchFilter).toList();
  }

  double get _totalSales => _visibleRecords.fold(0, (sum, r) => sum + r.totalSalesAmount);
  double get _totalWages => _visibleRecords.fold(0, (sum, r) => sum + r.computedWage);
  double get _totalRemittance => _visibleRecords.fold(0, (sum, r) => sum + r.expectedCashRemittance);

  void _showBranchPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter by Branch'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () { setState(() => _branchFilter = null); Navigator.pop(context); },
            child: const Text('All Branches'),
          ),
          ...kSampleBranches.map((b) => CupertinoActionSheetAction(
            onPressed: () { setState(() => _branchFilter = b.id); Navigator.pop(context); },
            child: Text(b.fullName),
          )),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _salesSub = FirestoreService.watchRecentSales().listen((records) {
      if (mounted) {
        setState(() {
          _records
            ..clear()
            ..addAll(records);
        });
      }
    });
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(title: 'Sales & Payroll', trailing: StaffTopActions()),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard('Total Sales', '₱${_totalSales.toStringAsFixed(0)}', CupertinoIcons.money_dollar_circle_fill),
            const SizedBox(height: 10),
            _summaryCard('Total Wages', '₱${_totalWages.toStringAsFixed(0)}', CupertinoIcons.person_2_fill),
            const SizedBox(height: 10),
            _summaryCard('Remittance', '₱${_totalRemittance.toStringAsFixed(0)}', CupertinoIcons.archivebox_fill),
            const SizedBox(height: 24),
            StaffSectionHeader(
              label: 'Sales Records',
              icon: CupertinoIcons.list_bullet,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showBranchPicker,
                child: Text(_branchFilter == null ? 'All Branches' : 'Filtered', style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 12),
            for (final r in _visibleRecords) ...[
              StaffCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (r.remainingStock != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('With Remaining Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                          ),
                      ],
                    ),
                    Text(r.branchName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Orders: ${r.portionsSold}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          'Remit: ₱${r.expectedCashRemittance.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent),
                        ),
                      ],
                    ),
                    if (r.regularSold != null || r.mediumSold != null || r.b1t1OrdersSold != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Sold: Reg ${r.regularSold ?? 0} · Med ${r.mediumSold ?? 0} · B1T1 ${r.b1t1OrdersSold ?? 0}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sales: ₱${r.totalSalesAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Salary: - ₱${r.computedWage.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (r.remainingStock != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.pastelBrown.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('REMAINING STOCK AT CLOSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              'Reg: ${r.remainingStock!.regular}  Med: ${r.remainingStock!.medium}  B1T1: ${r.remainingStock!.b1t1}  '
                              'Mayo: ${r.remainingStock!.mayo}  Styro: ${r.remainingStock!.styro}  Toyo: ${r.remainingStock!.toyo}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String val, IconData icon) {
    return StaffCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}
