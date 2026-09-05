import 'package:flutter/cupertino.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_top_actions.dart';

/// Sales tab — hindi na kailangang isulat ulit ang allocated inventory
/// (galing na sa Homepage), sapat na ang natitirang stock sa dulo ng
/// araw. Awtomatikong nakukwenta: orders sold (base sa Karne usage),
/// Sales, Wage (tiered rate ni Owner), at Net Total. May cross-check
/// din laban sa Styro usage para ma-detect agad kung may discrepancy —
/// direktang tumutugon ito sa dating problema ni Owner na mahirap
/// i-track ang mga hindi-pagkakatugma.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // Galing sa Homepage — mock lang muna dito, iisang shared source
  // once naka-backend na.
  static const _allocated =
      InventoryCounts(karne: 35, mayo: 40, styro: 40, toyo: 7);

  // TODO(backend): dapat editable ni Owner sa Admin Web (hindi
  // hardcoded) — hindi pa raw nagbabago mula nung nagsimula, pero
  // dapat pa rin settable.
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

  void _submit() {
    setState(() => _submitted = true);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: Text(
          _computation!.hasDiscrepancy
              ? 'Naisumite na, pero may na-flag na discrepancy — '
                  'aabisuhan si Owner.'
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sales'),
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('Inventory Ngayong Araw (galing sa Homepage)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _displayTile('Karne', '${_allocated.karne}')),
                const SizedBox(width: 12),
                Expanded(child: _displayTile('Mayo', '${_allocated.mayo}')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _displayTile('Styro', '${_allocated.styro}')),
                const SizedBox(width: 12),
                Expanded(child: _displayTile('Toyo', '${_allocated.toyo}')),
              ],
            ),
            const SizedBox(height: 20),
            _sectionLabel('Natitirang Stock (End of Day)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _inputTile('Karne', _karneController)),
                const SizedBox(width: 12),
                Expanded(child: _inputTile('Mayo', _mayoController)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _inputTile('Styro', _styroController)),
                const SizedBox(width: 12),
                Expanded(child: _inputTile('Toyo', _toyoController)),
              ],
            ),
            const SizedBox(height: 16),
            if (computation != null) ...[
              if (computation.hasDiscrepancy)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'May Discrepancy: Karne usage '
                          '(${computation.karneUsed}) ay hindi tugma sa '
                          'Styro usage (${computation.styroUsed}). '
                          'Aabisuhan si Owner.',
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
              _sectionLabel('Computation'),
              const SizedBox(height: 8),
              _card(
                child: Column(
                  children: [
                    _computedRow('Orders Sold', '${computation.ordersSold}'),
                    _computedRow(
                      'Sales',
                      '${computation.ordersSold} × ₱${_pricePerOrder.toStringAsFixed(0)} '
                          '= ₱${computation.salesAmount.toStringAsFixed(0)}',
                    ),
                    _computedRow('Wage (Sahod)',
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
              CupertinoButton(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
                onPressed: _submitted ? null : _submit,
                child: Text(_submitted ? 'Submitted' : 'Submit Sales'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Punan muna ang lahat ng natitirang stock para makita '
                  'ang computation.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _tileHeader(String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.pastelBrown.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Text(
            label[0],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _displayTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tileHeader(label),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputTile(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tileHeader(label),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '0',
            textAlign: TextAlign.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            style: const TextStyle(fontSize: 16),
            onChanged: (_) => setState(() {}),
          ),
        ],
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

/// Simpleng divider — walang built-in Divider widget ang Cupertino.
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
