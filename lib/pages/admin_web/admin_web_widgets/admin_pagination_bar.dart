import 'package:flutter/material.dart';
import '../admin_web_colors.dart';

/// Standard pagination bar for Admin Web dashboard screens.
class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.pageSize = 5,
    required this.onPageChanged,
    this.alwaysShow = false,
  });

  /// Current 0-indexed page number.
  final int currentPage;

  /// Total number of items across all pages.
  final int totalItems;

  /// Items per page (default is 5).
  final int pageSize;

  /// Callback when page changes.
  final ValueChanged<int> onPageChanged;

  /// If false, widget returns SizedBox.shrink() when totalPages <= 1.
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / pageSize).ceil();
    if (totalPages <= 1 && !alwaysShow) {
      return const SizedBox.shrink();
    }

    final safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final safeCurrentPage = currentPage.clamp(0, safeTotalPages - 1);
    final canPrev = safeCurrentPage > 0;
    final canNext = safeCurrentPage < safeTotalPages - 1;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            color: AdminWebColors.textSecondary,
            disabledColor: Colors.black26,
            splashRadius: 18,
            tooltip: 'Previous Page',
            onPressed: canPrev
                ? () => onPageChanged(safeCurrentPage - 1)
                : null,
          ),
          Text(
            'Page ${safeCurrentPage + 1} of $safeTotalPages',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AdminWebColors.textSecondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            color: AdminWebColors.textSecondary,
            disabledColor: Colors.black26,
            splashRadius: 18,
            tooltip: 'Next Page',
            onPressed: canNext
                ? () => onPageChanged(safeCurrentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
