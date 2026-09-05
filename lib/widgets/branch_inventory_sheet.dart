import 'package:flutter/cupertino.dart';
import '../models/branch.dart';
import '../models/branch_daily_inventory.dart';
import '../theme/app_theme.dart';

/// Ipinapakita kapag pinindot ang isang branch sa Homepage o Route tab
/// ng Driver app — kung ilan ang dapat dalhin na karne/mayo/styro/toyo
/// papunta doon, para maalalahanan ang mga tagaluto pag may kulang.
void showBranchInventorySheet(
  BuildContext context, {
  required Branch branch,
  required InventoryCounts required,
}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.pastelBrown,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              branch.fullName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Dapat dalhin dito',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _tile('Karne', required.karne)),
                const SizedBox(width: 10),
                Expanded(child: _tile('Mayo', required.mayo)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _tile('Styro', required.styro)),
                const SizedBox(width: 10),
                Expanded(child: _tile('Toyo', required.toyo)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

Widget _tile(String label, int value) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ],
    ),
  );
}
