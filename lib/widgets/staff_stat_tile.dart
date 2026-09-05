import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Small labeled badge (initial letter in a circle) used at the top of
/// every stat tile. Pulled out of Homepage/Sales so both screens stay
/// visually identical and only need to change in one place.
class _TileHeader extends StatelessWidget {
  const _TileHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.pastelBrown.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Text(
            label[0],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Read-only stat tile (e.g. "Karne: 35" allocated by Owner).
///
/// The value sits inside its own tinted, rounded "badge" rather than
/// as plain text floating on the white card — that extra block of
/// color is what actually pulls the eye to the number first, which
/// plain bold text on white wasn't doing strongly enough.
class StaffDisplayTile extends StatelessWidget {
  const StaffDisplayTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileHeader(label: label),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.accentDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Editable stat tile — a number field the cook fills in themselves
/// (recount, end-of-day stock, etc).
class StaffInputTile extends StatelessWidget {
  const StaffInputTile({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
          width: hasValue ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileHeader(label: label),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '0',
            textAlign: TextAlign.center,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: hasValue
                  ? AppColors.accent.withValues(alpha: 0.08)
                  : AppColors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
