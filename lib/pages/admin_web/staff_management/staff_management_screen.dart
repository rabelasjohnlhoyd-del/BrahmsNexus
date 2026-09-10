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
  final List<StaffMember> _staff = List<StaffMember>.from(kSampleStaff);

  final _searchController = TextEditingController();
  String _query = '';
  bool _showArchived = false;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StaffMember> get _filteredStaff {
    final base = _staff.where((s) => s.isArchived == _showArchived).toList();
    if (_query.trim().isEmpty) return base;
    final q = _query.trim().toLowerCase();
    return base.where((s) {
      return s.fullName.toLowerCase().contains(q) ||
          s.username.toLowerCase().contains(q) ||
          s.branch.toLowerCase().contains(q) ||
          s.position.toLowerCase().contains(q);
    }).toList();
  }

  List<StaffMember> get _paginatedStaff {
    final filtered = _filteredStaff;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= filtered.length) return [];
    final end = start + _pageSize;
    return filtered.sublist(start, end > filtered.length ? filtered.length : end);
  }

  int get _totalPages {
    final count = _filteredStaff.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  void _changePage(int page) {
    setState(() => _currentPage = page);
  }

  void _toggleView() {
    setState(() {
      _showArchived = !_showArchived;
      _currentPage = 1;
      _query = '';
      _searchController.clear();
    });
  }

  Future<void> _openAddStaff() async {
    final result = await Navigator.of(context).push<StaffMember>(
      MaterialPageRoute(builder: (context) => const AddStaffScreen()),
    );

    if (!mounted) return;
    _updateShellActions();

    if (result == null) return;

    setState(() {
      _staff.insert(0, result);
      _currentPage = 1;
    });

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

  Future<void> _toggleArchive(StaffMember member) async {
    final action = member.isArchived ? 'Restore' : 'Archive';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Staff Account'),
        content: Text(
          member.isArchived
              ? 'Are you sure you want to restore ${member.fullName}\'s account to the active list?'
              : 'Are you sure you want to archive ${member.fullName}\'s account? '
                  'They will no longer appear in the active staff list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: member.isArchived
                  ? AdminWebColors.success
                  : AdminWebColors.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        final index = _staff.indexWhere((s) => s.id == member.id);
        if (index != -1) {
          _staff[index] = member.copyWith(isArchived: !member.isArchived);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${member.fullName} was ${member.isArchived ? 'restored' : 'archived'}.',
          ),
        ),
      );
    }
  }

  Future<void> _permanentDelete(StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanent Delete'),
        content: Text(
          'Are you sure you want to PERMANENTLY delete this account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AdminWebColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _staff.removeWhere((s) => s.id == member.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.fullName} was permanently deleted.'),
        ),
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
    shell?.setActions([]); // Always keep header clean
  }

  @override
  Widget build(BuildContext context) {
    final staff = _paginatedStaff;
    final totalPages = _totalPages;

    return Container(
      color: AdminWebColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() {
                          _query = value;
                          _currentPage = 1;
                        }),
                        decoration: InputDecoration(
                          hintText:
                              'SEARCH BY NAME, USERNAME, BRANCH, OR POSITION',
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
                                    setState(() {
                                      _query = '';
                                      _currentPage = 1;
                                    });
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _toggleView,
                      icon: Icon(
                        _showArchived
                            ? Icons.arrow_back_rounded
                            : Icons.archive_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _showArchived ? 'BACK TO ACTIVE' : 'VIEW ARCHIVED',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _openAddStaff,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('ADD NEW STAFF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminWebColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                if (_showArchived) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminWebColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AdminWebColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: AdminWebColors.error),
                        SizedBox(width: 8),
                        Text(
                          'VIEWING ARCHIVED ACCOUNTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AdminWebColors.error,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: staff.isEmpty
                ? _EmptyState(
                    hasQuery: _query.isNotEmpty,
                    isArchivedView: _showArchived,
                  )
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
                        onArchive: () => _toggleArchive(member),
                        onPermanentDelete: () => _permanentDelete(member),
                      );
                    },
                  ),
          ),
          if (_filteredStaff.length > _pageSize)
            _PaginationFooter(
              currentPage: _currentPage,
              totalPages: totalPages,
              onPageChanged: _changePage,
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
    required this.onArchive,
    required this.onPermanentDelete,
  });

  final StaffMember member;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onArchive;
  final VoidCallback onPermanentDelete;

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
            icon: const Icon(Icons.more_vert_rounded,
                color: AdminWebColors.textSecondary),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'toggle') onToggleStatus();
              if (value == 'archive') onArchive();
              if (value == 'delete') onPermanentDelete();
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
                    Icon(
                        member.isActive
                            ? Icons.block_flipped
                            : Icons.check_circle_outline,
                        size: 18),
                    SizedBox(width: 10),
                    Text(member.isActive
                        ? 'Deactivate Account'
                        : 'Activate Account'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      member.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 18,
                      color: member.isArchived
                          ? AdminWebColors.success
                          : AdminWebColors.error,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      member.isArchived ? 'Restore Account' : 'Archive Account',
                      style: TextStyle(
                        color: member.isArchived
                            ? AdminWebColors.success
                            : AdminWebColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (member.isArchived)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever_outlined,
                        size: 18,
                        color: AdminWebColors.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Permanent Delete',
                        style: TextStyle(color: AdminWebColors.error),
                      ),
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
  const _EmptyState({
    required this.hasQuery,
    required this.isArchivedView,
  });

  final bool hasQuery;
  final bool isArchivedView;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery
                  ? Icons.search_off_rounded
                  : (isArchivedView
                      ? Icons.archive_outlined
                      : Icons.people_outline),
              size: 48,
              color: AdminWebColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'No staff match your search.'
                  : (isArchivedView
                      ? 'No archived accounts.'
                      : 'No staff accounts yet.\nTap "Add Staff" to create one.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminWebColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AdminWebColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous Page',
          ),
          const SizedBox(width: 16),
          Text(
            'PAGE $currentPage OF $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AdminWebColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next Page',
          ),
        ],
      ),
    );
  }
}

