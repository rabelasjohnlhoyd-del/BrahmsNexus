import 'package:flutter/cupertino.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Which layout [DriverNavBar] renders. Mirrors
/// widgets/staff_nav_bar.dart's [StaffHeaderMode] so both apps share
/// the exact same header language — every screen uses the same
/// gradient fill either way, only the content inside changes.
enum DriverHeaderMode {
  /// Simple centered title, used by every screen.
  compact,

  /// A slightly more prominent title for the Home screen, 
  /// but still compact and consistent with other headers.
  greeting,
}

/// Shared navigation bar for every Driver screen.
///
/// This is a plain, hand-painted [Container] — deliberately NOT a
/// [CupertinoNavigationBar]. CupertinoNavigationBar decides on its
/// own, internally, whether to render as a blurred/translucent
/// surface, which let the bar read as "not solid brown" in some
/// states (e.g. washing out while scrolling underneath it). Painting
/// it ourselves removes that guesswork: this bar's fill is always the
/// same [AppColors.headerStart] → [AppColors.headerEnd] gradient —
/// full stop — matching widgets/staff_nav_bar.dart so both apps share
/// one consistent header treatment instead of the Driver side looking
/// like a different, flatter app.
class DriverNavBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const DriverNavBar({
    super.key,
    required this.title,
    this.trailing,
    this.showBackButton = false,
    this.mode = DriverHeaderMode.compact,
    this.greetingName,
  });

  final String title;
  final Widget? trailing;

  /// Set true for screens pushed on top of a tab (Notifications,
  /// Profile, delivery/transfer detail) so people can get back.
  /// Tab-root screens don't need it.
  final bool showBackButton;

  final DriverHeaderMode mode;

  /// Name shown in the greeting block, e.g. "Good Evening, Driver".
  /// Only used when [mode] is [DriverHeaderMode.greeting]. Defaults
  /// to [AuthService.currentUsername].
  final String? greetingName;

  static const double _compactHeight = 56;
  static const double _greetingHeight = 56;

  @override
  Size get preferredSize => Size.fromHeight(
        mode == DriverHeaderMode.greeting ? _greetingHeight : _compactHeight,
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
        mode == DriverHeaderMode.greeting ? _greetingHeight : _compactHeight;

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
            // Soft decorative circles for depth — mirrors the same
            // treatment on the Staff header so both apps read as one
            // consistent design system.
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
              child: mode == DriverHeaderMode.greeting
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
    final name = greetingName ?? AuthService.currentUsername;
    final label = '${_greetingPrefix()}, $name';
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
