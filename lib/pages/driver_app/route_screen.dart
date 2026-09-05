import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branch_inventory_sheet.dart';
import '../../widgets/driver_top_actions.dart';

/// Route tab — ang aktwal na pagkakasunod-sunod ng ruta ngayong araw.
///
/// NOTE: Ang pagkakasunod na ito (dailyRouteSequence) ay STATIC/MOCK
/// muna. Ang totoong "better route" na dapat i-suggest base sa address
/// ng mga tauhang naka-assign ay gagawin ng DSS sa backend phase
/// (deferred — pure frontend muna, gaya ng plano).
class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

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
    final branches = [...kSampleBranches]
      ..sort((a, b) => a.dailyRouteSequence.compareTo(b.dailyRouteSequence));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Route'),
        trailing: DriverTopActions(initials: 'RS'),
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: branches.length,
          itemBuilder: (context, index) {
            final branch = branches[index];
            final isLast = index == branches.length - 1;
            final required = _requiredGoods[branch.id]!;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${branch.dailyRouteSequence}',
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppColors.pastelBrown.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: GestureDetector(
                        onTap: () => showBranchInventorySheet(
                          context,
                          branch: branch,
                          required: required,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                    const Text(
                                      'I-tap para makita ang dapat dalhin',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(CupertinoIcons.chevron_right,
                                  size: 18, color: AppColors.pastelBrown),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
