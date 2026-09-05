import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Shared navigation bar for every Staff screen.
///
/// This is a plain, hand-painted [Container] — deliberately NOT a
/// [CupertinoNavigationBar]. CupertinoNavigationBar decides on its
/// own, internally, whether to render as a blurred/translucent
/// surface (based on things like background opacity and ambient
/// brightness), and in practice that still let the bar read as
/// "not solid brown" in some states — e.g. appearing to lighten or
/// wash out while scrolling. Painting it ourselves removes that
/// guesswork completely: this bar's fill is always [AppColors.accent]
/// — full stop — no matter what's scrolling underneath it, which tab
/// is active, or anything else. Every Staff screen uses this same
/// widget, so the fix is automatically consistent everywhere.
class StaffNavBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const StaffNavBar({
    super.key,
    required this.title,
    this.trailing,
    this.showBackButton = false,
  });

  final String title;
  final Widget? trailing;

  /// Set true for screens pushed on top of a tab (Notifications,
  /// Profile) so people can get back. Tab-root screens don't need it.
  final bool showBackButton;

  static const double _barContentHeight = 44;

  @override
  Size get preferredSize => const Size.fromHeight(_barContentHeight);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Widget build(BuildContext context) {
    // Extends the solid brown fill up underneath the status bar too,
    // instead of stopping at the top of the nav-bar content — so
    // there's no thin strip up top that could show the page
    // background through instead.
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
