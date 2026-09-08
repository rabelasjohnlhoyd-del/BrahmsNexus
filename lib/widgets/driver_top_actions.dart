import 'package:flutter/cupertino.dart';

import '../pages/driver_app/notifications_screen.dart';

import '../theme/app_theme.dart';

/// Shared trailing actions for every tab of the Driver app:
/// notification bell (for Owner announcements). Colors here are 
/// white/inverted because this sits on top of the solid gradient 
/// [DriverNavBar].
class DriverTopActions extends StatelessWidget {
  const DriverTopActions({
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
          CupertinoPageRoute(
            builder: (_) => const DriverNotificationsScreen(),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            CupertinoIcons.bell_fill,
            color: CupertinoColors.white,
            size: 22,
          ),
          if (hasUnread)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.headerStart, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
