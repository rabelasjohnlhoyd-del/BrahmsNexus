import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import 'branch_form_screen.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  List<Branch> _branches = List<Branch>.from(kSampleBranches);
  final _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = false;

  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _updateShellActions();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.getBranches();
    if (!mounted) return;
    setState(() {
      _branches = list;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Branch> get _filteredBranches {
    if (_query.trim().isEmpty) return _branches;
    final q = _query.trim().toLowerCase();
    return _branches.where((b) {
      return b.name.toLowerCase().contains(q) ||
          b.municipality.toLowerCase().contains(q);
    }).toList();
  }

  void _navigateToForm([Branch? branch]) async {
    final result = await Navigator.of(context).push<Branch>(
      MaterialPageRoute(
        builder: (context) => BranchFormScreen(branch: branch),
      ),
    );

    if (result != null) {
      await SupabaseService.saveBranch(result);
      await _loadBranches();
      if (!mounted) return;
      _updateShellActions();
    }
  }

  @override
  void didUpdateWidget(BranchManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle(null);
    shell?.setActions([]);
  }

  @override
  Widget build(BuildContext context) {
    final branches = _filteredBranches;
    return Container(
      color: AdminWebColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToForm(),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                      label: const Text('ADD BRANCH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminWebColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: EdgeInsets.zero,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText:
                                  'Search branches by name or municipality...',
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AdminWebColors.accent),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : branches.isEmpty
                    ? const Center(child: Text('No branches found.', style: TextStyle(color: AdminWebColors.textSecondary)))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: (branches.length - (_currentPage * _pageSize)).clamp(0, _pageSize),
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final b = branches[(_currentPage * _pageSize) + index];
                                return GlassCard(
                                  padding: EdgeInsets.zero,
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AdminWebColors.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.storefront_rounded,
                                            color: AdminWebColors.accent),
                                      ),
                                      title: Text(
                                        b.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AdminWebColors.textPrimary,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Daily Route Priority: ${b.dailyRouteSequence}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AdminWebColors.textSecondary,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_note_rounded,
                                                color: AdminWebColors.accent),
                                            onPressed: () => _navigateToForm(b),
                                            tooltip: 'Edit Branch',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded,
                                                color: AdminWebColors.error),
                                            onPressed: () => _confirmDelete(b),
                                            tooltip: 'Delete Branch',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPagination(branches.length),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Branch b) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this branch: ${b.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.error),
            onPressed: () async {
              final nav = Navigator.of(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);
              await SupabaseService.deleteBranch(b.id);
              await _loadBranches();
              nav.pop();
              messenger.showSnackBar(
                SnackBar(content: Text('Branch ${b.name} deleted.')),
              );
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = (totalItems / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
        ),
        Text(
          'Page ${_currentPage + 1} of $totalPages',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AdminWebColors.textSecondary),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
        ),
      ],
    );
  }
}

