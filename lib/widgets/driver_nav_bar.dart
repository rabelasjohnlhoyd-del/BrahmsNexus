import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Which layout [DriverNavBar] renders. Mirrors
/// widgets/staff_nav_bar.dart's [StaffHeaderMode] so both apps share
/// the exact same header language — every screen uses the same
/// gradient fill either way, only the content inside changes.
enum DriverHeaderMode {
  /// Simple centered title, used by every screen except Home
  /// (Route, Stock Transfer, Bilao Deliveries, Notifications,
  /// Profile, and detail screens).
  compact,

  /// The bigger "Good Evening, Driver" greeting block — Home only.
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
    this.greetingName = 'Driver',
  });

  final String title;
  final Widget? trailing;

  /// Set true for screens pushed on top of a tab (Notifications,
  /// Profile, delivery/transfer detail) so people can get back.
  /// Tab-root screens don't need it.
  final bool showBackButton;

  final DriverHeaderMode mode;

  /// Name shown in the greeting block, e.g. "Good Evening, Driver".
  /// Only used when [mode] is [DriverHeaderMode.greeting].
  final String greetingName;

  static const double _compactHeight = 44;
  static const double _greetingHeight = 128;

  @override
  Size get preferredSize => Size.fromHeight(
        mode == DriverHeaderMode.greeting ? _greetingHeight : _compactHeight,
      );

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formattedToday() {
    final now = DateTime.now();
    return '${_months[now.month - 1]} ${now.day}, ${now.year}';
  }

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
            if (mode == DriverHeaderMode.greeting)
              _buildGreeting(context)
            else
              _buildCompact(context),
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
    // A plain three-slot Row (fixed-width leading/trailing, centered
    // title in between) instead of a Stack with Positioned back
    // button/trailing over a centered title — that previous approach
    // let the title run full-width behind the icons, so a longer
    // title (or the trailing bell + avatar) could visually collide
    // with the back button. A Row with fixed-width side slots is
    // deterministic: both slots always reserve their own space, so
    // nothing can shift or overlap between screens.
    //
    // IMPORTANT: the two slots are NOT the same width. The leading
    // slot only ever holds a single back-chevron icon (~26px), but
    // the trailing slot holds [DriverTopActions] — a notification
    // bell + a 32px avatar with a gap between them, which needs much
    // more room than that. Sizing the trailing slot to actually fit
    // [DriverTopActions] keeps it from ever spilling toward the title
    // or the back button.
    const leadingSlotWidth = 44.0;
    const trailingSlotWidth = 84.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: leadingSlotWidth,
            child: showBackButton
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      CupertinoIcons.back,
                      color: CupertinoColors.white,
                      size: 26,
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          SizedBox(
            width: trailingSlotWidth,
            child: trailing != null
                ? Align(alignment: Alignment.centerRight, child: trailing)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_greetingPrefix()},',
            style: TextStyle(
              color: CupertinoColors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                greetingName,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Text('🚚', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 14,
                color: CupertinoColors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                _formattedToday(),
                style: TextStyle(
                  color: CupertinoColors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
