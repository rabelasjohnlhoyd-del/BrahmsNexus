import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Small labeled badge (initial letter in a circle) used at the top of
/// every stat tile. Pulled out of Homepage/Sales so both screens stay
/// visually identical and only need to change in one place.
class _TileHeader extends StatelessWidget {
  const _TileHeader({required this.label, this.dark = false});

  final String label;

  /// True on the alternating dark-brown tiles (see [StaffDisplayTile]).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final badgeColor = dark
        ? CupertinoColors.white.withValues(alpha: 0.22)
        : AppColors.pastelBrown.withValues(alpha: 0.3);
    final badgeTextColor = dark ? CupertinoColors.white : AppColors.accent;
    final labelColor =
        dark ? CupertinoColors.white.withValues(alpha: 0.85) : AppColors.textSecondary;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            label[0],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: badgeTextColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: labelColor,
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
  const StaffDisplayTile({
    super.key,
    required this.label,
    required this.value,
    this.dark = false,
  });

  final String label;
  final String value;

  /// Renders the tile in the solid dark-brown — white text style
  /// instead of white-card style. Used to alternate tiles in a grid
  /// for visual rhythm, matching the reference design.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? null : CupertinoColors.white,
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentDark, AppColors.accent],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: dark ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: dark ? 0.16 : 0.06),
            blurRadius: dark ? 14 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileHeader(label: label, dark: dark),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? CupertinoColors.white.withValues(alpha: 0.18)
                  : AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: dark ? CupertinoColors.white : AppColors.accentDark,
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

  void _step(int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 999999);
    controller.text = '$next';
    onChanged();
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 12, color: AppColors.accent),
      ),
    );
  }

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
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
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
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepperButton(CupertinoIcons.chevron_up, () => _step(1)),
                  const SizedBox(height: 4),
                  _stepperButton(CupertinoIcons.chevron_down, () => _step(-1)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
