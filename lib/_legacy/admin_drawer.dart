import 'package:flutter/material.dart';
import '../pages/admin_web/announcements/announcements_screen.dart';
import '../pages/admin_web/employee_reports/employee_reports_screen.dart';
import '../pages/admin_web/staff_management/staff_management_screen.dart';
import '../theme/app_theme.dart';

/// Drawer na lalabas kapag pinindot ang Burger icon sa Bottom Nav.
/// Naglalaman ng: Announcements, Staff Management, Employee Reports.
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.pastelBrown.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.pastelBrown,
                    child: Icon(Icons.menu_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Admin Menu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DrawerButton(
              icon: Icons.campaign_outlined,
              label: 'Announcements',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
                );
              },
            ),
            _DrawerButton(
              icon: Icons.groups_outlined,
              label: 'Staff Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StaffManagementScreen(),
                  ),
                );
              },
            ),
            _DrawerButton(
              icon: Icons.description_outlined,
              label: 'Employee Reports',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EmployeeReportsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerButton extends StatelessWidget {
  const _DrawerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppColors.pastelBrown.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accent),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.pastelBrown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
