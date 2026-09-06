import 'package:flutter/cupertino.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_stat_tile.dart';
import '../../widgets/staff_top_actions.dart';

/// Sales tab — no need to re-enter the allocated inventory (that came
/// from Homepage already); this just needs the remaining stock at the
/// end of the day. Orders sold, Sales, Wage (Owner's tiered rate), and
/// Net Total are all computed automatically. There's also a
/// cross-check against Styro usage to catch discrepancies early —
/// this directly addresses Owner's old problem of mismatches being
/// hard to track down.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // From Homepage — mocked here for now, will be a single shared
  // source once the backend is wired up.
  static const _allocated =
      InventoryCounts(karne: 35, mayo: 40, styro: 40, toyo: 7);

  // TODO(backend): should be editable by Owner in Admin Web (not
  // hardcoded) — hasn't changed since launch, but should stay settable.
  static const double _pricePerOrder = 130;

  final _karneController = TextEditingController();
  final _mayoController = TextEditingController();
  final _styroController = TextEditingController();
  final _toyoController = TextEditingController();

  bool _submitted = false;

  @override
  void dispose() {
    _karneController.dispose();
    _mayoController.dispose();
    _styroController.dispose();
    _toyoController.dispose();
    super.dispose();
  }

  bool get _hasAllInputs =>
      _karneController.text.isNotEmpty &&
      _mayoController.text.isNotEmpty &&
      _styroController.text.isNotEmpty &&
      _toyoController.text.isNotEmpty;

  DailySalesComputation? get _computation {
    if (!_hasAllInputs) return null;
    final karne = int.tryParse(_karneController.text);
    final mayo = int.tryParse(_mayoController.text);
    final styro = int.tryParse(_styroController.text);
    final toyo = int.tryParse(_toyoController.text);
    if (karne == null || mayo == null || styro == null || toyo == null) {
      return null;
    }
    return DailySalesComputation(
      allocated: _allocated,
      remaining: InventoryCounts(
        karne: karne,
        mayo: mayo,
        styro: styro,
        toyo: toyo,
      ),
      pricePerOrder: _pricePerOrder,
    );
  }

  /// Confirms before actually submitting — sales figures feed directly
  /// into payroll, so a single accidental tap on "Submit Sales"
  /// shouldn't be enough to lock them in.
  Future<void> _confirmSubmit() async {
    final computation = _computation;
    if (computation == null) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Submit Sales?'),
        content: Text(
          computation.hasDiscrepancy
              ? 'A discrepancy was found between Karne and Styro usage. '
                  'The Owner will be notified. Submit anyway?'
              : 'Orders Sold: ${computation.ordersSold} · Net Total: '
                  '\u20b1${computation.netTotal.toStringAsFixed(0)}. This '
                  "can't be edited once submitted.",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            isDestructiveAction: computation.hasDiscrepancy,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    _submit();
  }

  void _submit() {
    setState(() => _submitted = true);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: Text(
          _computation!.hasDiscrepancy
              ? 'Submitted, but a discrepancy was flagged — the Owner '
                  'will be notified.'
              : 'Sales submitted!',
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final computation = _computation;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Sales',
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StaffSectionHeader(
              label: "Today's Inventory",
              icon: CupertinoIcons.cube_box_fill,
              subtitle: 'Reference only — confirmed back on Home',
              large: true,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: StaffDisplayTile(label: 'Karne', value: '${_allocated.karne}')),
                const SizedBox(width: 12),
                Expanded(child: StaffDisplayTile(label: 'Mayo', value: '${_allocated.mayo}', dark: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StaffDisplayTile(label: 'Styro', value: '${_allocated.styro}')),
                const SizedBox(width: 12),
                Expanded(child: StaffDisplayTile(label: 'Toyo', value: '${_allocated.toyo}', dark: true)),
              ],
            ),
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Remaining Stock',
              icon: CupertinoIcons.archivebox_fill,
              subtitle: 'What\'s left at the end of the day',
              large: true,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StaffInputTile(
                    label: 'Karne',
                    controller: _karneController,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaffInputTile(
                    label: 'Mayo',
                    controller: _mayoController,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StaffInputTile(
                    label: 'Styro',
                    controller: _styroController,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaffInputTile(
                    label: 'Toyo',
                    controller: _toyoController,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (computation != null) ...[
              if (computation.hasDiscrepancy)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Discrepancy found: Karne usage '
                          '(${computation.karneUsed}) does not match '
                          'Styro usage (${computation.styroUsed}). '
                          'The Owner will be notified.',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const StaffSectionHeader(
                label: 'Computation',
                icon: CupertinoIcons.money_dollar_circle_fill,
              ),
              const SizedBox(height: 10),
              StaffCard(
                child: Column(
                  children: [
                    _computedRow('Orders Sold', '${computation.ordersSold}'),
                    _computedRow(
                      'Sales',
                      '${computation.ordersSold} × ₱${_pricePerOrder.toStringAsFixed(0)} '
                          '= ₱${computation.salesAmount.toStringAsFixed(0)}',
                    ),
                    _computedRow('Wage',
                        '- ₱${computation.wage.toStringAsFixed(0)}'),
                    const _CupertinoDivider(),
                    _computedRow(
                      'TOTAL',
                      '₱${computation.netTotal.toStringAsFixed(0)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StaffButton(
                label: _submitted ? 'Submitted' : 'Submit Sales',
                icon: _submitted ? CupertinoIcons.check_mark : null,
                onPressed: _submitted ? null : _confirmSubmit,
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.pastelBrown.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.info_circle_fill,
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fill in all remaining stock counts above to see '
                        'the computation.',
                        style: const TextStyle(color: AppColors.textSecondary),
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

  Widget _computedRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple divider — Cupertino has no built-in Divider widget.
class _CupertinoDivider extends StatelessWidget {
  const _CupertinoDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: AppColors.border,
    );
  }
}
