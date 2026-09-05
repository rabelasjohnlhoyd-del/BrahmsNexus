import 'package:flutter/material.dart';
import '../../../models/staff_member.dart';
import '../../../theme/app_theme.dart';
import 'add_staff_screen.dart';

/// Admin-only screen for viewing and managing staff/employee accounts.
///
/// Front-end only for now: staff records live in local state, seeded
/// with a couple of sample entries. Once Firebase is connected, this
/// will stream from Firestore instead of using [_staff].
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final List<StaffMember> _staff = [
    StaffMember(
      id: 'sample-1',
      fullName: 'Maria Santos',
      username: 'maria.santos',
      branch: 'Main Branch',
      position: 'Cashier',
      email: 'maria.santos@example.com',
    ),
    StaffMember(
      id: 'sample-2',
      fullName: 'Juan Dela Cruz',
      username: 'juan.delacruz',
      branch: 'Branch 2',
      position: 'Cook',
      isActive: false,
    ),
  ];

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StaffMember> get _filteredStaff {
    if (_query.trim().isEmpty) return _staff;
    final q = _query.trim().toLowerCase();
    return _staff.where((s) {
      return s.fullName.toLowerCase().contains(q) ||
          s.username.toLowerCase().contains(q) ||
          s.branch.toLowerCase().contains(q) ||
          s.position.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openAddStaff() async {
    final result = await Navigator.of(context).push<StaffMember>(
      MaterialPageRoute(builder: (_) => const AddStaffScreen()),
    );

    if (result == null || !mounted) return;

    setState(() => _staff.insert(0, result));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.fullName} was added successfully.')),
    );
  }

  void _toggleStatus(StaffMember member) {
    setState(() {
      final index = _staff.indexWhere((s) => s.id == member.id);
      if (index == -1) return;
      _staff[index] = member.copyWith(isActive: !member.isActive);
    });
  }

  Future<void> _confirmRemove(StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff Account'),
        content: Text(
          'Are you sure you want to remove ${member.fullName}\'s account? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _staff.removeWhere((s) => s.id == member.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.fullName} was removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = _filteredStaff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add staff account',
            onPressed: _openAddStaff,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search by name, username, branch, or position',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: staff.isEmpty
                  ? _EmptyState(hasQuery: _query.isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: staff.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final member = staff[index];
                        return _StaffTile(
                          member: member,
                          onToggleStatus: () => _toggleStatus(member),
                          onRemove: () => _confirmRemove(member),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStaff,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Staff'),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.onToggleStatus,
    required this.onRemove,
  });

  final StaffMember member;
  final VoidCallback onToggleStatus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              child: Text(
                member.initials,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusChip(isActive: member.isActive),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${member.username}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _InfoPill(
                        icon: Icons.store_mall_directory_outlined,
                        label: member.branch,
                      ),
                      _InfoPill(
                        icon: Icons.work_outline,
                        label: member.position,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle') onToggleStatus();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    member.isActive ? 'Deactivate Account' : 'Activate Account',
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove Account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.people_outline,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'No staff match your search.'
                  : 'No staff accounts yet.\nTap "Add Staff" to create one.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
