import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Lightweight custom-painted bar chart for the Owner App Home screen.
/// Inspired by the Web Admin's SimpleBarChart but using Cupertino styling.
class OwnerSalesTrendChart extends StatelessWidget {
  const OwnerSalesTrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock weekly trend data
    final data = [4200.0, 3800.0, 5100.0, 4900.0, 6200.0, 4500.0, 7700.0];
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxVal = data.reduce((a, b) => a > b ? a : b) * 1.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Weekly Sales Trend',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '₱${data.last.toStringAsFixed(0)} today',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(data.length, (index) {
              final val = data[index];
              final ratio = val / maxVal;
              final isToday = index == data.length - 1;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FractionallySizedBox(
                          heightFactor: ratio,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.accent
                                  : AppColors.accent.withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
