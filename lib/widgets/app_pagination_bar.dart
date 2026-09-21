import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Reusable pagination bar for mobile applications (Owner, Staff, Driver, Production).
class AppPaginationBar extends StatelessWidget {
  const AppPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.pageSize = 5,
    required this.onPageChanged,
    this.alwaysShow = false,
  });

  /// Current 0-indexed page.
  final int currentPage;

  /// Total count of items.
  final int totalItems;

  /// Items per page (defaults to 5).
  final int pageSize;

  /// Callback when a page navigation is requested.
  final ValueChanged<int> onPageChanged;

  /// If false (default), hides completely when totalPages <= 1.
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / pageSize).ceil();
    if (totalPages <= 1 && !alwaysShow) {
      return const SizedBox.shrink();
    }

    final safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final safeCurrentPage = currentPage.clamp(0, safeTotalPages - 1);
    final canGoPrev = safeCurrentPage > 0;
    final canGoNext = safeCurrentPage < safeTotalPages - 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            color: canGoPrev
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.pastelBrown.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            onPressed: canGoPrev
                ? () => onPageChanged(safeCurrentPage - 1)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.chevron_left,
                  size: 14,
                  color: canGoPrev ? AppColors.accent : CupertinoColors.inactiveGray,
                ),
                const SizedBox(width: 4),
                Text(
                  'Prev',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: canGoPrev ? AppColors.accent : CupertinoColors.inactiveGray,
                  ),
                ),
              ],
            ),
          ),

          // Page indicator text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page ${safeCurrentPage + 1} of $safeTotalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$totalItems total',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Next button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            color: canGoNext
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.pastelBrown.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            onPressed: canGoNext
                ? () => onPageChanged(safeCurrentPage + 1)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: canGoNext ? AppColors.accent : CupertinoColors.inactiveGray,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: canGoNext ? AppColors.accent : CupertinoColors.inactiveGray,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
