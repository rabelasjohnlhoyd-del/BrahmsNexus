import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branch_inventory_sheet.dart';
import '../../widgets/driver_top_actions.dart';

/// Homepage tab ng Driver app — makikita LAHAT ng branches at kung
/// sinong tagaluto ang naka-assign sa bawat isa ngayong araw. Pag
/// pinindot ang isang branch, makikita kung ilang karne/mayo/styro/
/// toyo ang dapat dalhin doon.
class DriverHomepageScreen extends StatelessWidget {
  const DriverHomepageScreen({super.key});

  // Mock: employee assigned per branch id. Ilang branch ay walang
  // naka-assign (rest day / walang tauhan ngayong araw).
  static const Map<String, String> _assignedStaff = {
    'br1': 'Juan Dela Cruz',
    'br2': 'Pedro Santos',
    'br3': 'Maria Reyes',
    'br6': 'Liza Gomez',
  };

  // Mock: kailangang dalhin per branch (karne, mayo, styro, toyo).
  static const Map<String, InventoryCounts> _requiredGoods = {
    'br1': InventoryCounts(karne: 35, mayo: 40, styro: 40, toyo: 7),
    'br2': InventoryCounts(karne: 25, mayo: 28, styro: 28, toyo: 5),
    'br3': InventoryCounts(karne: 20, mayo: 22, styro: 22, toyo: 4),
    'br4': InventoryCounts(karne: 15, mayo: 18, styro: 18, toyo: 3),
    'br5': InventoryCounts(karne: 15, mayo: 18, styro: 18, toyo: 3),
    'br6': InventoryCounts(karne: 22, mayo: 25, styro: 25, toyo: 5),
  };

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Homepage'),
        trailing: DriverTopActions(initials: 'RS'),
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: kSampleBranches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final branch = kSampleBranches[index];
            final staffName = _assignedStaff[branch.id];
            final required = _requiredGoods[branch.id]!;

            return GestureDetector(
              onTap: () => showBranchInventorySheet(
                context,
                branch: branch,
                required: required,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.pastelBrown.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(CupertinoIcons.building_2_fill,
                          color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.fullName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                staffName != null
                                    ? CupertinoIcons.person_fill
                                    : CupertinoIcons.person,
                                size: 13,
                                color: staffName != null
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                staffName ?? 'Walang naka-assign ngayon',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: staffName != null
                                      ? AppColors.textSecondary
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_right,
                        size: 18, color: AppColors.pastelBrown),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
