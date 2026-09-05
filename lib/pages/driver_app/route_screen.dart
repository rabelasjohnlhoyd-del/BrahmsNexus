import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branch_inventory_sheet.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_top_actions.dart';
import '../../widgets/driver_undo_toast.dart';

/// Route tab — the actual stop-by-stop order for today's route, with
/// each stop showing what needs to be brought and letting the driver
/// mark it as visited once they've dropped off / picked up there.
///
/// NOTE: This stop order (dailyRouteSequence) is currently a
/// static/mock default order. The real "best route" suggestion, based
/// on the addresses of staff assigned that day, will be computed by
/// the DSS backend (deferred — pure frontend for now, as planned).
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  static const Map<String, InventoryCounts> _requiredGoods = {
    'br1': InventoryCounts(karne: 35, mayo: 40, styro: 40, toyo: 7),
    'br2': InventoryCounts(karne: 25, mayo: 28, styro: 28, toyo: 5),
    'br3': InventoryCounts(karne: 20, mayo: 22, styro: 22, toyo: 4),
    'br4': InventoryCounts(karne: 15, mayo: 18, styro: 18, toyo: 3),
    'br5': InventoryCounts(karne: 15, mayo: 18, styro: 18, toyo: 3),
    'br6': InventoryCounts(karne: 22, mayo: 25, styro: 25, toyo: 5),
  };

  final Set<String> _visitedBranchIds = {};
  final Map<String, DateTime> _visitedAt = {};

  /// Total items to bring for a branch — used in the stop's subtitle
  /// so the driver sees "4 items" at a glance instead of having to
  /// open the sheet just to know there's anything to bring at all.
  int _itemCount(InventoryCounts c) {
    var count = 0;
    if (c.karne > 0) count++;
    if (c.mayo > 0) count++;
    if (c.styro > 0) count++;
    if (c.toyo > 0) count++;
    return count;
  }

  void _markVisited(String branchId) {
    setState(() {
      _visitedBranchIds.add(branchId);
      _visitedAt[branchId] = DateTime.now();
    });

    // Undo needs to survive the sheet already having closed, so it's
    // shown from the Route screen's own context, not the sheet's.
    showDriverUndoToast(
      context,
      message: 'Marked as visited',
      onUndo: () => _undoVisited(branchId),
    );
  }

  /// Reverts a stop back to "not visited" — reachable either from the
  /// toast right after marking it, or from the "Undo" action inside
  /// the sheet itself for a stop visited earlier in the day.
  void _undoVisited(String branchId) {
    setState(() {
      _visitedBranchIds.remove(branchId);
      _visitedAt.remove(branchId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final branches = [...kSampleBranches]
      ..sort((a, b) => a.dailyRouteSequence.compareTo(b.dailyRouteSequence));
    final visitedCount = _visitedBranchIds.length;
    final allDone = visitedCount == branches.length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Route',
        trailing: DriverTopActions(initials: 'RS'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress summary — replaces any ad-hoc status color with
            // a single, calm, on-brand banner instead.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: allDone
                    ? AppColors.success.withValues(alpha: 0.10)
                    : AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: allDone
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    allDone
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.map_fill,
                    color: allDone ? AppColors.success : AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allDone
                              ? 'All stops completed for today!'
                              : "Today's Route",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: allDone
                                ? AppColors.success
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$visitedCount of ${branches.length} stops visited',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(branches.length, (index) {
              final branch = branches[index];
              final isLast = index == branches.length - 1;
              final required = _requiredGoods[branch.id]!;
              final visited = _visitedBranchIds.contains(branch.id);
              final itemCount = _itemCount(required);

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
                          decoration: BoxDecoration(
                            color: visited
                                ? AppColors.success
                                : AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: visited
                              ? const Icon(
                                  CupertinoIcons.check_mark,
                                  color: CupertinoColors.white,
                                  size: 14,
                                )
                              : Text(
                                  '${branch.dailyRouteSequence}',
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        // Subtle accent-tinted connector instead of the
                        // washed-out tan line that clashed with the
                        // rest of the app's brown/white palette.
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: visited
                                  ? AppColors.success.withValues(alpha: 0.35)
                                  : AppColors.accent.withValues(alpha: 0.2),
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
                            alreadyVisited: visited,
                            visitedAt: _visitedAt[branch.id],
                            onMarkVisited: () => _markVisited(branch.id),
                            onUndoVisit: visited
                                ? () => _undoVisited(branch.id)
                                : null,
                          ),
                          child: DriverCard(
                            highlighted: visited,
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
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.cube_box_fill,
                                            size: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              itemCount == 0
                                                  ? 'Nothing to bring'
                                                  : '$itemCount item'
                                                      '${itemCount == 1 ? '' : 's'} to bring',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          if (visited) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              CupertinoIcons
                                                  .check_mark_circled_solid,
                                              size: 13,
                                              color: AppColors.success,
                                            ),
                                            const SizedBox(width: 3),
                                            const Text(
                                              'Visited',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 18,
                                  color: AppColors.accent.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
