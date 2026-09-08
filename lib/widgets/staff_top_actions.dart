import 'package:flutter/cupertino.dart';
import '../pages/staff_app/notifications_screen.dart';
import '../theme/app_theme.dart';

/// Shared trailing actions for every tab of the Cook/Staff app:
/// notification bell (left) + profile avatar (right). This replaces
/// the old, separate "Announcements" tab.
///
/// Colors here are white/inverted because this sits on top of the
/// solid accent-brown [StaffNavBar] — see that file for why the bar
/// is a solid color instead of the previous translucent white one.
class StaffTopActions extends StatelessWidget {
  const StaffTopActions({
    super.key,
    this.hasUnread = true,
  });

  /// Shows a small dot on the bell when there are unread
  /// announcements. Defaults to true until this is wired to real
  /// notification data.
  final bool hasUnread;


  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            CupertinoIcons.bell_fill,
            color: CupertinoColors.white,
            size: 24,
          ),
          if (hasUnread)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.headerStart, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
