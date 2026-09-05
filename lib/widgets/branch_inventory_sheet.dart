import 'package:flutter/cupertino.dart';
import '../models/branch.dart';
import '../models/branch_daily_inventory.dart';
import '../theme/app_theme.dart';
import 'driver_button.dart';

/// Shown when a branch is tapped on the Driver's Homepage or Route tab
/// — how much meat/mayo/styrofoam/soy sauce should be brought there.
///
/// Two distinct modes, controlled entirely by which callbacks are
/// passed in:
///  - Homepage (view-only): pass neither [onMarkVisited] nor
///    [onUndoVisit]. The sheet becomes pure information — a plain,
///    read-only grid of quantities. No checkboxes, no actions.
///  - Route (interactive): pass [onMarkVisited]. While the stop isn't
///    visited yet, items can be tapped as "packed" while loading the
///    van. Once [alreadyVisited] is true, the checklist locks (no more
///    tapping) and, if [onUndoVisit] is supplied, an "Undo" action
///    appears so a mistaken tap can be reverted.
void showBranchInventorySheet(
  BuildContext context, {
  required Branch branch,
  required InventoryCounts required,
  bool alreadyVisited = false,
  DateTime? visitedAt,
  VoidCallback? onMarkVisited,
  VoidCallback? onUndoVisit,
}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      // Cap the sheet's height so it can never grow past the screen —
      // regardless of system font size — instead of overflowing.
      final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

      return _BranchInventorySheetContent(
        branch: branch,
        required: required,
        alreadyVisited: alreadyVisited,
        visitedAt: visitedAt,
        onMarkVisited: onMarkVisited,
        onUndoVisit: onUndoVisit,
        maxHeight: maxSheetHeight,
      );
    },
  );
}

class _BranchInventorySheetContent extends StatefulWidget {
  const _BranchInventorySheetContent({
    required this.branch,
    required this.required,
    required this.alreadyVisited,
    required this.visitedAt,
    required this.onMarkVisited,
    required this.onUndoVisit,
    required this.maxHeight,
  });

  final Branch branch;
  final InventoryCounts required;
  final bool alreadyVisited;
  final DateTime? visitedAt;
  final VoidCallback? onMarkVisited;
  final VoidCallback? onUndoVisit;
  final double maxHeight;

  @override
  State<_BranchInventorySheetContent> createState() =>
      _BranchInventorySheetContentState();
}

class _BranchInventorySheetContentState
    extends State<_BranchInventorySheetContent> {
  // Packing checklist — only ever mutable on an active (not yet
  // visited) Route stop. Not persisted; it's a one-time loading aid.
  final Set<String> _packed = {};

  /// This sheet came from the Route tab at all (view vs. action mode).
  bool get _isRouteContext => widget.onMarkVisited != null;

  /// Items can currently be tapped to toggle packed state.
  bool get _checklistInteractive => _isRouteContext && !widget.alreadyVisited;

  List<MapEntry<String, int>> get _items {
    final r = widget.required;
    return [
      if (r.karne > 0) MapEntry('Meat', r.karne),
      if (r.mayo > 0) MapEntry('Mayo', r.mayo),
      if (r.styro > 0) MapEntry('Styrofoam', r.styro),
      if (r.toyo > 0) MapEntry('Soy Sauce', r.toyo),
    ];
  }

  String _formatTime(DateTime dt) {
    final hour24 = dt.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final allPacked = items.isNotEmpty && _packed.length == items.length;

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.pastelBrown,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              _Header(
                branchName: widget.branch.fullName,
                subtitle: 'Items to bring here',
                alreadyVisited: widget.alreadyVisited,
                visitedAt: widget.visitedAt,
                onUndoVisit: widget.onUndoVisit,
                formatTime: _formatTime,
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Nothing to bring for this stop.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else ...[
                if (_isRouteContext) ...[
                  _ChecklistStatusRow(
                    interactive: _checklistInteractive,
                    locked: _isRouteContext && widget.alreadyVisited,
                    packedCount: _packed.length,
                    totalCount: items.length,
                    allPacked: allPacked,
                  ),
                  const SizedBox(height: 10),
                ],
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.05,
                  children: items.map((entry) {
                    final packed = _packed.contains(entry.key);
                    return _InventoryTile(
                      label: entry.key,
                      value: entry.value,
                      // Read-only everywhere except an active,
                      // not-yet-visited Route stop.
                      showCheckbox: _isRouteContext,
                      checked: packed,
                      interactive: _checklistInteractive,
                      onTap: _checklistInteractive
                          ? () {
                              setState(() {
                                if (packed) {
                                  _packed.remove(entry.key);
                                } else {
                                  _packed.add(entry.key);
                                }
                              });
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ],
              if (widget.onMarkVisited != null && !widget.alreadyVisited) ...[
                const SizedBox(height: 20),
                DriverButton(
                  label: 'Mark as Visited',
                  icon: CupertinoIcons.check_mark,
                  color: AppColors.success,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onMarkVisited!();
                  },
                ),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title + subtitle on the left; visited badge (with optional Undo)
/// on the right. Wraps gracefully instead of clipping/overlapping.
class _Header extends StatelessWidget {
  const _Header({
    required this.branchName,
    required this.subtitle,
    required this.alreadyVisited,
    required this.visitedAt,
    required this.onUndoVisit,
    required this.formatTime,
  });

  final String branchName;
  final String subtitle;
  final bool alreadyVisited;
  final DateTime? visitedAt;
  final VoidCallback? onUndoVisit;
  final String Function(DateTime) formatTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branchName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (alreadyVisited) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.check_mark_circled_solid,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      visitedAt != null
                          ? 'Visited ${formatTime(visitedAt!)}'
                          : 'Visited',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onUndoVisit != null) ...[
                const SizedBox(height: 6),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  onPressed: onUndoVisit,
                  child: const Text(
                    'Undo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// The small "tap to pack / X of N packed" row shown above the grid,
/// only while this is an interactive Route checklist. Switches to a
/// muted "Checklist locked" note once the stop is visited.
class _ChecklistStatusRow extends StatelessWidget {
  const _ChecklistStatusRow({
    required this.interactive,
    required this.locked,
    required this.packedCount,
    required this.totalCount,
    required this.allPacked,
  });

  final bool interactive;
  final bool locked;
  final int packedCount;
  final int totalCount;
  final bool allPacked;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Row(
        children: [
          const Icon(CupertinoIcons.lock_fill,
              size: 12.5, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          const Flexible(
            child: Text(
              'Checklist locked — this stop is already visited',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Text(
            "Tap an item once it's loaded",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: (allPacked ? AppColors.success : AppColors.accent)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$packedCount of $totalCount packed',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: allPacked ? AppColors.success : AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single quantity tile. Never uses text decoration (underline /
/// strikethrough) to show checked state — only border, fill, and a
/// trailing icon change.
class _InventoryTile extends StatelessWidget {
  const _InventoryTile({
    required this.label,
    required this.value,
    required this.showCheckbox,
    required this.checked,
    required this.interactive,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool showCheckbox;
  final bool checked;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = showCheckbox && checked;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.success.withValues(alpha: 0.08)
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.success : AppColors.border,
          width: highlighted ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: highlighted
                        ? AppColors.success
                        : AppColors.accent,
                    // Deliberately no `decoration` here — checked
                    // state is shown only via color/border/icon.
                  ),
                ),
              ],
            ),
          ),
          if (showCheckbox) ...[
            const SizedBox(width: 6),
            Icon(
              checked
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              size: 20,
              color: checked ? AppColors.success : AppColors.border,
            ),
          ],
        ],
      ),
    );

    if (!showCheckbox || !interactive) return tile;

    return GestureDetector(onTap: onTap, child: tile);
  }
}
