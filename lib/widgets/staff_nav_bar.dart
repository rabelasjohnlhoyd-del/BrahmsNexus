import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Which layout [StaffNavBar] renders. Every Staff screen uses the
/// same gradient fill either way — only the content inside changes —
/// so the whole section reads as one consistent header treatment
/// instead of "Home has its own header design".
enum StaffHeaderMode {
  /// Simple centered title, used by every screen except Home
  /// (Sales, Report, Timer, Notifications, Profile).
  compact,

  /// The bigger "Good Evening, Staff" greeting block — Home only.
  greeting,
}

/// Shared header for every Staff screen.
///
/// This is a plain, hand-painted [Container] — deliberately NOT a
/// [CupertinoNavigationBar]. CupertinoNavigationBar decides on its
/// own, internally, whether to render as a blurred/translucent
/// surface (based on things like background opacity and ambient
/// brightness), and in practice that still let the bar read as
/// "not solid brown" in some states — e.g. appearing to lighten or
/// wash out while scrolling. Painting it ourselves removes that
/// guesswork completely: this bar's fill is always the same
/// [AppColors.headerStart] → [AppColors.headerEnd] gradient — full
/// stop — no matter what's scrolling underneath it, which tab is
/// active, or anything else. Every Staff screen uses this same
/// widget, so the fix (and the look) is automatically consistent
/// everywhere.
class StaffNavBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const StaffNavBar({
    super.key,
    required this.title,
    this.trailing,
    this.showBackButton = false,
    this.mode = StaffHeaderMode.compact,
    this.greetingName = 'Staff',
  });

  final String title;
  final Widget? trailing;

  /// Set true for screens pushed on top of a tab (Notifications,
  /// Profile) so people can get back. Tab-root screens don't need it.
  final bool showBackButton;

  final StaffHeaderMode mode;

  /// Name shown in the greeting block, e.g. "Good Evening, Staff".
  /// Only used when [mode] is [StaffHeaderMode.greeting].
  final String greetingName;

  static const double _compactHeight = 56;
  static const double _greetingHeight = 56;

  @override
  Size get preferredSize => Size.fromHeight(
        mode == StaffHeaderMode.greeting ? _greetingHeight : _compactHeight,
      );

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    // Extends the gradient fill up underneath the status bar too,
    // instead of stopping at the top of the header content — so
    // there's no thin strip up top that could show the page
    // background through instead.
    final topInset = MediaQuery.of(context).padding.top;
    final contentHeight =
        mode == StaffHeaderMode.greeting ? _greetingHeight : _compactHeight;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerStart, AppColors.headerEnd],
        ),
      ),
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: contentHeight,
        child: Stack(
          children: [
            // Soft decorative circles for depth, echoing the
            // reference design's subtle top-right glow — pure
            // shapes, no image assets required.
            Positioned(
              right: -36,
              top: -36,
              child: _decorCircle(120),
            ),
            Positioned(
              right: 36,
              bottom: -46,
              child: _decorCircle(90),
            ),
            Positioned.fill(
              child: mode == StaffHeaderMode.greeting
                  ? _buildGreeting(context)
                  : _buildCompact(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CupertinoColors.white.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return _buildHeaderContent(context, title, showBack: showBackButton);
  }

  Widget _buildGreeting(BuildContext context) {
    // Home greeting header — now simplified to match the compact
    // style, keeping everything clean and consistent.
    final label = '${_greetingPrefix()}, $greetingName';
    return _buildHeaderContent(context, label, showBack: false);
  }

  Widget _buildHeaderContent(
    BuildContext context,
    String label, {
    required bool showBack,
  }) {
    // A Stack with Center ensures the title is ALWAYS mathematically
    // centered relative to the screen width, completely independent
    // of whatever icons are in the side slots.
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
        if (showBack)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: CupertinoButton(
                padding: const EdgeInsets.all(8),
                minimumSize: Size.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  CupertinoIcons.back,
                  color: CupertinoColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        if (trailing != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: trailing!,
            ),
          ),
      ],
    );
  }
}
