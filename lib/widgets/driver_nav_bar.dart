import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Shared navigation bar for every Driver screen.
///
/// This is a plain, hand-painted [Container] — deliberately NOT a
/// [CupertinoNavigationBar]. CupertinoNavigationBar decides on its
/// own, internally, whether to render as a blurred/translucent
/// surface, which let the bar read as "not solid brown" in some
/// states (e.g. washing out while scrolling underneath it). Painting
/// it ourselves removes that guesswork: this bar's fill is always
/// [AppColors.accent] — full stop. Mirrors widgets/staff_nav_bar.dart
/// so both apps share the exact same header treatment.
class DriverNavBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const DriverNavBar({
    super.key,
    required this.title,
    this.trailing,
    this.showBackButton = false,
  });

  final String title;
  final Widget? trailing;

  /// Set true for screens pushed on top of a tab (Notifications,
  /// Profile, delivery/transfer detail) so people can get back.
  /// Tab-root screens don't need it.
  final bool showBackButton;

  static const double _barContentHeight = 44;

  @override
  Size get preferredSize => const Size.fromHeight(_barContentHeight);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Widget build(BuildContext context) {
    // Extends the solid brown fill up underneath the status bar too,
    // instead of stopping at the top of the nav-bar content.
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      color: AppColors.accent,
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: _barContentHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            if (showBackButton)
              Positioned(
                left: 0,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Icon(
                    CupertinoIcons.back,
                    color: CupertinoColors.white,
                    size: 26,
                  ),
                ),
              ),
            if (trailing != null)
              Positioned(
                right: 16,
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
