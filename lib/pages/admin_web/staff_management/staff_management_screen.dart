import 'package:flutter/material.dart';
import '../../../models/staff_member.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import 'add_staff_screen.dart';
import 'edit_staff_screen.dart';

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
  // Seeded from the shared kSampleStaff directory (models/staff_member.dart)
  // so this list stays in sync with the Owner app's Assignments tab —
  // previously this had its own separate hardcoded entries.
  final List<StaffMember> _staff = List<StaffMember>.from(kSampleStaff);

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
      MaterialPageRoute(builder: (context) => const AddStaffScreen()),
    );

    if (!mounted) return;
    _updateShellActions();

    if (result == null) return;

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

  Future<void> _openEditStaff(StaffMember member) async {
    final result = await Navigator.of(context).push<StaffMember>(
      MaterialPageRoute(builder: (context) => EditStaffScreen(member: member)),
    );

    if (!mounted) return;
    _updateShellActions();

    if (result == null) return;

    setState(() {
      final index = _staff.indexWhere((s) => s.id == member.id);
      if (index != -1) _staff[index] = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.fullName} was updated.')),
    );
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
            style: TextButton.styleFrom(foregroundColor: AdminWebColors.error),
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
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(StaffManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([
      ElevatedButton.icon(
        onPressed: _openAddStaff,
        icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
        label: const Text('ADD STAFF'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          elevation: 0,
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final staff = _filteredStaff;

    return Container(
      color: AdminWebColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'SEARCH BY NAME, USERNAME, BRANCH, OR POSITION',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: staff.isEmpty
                ? _EmptyState(hasQuery: _query.isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: staff.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = staff[index];
                      return _StaffTile(
                        member: member,
                        onEdit: () => _openEditStaff(member),
                        onToggleStatus: () => _toggleStatus(member),
                        onRemove: () => _confirmRemove(member),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onRemove,
  });

  final StaffMember member;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AdminWebColors.accent.withValues(alpha: 0.2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              member.initials,
              style: const TextStyle(
                color: AdminWebColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AdminWebColors.textPrimary,
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
                    fontWeight: FontWeight.w500,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
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
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AdminWebColors.textSecondary),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'toggle') onToggleStatus();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Details'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(member.isActive ? Icons.block_flipped : Icons.check_circle_outline, size: 18),
                    SizedBox(width: 10),
                    Text(member.isActive ? 'Deactivate Account' : 'Activate Account'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AdminWebColors.error),
                    SizedBox(width: 10),
                    Text('Remove Account', style: TextStyle(color: AdminWebColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AdminWebColors.success : AdminWebColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
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
        color: AdminWebColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminWebColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AdminWebColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AdminWebColors.textSecondary,
            ),
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
              color: AdminWebColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'No staff match your search.'
                  : 'No staff accounts yet.\nTap "Add Staff" to create one.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminWebColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
