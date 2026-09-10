import 'package:flutter/material.dart';
import '../../../models/sales_record.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

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

  static const double _wideBreakpoint = 700;

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
    SalesRecord(
      id: 's3',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
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

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(SalesPayrollScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([
      OutlinedButton.icon(
        onPressed: _showSetRateDialog,
        icon: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
        label: Text(
          'RATE: ₱${_commissionRate.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
        label: const Text('EXPORT'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          elevation: 0,
        ),
      ),
    ]);
  }

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
                _updateShellActions();
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

    return Container(
      color: AdminWebColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                if (!isWide) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showSetRateDialog,
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: Text(
                            'RATE: ₱${_commissionRate.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminWebColors.accent,
                            side: const BorderSide(color: AdminWebColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payroll summary exported.')),
                          );
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 16),
                        label: const Text('EXPORT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminWebColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                isWide
                  ? Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            'Total Gross Sales',
                            '₱${_totalSales.toStringAsFixed(0)}',
                            Icons.payments_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _summaryCard(
                            'Staff Payroll (Wages)',
                            '₱${_totalWages.toStringAsFixed(0)}',
                            Icons.badge_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _summaryCard(
                            'Expected Remittance',
                            '₱${_totalRemittance.toStringAsFixed(0)}',
                            Icons.account_balance_wallet_rounded,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _summaryCard(
                          'Total Gross Sales',
                          '₱${_totalSales.toStringAsFixed(0)}',
                          Icons.payments_rounded,
                        ),
                        const SizedBox(height: 12),
                        _summaryCard(
                          'Staff Payroll (Wages)',
                          '₱${_totalWages.toStringAsFixed(0)}',
                          Icons.badge_rounded,
                        ),
                        const SizedBox(height: 12),
                        _summaryCard(
                          'Expected Remittance',
                          '₱${_totalRemittance.toStringAsFixed(0)}',
                          Icons.account_balance_wallet_rounded,
                        ),
                      ],
                    ),
              const SizedBox(height: 32),
              const Text(
                'FILTER BY BRANCH',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.0,
                  color: AdminWebColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('ALL BRANCHES'),
                      selected: _branchFilter == null,
                      onSelected: (_) => setState(() => _branchFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ...branches.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(b.toUpperCase()),
                          selected: _branchFilter == b,
                          onSelected: (_) => setState(() => _branchFilter = b),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_visibleRecords.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No sales records found for the selected filter.',
                      style: TextStyle(color: AdminWebColors.textSecondary),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _visibleRecords.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _SalesRecordCard(
                      record: _visibleRecords[index],
                      isWide: isWide,
                    );
                  },
                ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    ),
  );
}

  Widget _summaryCard(String label, String value, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AdminWebColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminWebColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Isang sales record — Row (magkatabi, 6 elements) sa malawak na
/// screen; Column na may 2x2 grid ng mini-stats sa makitid na screen
/// (phone browser) para hindi masiksik.
class _SalesRecordCard extends StatelessWidget {
  const _SalesRecordCard({required this.record, required this.isWide});

  final SalesRecord record;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final r = record;

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
            r.employeeName.substring(0, 1),
            style: const TextStyle(
              color: AdminWebColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.employeeName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              Text(
                '${r.branchName} · ${r.date.month}/${r.date.day}/${r.date.year}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AdminWebColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final stats = [
      _miniStat('PORTIONS', '${r.portionsSold}'),
      _miniStat('TOTAL SALES', '₱${r.totalSalesAmount.toStringAsFixed(0)}'),
      _miniStat('WAGE', '₱${r.computedWage.toStringAsFixed(0)}'),
      _miniStat(
        'REMITTANCE',
        '₱${r.expectedCashRemittance.toStringAsFixed(0)}',
        highlight: true,
      ),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: isWide
          ? Row(
              children: [
                Expanded(flex: 3, child: avatarAndName),
                ...stats.map((s) => Expanded(flex: 2, child: s)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                avatarAndName,
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: stats[0]),
                    Expanded(child: stats[1]),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: stats[2]),
                    Expanded(child: stats[3]),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AdminWebColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: highlight ? AdminWebColors.accent : AdminWebColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

