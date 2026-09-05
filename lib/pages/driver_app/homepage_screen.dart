import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branch_inventory_sheet.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/driver_top_actions.dart';

/// Homepage tab of the Driver app — shows ALL branches and which cook
/// is assigned to each one today. Tapping a branch shows how much
/// meat/mayo/styrofoam/soy sauce needs to be brought there.
class DriverHomepageScreen extends StatelessWidget {
  const DriverHomepageScreen({super.key});

  // Mock: employee assigned per branch id. Some branches have no one
  // assigned (rest day / no staff scheduled today).
  static const Map<String, String> _assignedStaff = {
    'br1': 'Juan Dela Cruz',
    'br2': 'Pedro Santos',
    'br3': 'Maria Reyes',
    'br6': 'Liza Gomez',
  };

  // Mock: items to bring per branch (meat, mayo, styrofoam, soy sauce).
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
      navigationBar: const DriverNavBar(
        title: 'Homepage',
        trailing: DriverTopActions(initials: 'RS'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const DriverSectionHeader(
              label: "Today's Branches",
              icon: CupertinoIcons.building_2_fill,
            ),
            const SizedBox(height: 10),
            ...kSampleBranches.map((branch) {
              final staffName = _assignedStaff[branch.id];
              final required = _requiredGoods[branch.id]!;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => showBranchInventorySheet(
                    context,
                    branch: branch,
                    required: required,
                  ),
                  child: DriverCard(
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
                                  Expanded(
                                    child: Text(
                                      staffName ?? 'No staff assigned yet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: staffName != null
                                            ? AppColors.textSecondary
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(CupertinoIcons.chevron_right,
                            size: 18, color: AppColors.pastelBrown),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
