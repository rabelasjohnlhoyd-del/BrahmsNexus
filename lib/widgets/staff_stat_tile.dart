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
        borderRadius: BorderRadius.circular(12),
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
class StaffInputTile extends StatefulWidget {
  const StaffInputTile({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.step = 1,
    this.evenOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool enabled;
  final int step;
  final bool evenOnly;

  @override
  State<StaffInputTile> createState() => _StaffInputTileState();
}

class _StaffInputTileState extends State<StaffInputTile> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && widget.evenOnly) {
      _snapToEven();
    }
  }

  void _snapToEven() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    final val = int.tryParse(text);
    if (val != null && val % 2 != 0) {
      final snapped = (val ~/ 2) * 2;
      widget.controller.text = '$snapped';
      setState(() {});
      widget.onChanged();
    }
  }

  void _step(int delta) {
    if (!widget.enabled) return;
    int current = int.tryParse(widget.controller.text) ?? 0;
    int next = current + delta;
    if (widget.evenOnly && next % 2 != 0) {
      next = delta > 0 ? (next + 1) : (next - 1);
    }
    next = next.clamp(0, 999999);
    setState(() {
      widget.controller.text = '$next';
    });
    widget.onChanged();
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: Container(
        width: 22,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.enabled
              ? AppColors.background
              : AppColors.background.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          icon,
          size: 12,
          color: widget.enabled
              ? AppColors.accent
              : AppColors.textSecondary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    final parsedVal = int.tryParse(widget.controller.text.trim());
    final isOddError = widget.evenOnly && parsedVal != null && parsedVal % 2 != 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.enabled ? CupertinoColors.white : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !widget.enabled
              ? AppColors.border.withValues(alpha: 0.6)
              : (isOddError
                  ? AppColors.error
                  : (hasValue ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border)),
          width: (hasValue || isOddError) && widget.enabled ? 1.3 : 1,
        ),
        boxShadow: widget.enabled
            ? [
                BoxShadow(
                  color: (isOddError ? AppColors.error : AppColors.accentDark).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileHeader(label: widget.label),
          if (isOddError) ...[
            const SizedBox(height: 2),
            const Text(
              'Even numbers only (0, 2, 4...)',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  readOnly: !widget.enabled,
                  keyboardType: TextInputType.number,
                  placeholder: '0',
                  textAlign: TextAlign.center,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: !widget.enabled
                        ? const Color(0xFFEEEEEE)
                        : (isOddError
                            ? AppColors.error.withValues(alpha: 0.08)
                            : (hasValue
                                ? AppColors.accent.withValues(alpha: 0.08)
                                : AppColors.background.withValues(alpha: 0.6))),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: !widget.enabled
                        ? AppColors.textSecondary
                        : (isOddError ? AppColors.error : AppColors.textPrimary),
                  ),
                  onChanged: widget.enabled
                      ? (_) {
                          setState(() {});
                          widget.onChanged();
                        }
                      : null,
                  onSubmitted: (_) {
                    if (widget.evenOnly) _snapToEven();
                  },
                  onEditingComplete: () {
                    if (widget.evenOnly) _snapToEven();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepperButton(CupertinoIcons.chevron_up, () => _step(widget.step)),
                  const SizedBox(height: 4),
                  _stepperButton(CupertinoIcons.chevron_down, () => _step(-widget.step)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
