import 'package:flutter/material.dart';
import '../../../models/financial_period.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/procurement_list.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';

class MonthlyFinancialsScreen extends StatefulWidget {
  const MonthlyFinancialsScreen({super.key, this.karneBatches = const []});

  /// Live batches from the Warehouse tab (InventoryScreen). Production
  /// pcs for the period is derived from these instead of being typed
  /// in separately, so the two tabs can't drift out of sync.
  final List<KarneBatch> karneBatches;

  @override
  State<MonthlyFinancialsScreen> createState() => _MonthlyFinancialsScreenState();
}

class _MonthlyFinancialsScreenState extends State<MonthlyFinancialsScreen> {
  late FinancialPeriod _period;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(covariant MonthlyFinancialsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recompute productionPcs from the latest batches every time the
    // parent (InventoryScreen) rebuilds this widget — cheap sum over a
    // short list, and avoids relying on List identity/equality (the
    // parent mutates its list in place, so reference comparison here
    // would silently miss real changes). Everything else the user has
    // already edited on this screen (procurement items, labor days,
    // overheads) is preserved as-is.
    setState(() {
      _period = FinancialPeriod(
        id: _period.id,
        monthName: _period.monthName,
        year: _period.year,
        productionPcs: _totalPcsFromBatches(),
        productionLaborDays: _period.productionLaborDays,
        dailyOverheads: _period.dailyOverheads,
        procurementGroups: _period.procurementGroups,
      );
    });
  }

  int _totalPcsFromBatches() =>
      widget.karneBatches.fold(0, (sum, b) => sum + b.totalPcsNagawa);

  void _initializeData() {
    final groups = [
      ProcurementGroup(id: 'pg1', title: 'LPG 6 STORE', items: [
        ProcurementItem(id: 'i1', name: 'Labuin', price: 1065, isPaid: true),
        ProcurementItem(id: 'i2', name: 'Nanhaya', price: 1065, isPaid: true),
        ProcurementItem(id: 'i3', name: 'San Francisco', price: 1065, isPaid: true),
        ProcurementItem(id: 'i4', name: 'Dayap', price: 1065, isPaid: true),
        ProcurementItem(id: 'i5', name: 'Gatid', price: 1065, isPaid: true),
        ProcurementItem(id: 'i6', name: 'Pila', price: 1065, isPaid: true),
      ]),
      ProcurementGroup(id: 'pg2', title: 'INHOUSE INGREDIENTS', items: [
        ProcurementItem(id: 'i7', name: 'Styro 30 bundle', price: 3900, isPaid: true),
        ProcurementItem(id: 'i8', name: 'Sili budget', price: 1220, isPaid: true),
        ProcurementItem(id: 'i9', name: 'Sibuyas budget', price: 5040, isPaid: true),
        ProcurementItem(id: 'i10', name: '9 box mayo', price: 10822.5, isPaid: true),
        ProcurementItem(id: 'i11', name: 'Suka 2pcs', price: 38, isPaid: true),
        ProcurementItem(id: 'i12', name: 'Ellies Toyo 2pcs', price: 204, isPaid: true),
        ProcurementItem(id: 'i13', name: 'Knorr shopee 3pcs', price: 1494, isPaid: true),
        ProcurementItem(id: 'i14', name: 'Sando bag 6000pcs', price: 600, isPaid: true),
      ]),
      ProcurementGroup(id: 'pg3', title: 'PRODUCTION INGREDIENTS & LPG BIG', items: [
        ProcurementItem(id: 'p1', name: 'Asin 380', price: 380, isPaid: true),
        ProcurementItem(id: 'p2', name: 'Laurel 200', price: 200, isPaid: true),
        ProcurementItem(id: 'p3', name: 'Datu puti 210', price: 210, isPaid: true),
        ProcurementItem(id: 'p4', name: 'Paminta online 541', price: 541, isPaid: true),
        ProcurementItem(id: 'p5', name: 'Vetsin shopee online 245', price: 245, isPaid: true),
        ProcurementItem(id: 'p6', name: 'Gasul 4650 2 set', price: 4650, isPaid: true),
      ]),
      ProcurementGroup(id: 'pg4', title: 'SECRET INGREDIENTS FOR MAYO', items: [
        ProcurementItem(id: 's1', name: 'Knorr oyster sauce 646', price: 646, isPaid: true),
        ProcurementItem(id: 's2', name: 'Paminta pino 411', price: 411, isPaid: true),
        ProcurementItem(id: 's3', name: 'Garlic powder 315', price: 315, isPaid: true),
        ProcurementItem(id: 's4', name: 'Original vetsin shopee 193.5', price: 193.5, isPaid: true),
        ProcurementItem(id: 's5', name: 'Liver spread 19pcs', price: 408.5, isPaid: true),
      ]),
    ];

    final overheads = List.generate(25, (i) => DailyOverheadEntry(
      date: DateTime.now().subtract(Duration(days: i)),
      totalStaffWages: 2210, // 3160 - 950
    ));

    _period = FinancialPeriod(
      id: 'p1',
      monthName: 'July - August',
      year: 2026,
      productionPcs: _totalPcsFromBatches(),
      productionLaborDays: 7,
      dailyOverheads: overheads,
      procurementGroups: groups,
    );
  }

  void _editItem(ProcurementGroup group, ProcurementItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.price.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Budget/Price'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.name = nameCtrl.text;
                item.price = double.tryParse(priceCtrl.text) ?? 0;
              });
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _editProductionLabor() {
    final daysCtrl = TextEditingController(text: _period.productionLaborDays.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Production Labor'),
        content: TextField(controller: daysCtrl, decoration: const InputDecoration(labelText: 'Working Days'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _period = FinancialPeriod(
                  id: _period.id,
                  monthName: _period.monthName,
                  year: _period.year,
                  productionPcs: _period.productionPcs,
                  productionLaborDays: int.tryParse(daysCtrl.text) ?? 7,
                  dailyOverheads: _period.dailyOverheads,
                  procurementGroups: _period.procurementGroups,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialOverview(),
            const SizedBox(height: 32),
            _buildProcurementSections(),
            const SizedBox(height: 32),
            _buildLaborAndOverheadSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FINANCIAL DASHBOARD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: AdminWebColors.textSecondary)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _kpiTile('Gross Revenue', '₱${_period.grossRevenue.toStringAsFixed(0)}', 'FROM ${_period.productionPcs} PCS', Icons.payments_rounded, color: AdminWebColors.success)),
            const SizedBox(width: 16),
            Expanded(child: _kpiTile('Total Expenses', '₱${_period.totalExpenses.toStringAsFixed(0)}', 'INCL. LABOR & OVERHEAD', Icons.shopping_cart_rounded, color: AdminWebColors.error)),
            const SizedBox(width: 16),
            Expanded(child: _kpiTile('NET MAV', '₱${_period.netMav.toStringAsFixed(0)}', 'NET PROFIT FOR THE PERIOD', Icons.account_balance_wallet_rounded, color: AdminWebColors.accent, isMain: true)),
          ],
        ),
      ],
    );
  }

  Widget _kpiTile(String label, String val, String sub, IconData icon, {Color? color, bool isMain = false}) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color ?? AdminWebColors.accent),
          const SizedBox(height: 16),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: isMain ? 32 : 24, fontWeight: FontWeight.w900, color: color ?? AdminWebColors.textPrimary)),
          Text(sub, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminWebColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildProcurementSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PROCUREMENT & INGREDIENTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: AdminWebColors.textSecondary)),
        const SizedBox(height: 16),
        for (var group in _period.procurementGroups) ...[
          _buildGroupCard(group),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildGroupCard(ProcurementGroup group) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: AdminWebColors.accent.withValues(alpha: 0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(group.title, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminWebColors.accent)),
                Text('CATEGORY TOTAL: ₱${group.total.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          ...group.items.map((item) => _buildItemRow(group, item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(ProcurementGroup group, ProcurementItem item) {
    return InkWell(
      onTap: () => _editItem(group, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Checkbox(
              value: item.isPaid, 
              onChanged: (v) => setState(() => item.isPaid = v!),
              activeColor: AdminWebColors.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Text('Click to edit price/name', style: TextStyle(fontSize: 10, color: AdminWebColors.textSecondary)),
                ],
              ),
            ),
            Text('₱${item.price.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: item.isPaid ? AdminWebColors.success.withValues(alpha: 0.1) : AdminWebColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(item.isPaid ? 'PAID' : 'NOT PAID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: item.isPaid ? AdminWebColors.success : AdminWebColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaborAndOverheadSection() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LABOR & STORE OVERHEAD', style: TextStyle(fontWeight: FontWeight.w900, color: AdminWebColors.accent, letterSpacing: 0.5)),
          const SizedBox(height: 20),
          
          // Production Labor
          _overheadRowWithAction(
            label: 'Production Labor (Abby & Menes)', 
            val: '₱${_period.totalProductionLaborCost.toStringAsFixed(0)}',
            sub: '${_period.productionLaborDays} working days recorded',
            onEdit: _editProductionLabor,
          ),
          const Divider(height: 32),
          
          // Daily Overhead Accumulator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Store Labor & Overheads', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Automated sum from 6 branches + fixed costs', style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                ],
              ),
              _badge('${_period.workingDaysCount.toInt()} / 25 DAYS', AdminWebColors.accent),
            ],
          ),
          const SizedBox(height: 16),
          _overheadRow('Total Staff Wages (Dynamic)', '₱${(_period.accumulatedStoreCost - (_period.workingDaysCount * 950)).toStringAsFixed(0)}'),
          _overheadRow('Total Rent & Butaw', '₱${(_period.workingDaysCount * 100).toStringAsFixed(0)}'),
          _overheadRow('Total Daddy\'s Net', '₱${(_period.workingDaysCount * 700).toStringAsFixed(0)}'),
          _overheadRow('Total Trike Gas', '₱${(_period.workingDaysCount * 150).toStringAsFixed(0)}'),
          
          const Divider(height: 40, thickness: 1.5),
          _overheadRow('OVERALL STORE COST', '₱${_period.accumulatedStoreCost.toStringAsFixed(0)}', isTotal: true),
        ],
      ),
    );
  }

  Widget _overheadRow(String label, String val, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600, fontSize: isTotal ? 16 : 13, color: isTotal ? AdminWebColors.textPrimary : AdminWebColors.textSecondary)),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isTotal ? 20 : 14, color: isTotal ? AdminWebColors.accent : AdminWebColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _overheadRowWithAction({required String label, required String val, required String sub, required VoidCallback onEdit}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(sub, style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
          ],
        ),
        Row(
          children: [
            Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AdminWebColors.textPrimary)),
            const SizedBox(width: 12),
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18, color: AdminWebColors.accent)),
          ],
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
    );
  }
}
