import 'package:flutter/cupertino.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_top_actions.dart';

/// Homepage tab ng Cook/Staff app:
/// 1. Ipinapakita kung saang branch sila in-assign ni Owner ngayong araw.
/// 2. Ipinapakita ang inventory (Karne/Mayo/Styro/Toyo) na sinabi ni
///    Owner na ipinadala — ito ang "allocated" na dapat i-verify.
/// 3. Cook binibilang ulit ang aktwal na dala nila at ini-input dito.
/// 4. Kung tugma -> Confirm LANG ang bukas. Kung hindi tugma (labis man
///    o kulang) -> Deny LANG ang bukas, tapos type ng message kay Owner
///    tungkol sa kulang. NON-BLOCKING: puwede pa ring tumuloy sa Sales
///    tab kahit "Discrepancy Reported" pa ang status — si Owner na lang
///    ang magpapadala ng extra.
/// 5. Makikita rin ang ibang cooks na naka-assign sa ibang branch
///    ngayong araw.
class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  BranchDailyInventory _inventory = BranchDailyInventory(
    branchId: 'br2',
    branchName: 'Sta. Cruz',
    date: DateTime.now(),
    allocated: const InventoryCounts(karne: 35, mayo: 40, styro: 40, toyo: 7),
  );

  final _karneController = TextEditingController();
  final _mayoController = TextEditingController();
  final _styroController = TextEditingController();
  final _toyoController = TextEditingController();
  final _discrepancyController = TextEditingController();

  final List<Map<String, String>> _coworkers = const [
    {'name': 'Maria Reyes', 'branch': 'Pila'},
    {'name': 'Pedro Santos', 'branch': 'Labuin'},
    {'name': 'Liza Gomez', 'branch': 'Dayap, Calauan'},
  ];

  @override
  void dispose() {
    _karneController.dispose();
    _mayoController.dispose();
    _styroController.dispose();
    _toyoController.dispose();
    _discrepancyController.dispose();
    super.dispose();
  }

  bool get _hasEnteredCount =>
      _karneController.text.isNotEmpty &&
      _mayoController.text.isNotEmpty &&
      _styroController.text.isNotEmpty &&
      _toyoController.text.isNotEmpty;

  bool get _countsMatch {
    if (!_hasEnteredCount) return false;
    final a = _inventory.allocated;
    return int.tryParse(_karneController.text) == a.karne &&
        int.tryParse(_mayoController.text) == a.mayo &&
        int.tryParse(_styroController.text) == a.styro &&
        int.tryParse(_toyoController.text) == a.toyo;
  }

  /// Confirm ay bubukas LANG kung kumpleto ang input AT tugma sa
  /// allocated.
  bool get _canConfirm => _hasEnteredCount && _countsMatch;

  /// Deny ay bubukas LANG kung kumpleto ang input pero HINDI tugma
  /// (labis man o kulang) sa allocated.
  bool get _canDeny => _hasEnteredCount && !_countsMatch;

  void _confirm() {
    setState(() {
      _inventory = _inventory.copyWith(
        status: InventoryVerificationStatus.confirmed,
      );
    });
    _showToast('Inventory confirmed!');
  }

  Future<void> _showDenyDialog() async {
    _discrepancyController.clear();
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Anong kulang?'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _discrepancyController,
            placeholder: 'Hal.: 5kg meron sa Karne na kulang...',
            maxLines: 3,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              setState(() {
                _inventory = _inventory.copyWith(
                  status: InventoryVerificationStatus.discrepancyReported,
                  discrepancyNote: _discrepancyController.text.trim(),
                );
              });
              Navigator.of(dialogContext).pop();
              _showToast('Naipadala kay Owner ang report mo.');
            },
            child: const Text('Send to Owner'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoActionSheet(
        message: Text(message),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ),
    );
  }

  Color _statusColor(InventoryVerificationStatus status) {
    switch (status) {
      case InventoryVerificationStatus.pending:
        return AppColors.warning;
      case InventoryVerificationStatus.confirmed:
        return AppColors.success;
      case InventoryVerificationStatus.discrepancyReported:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _inventory.allocated;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Homepage'),
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Assigned branch
            _card(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.pastelBrown.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.building_2_fill,
                        color: AppColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Branch Today',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _inventory.branchName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Allocated inventory — 2x2 grid
            _sectionLabel('Inventory na ipinadala ni Owner'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _displayTile('Karne', '${a.karne}')),
                const SizedBox(width: 12),
                Expanded(child: _displayTile('Mayo', '${a.mayo}')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _displayTile('Styro', '${a.styro}')),
                const SizedBox(width: 12),
                Expanded(child: _displayTile('Toyo', '${a.toyo}')),
              ],
            ),
            const SizedBox(height: 22),

            // Recount — 2x2 grid ng input fields
            _sectionLabel('I-verify: Bilangin ang aktwal na dala mo'),
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
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor(_inventory.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _inventory.status == InventoryVerificationStatus.confirmed
                        ? CupertinoIcons.check_mark_circled_solid
                        : _inventory.status ==
                                InventoryVerificationStatus
                                    .discrepancyReported
                            ? CupertinoIcons.exclamationmark_circle_fill
                            : CupertinoIcons.clock_fill,
                    size: 16,
                    color: _statusColor(_inventory.status),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _inventory.status.label,
                    style: TextStyle(
                      color: _statusColor(_inventory.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _canConfirm ? _confirm : null,
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _canDeny ? _showDenyDialog : null,
                    child: const Text('Deny'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Co-workers
            _sectionLabel('Kasamahan Ngayon'),
            const SizedBox(height: 10),
            ..._coworkers.map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.person_fill,
                        size: 18, color: AppColors.pastelBrown),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c['name']!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      c['branch']!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
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

  /// Read-only tile — para sa "allocated" na inventory (galing kay Owner).
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

  /// Input tile — para sa recount na ini-encode ng cook.
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
}
