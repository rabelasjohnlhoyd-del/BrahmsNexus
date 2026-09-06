import 'package:flutter/cupertino.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_stat_tile.dart';
import '../../widgets/staff_top_actions.dart';

/// Homepage tab of the Cook/Staff app:
/// 1. Shows which branch Owner assigned them to today.
/// 2. Shows the inventory (Karne/Mayo/Styro/Toyo) Owner says was sent —
///    this is the "allocated" amount that needs to be verified.
/// 3. Cook counts what they actually received and enters it here.
/// 4. If it matches -> only Confirm is enabled. If it doesn't match
///    (too much or too little) -> only Deny is enabled, then they type
///    a message to Owner about the shortfall. NON-BLOCKING: they can
///    still continue to the Sales tab even while the status is
///    "Discrepancy Reported" — Owner handles sending extra stock.
/// 5. Also shows other cooks assigned to other branches today.
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

  /// Confirm only unlocks when the input is complete AND matches the
  /// allocated amount.
  bool get _canConfirm => _hasEnteredCount && _countsMatch;

  /// Deny only unlocks when the input is complete but does NOT match
  /// (too much or too little) the allocated amount.
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
        title: const Text("What's missing or extra?"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _discrepancyController,
            placeholder: 'e.g., 5kg short on Karne...',
            maxLines: 3,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            placeholderStyle: const TextStyle(color: AppColors.textSecondary),
            style: const TextStyle(color: AppColors.textPrimary),
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
              _showToast('Your report has been sent to the Owner.');
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

  IconData _statusIcon(InventoryVerificationStatus status) {
    switch (status) {
      case InventoryVerificationStatus.pending:
        return CupertinoIcons.clock_fill;
      case InventoryVerificationStatus.confirmed:
        return CupertinoIcons.check_mark_circled_solid;
      case InventoryVerificationStatus.discrepancyReported:
        return CupertinoIcons.exclamationmark_circle_fill;
    }
  }

  String _statusSubtitle(InventoryVerificationStatus status) {
    switch (status) {
      case InventoryVerificationStatus.pending:
        return 'Enter all four counts above, then confirm or report a mismatch.';
      case InventoryVerificationStatus.confirmed:
        return 'Your count matches what Owner sent — you\'re good to go.';
      case InventoryVerificationStatus.discrepancyReported:
        final note = _inventory.discrepancyNote;
        return (note != null && note.isNotEmpty)
            ? 'Sent to Owner: "$note"'
            : 'Owner has been notified. You can still continue to Sales.';
    }
  }

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  Widget _dateChip() {
    final now = DateTime.now();
    final label = '${_months[now.month - 1]} ${now.day}, ${now.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pastelBrown.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.calendar, size: 12, color: AppColors.accentDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accentDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _inventory.allocated;
    final status = _inventory.status;
    final statusColor = _statusColor(status);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Homepage',
        mode: StaffHeaderMode.greeting,
        greetingName: 'Staff',
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Branch selector pill
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDark.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.location_solid,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _inventory.branchName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_right,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Allocated inventory — 2x2 grid
            StaffSectionHeader(
              label: "Today's Allocated Inventory",
              icon: CupertinoIcons.cube_box_fill,
              subtitle: 'Quick overview of your assigned items',
              large: true,
              trailing: _dateChip(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: StaffDisplayTile(label: 'Karne', value: '${a.karne}')),
                const SizedBox(width: 12),
                Expanded(child: StaffDisplayTile(label: 'Mayo', value: '${a.mayo}', dark: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StaffDisplayTile(label: 'Styro', value: '${a.styro}')),
                const SizedBox(width: 12),
                Expanded(child: StaffDisplayTile(label: 'Toyo', value: '${a.toyo}', dark: true)),
              ],
            ),
            const SizedBox(height: 26),

            // Recount — 2x2 grid of input fields
            const StaffSectionHeader(
              label: 'Verify: Count What You Actually Received',
              icon: CupertinoIcons.checkmark_seal_fill,
              subtitle: 'Enter the actual count of items you received',
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
            const SizedBox(height: 16),

            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(status), size: 18, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusSubtitle(status),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StaffButton(
                    label: 'Confirm',
                    icon: CupertinoIcons.checkmark_alt,
                    color: AppColors.success,
                    onPressed: _canConfirm ? _confirm : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaffButton(
                    label: 'Deny',
                    icon: CupertinoIcons.xmark,
                    color: AppColors.error,
                    onPressed: _canDeny ? _showDenyDialog : null,
                  ),
                ),
              ],
            ),
            if (!_hasEnteredCount) ...[
              const SizedBox(height: 8),
              const Text(
                'Enter all four counts above to enable Confirm or Deny.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 26),

            // Co-workers
            const StaffSectionHeader(
              label: 'Coworkers Today',
              icon: CupertinoIcons.person_2_fill,
            ),
            const SizedBox(height: 10),
            ..._coworkers.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StaffCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.pastelBrown.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.person_fill,
                            size: 15, color: AppColors.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c['name']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pastelBrown.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c['branch']!,
                          style: const TextStyle(
                            color: AppColors.accentDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
