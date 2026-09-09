import 'package:flutter/material.dart';
import '../../../models/branch.dart';
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
  final List<Branch> _branches = List<Branch>.from(kSampleBranches);
  final _searchController = TextEditingController();
  String _query = '';

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
      setState(() {
        final index = _branches.indexWhere((b) => b.id == result.id);
        if (index != -1) {
          _branches[index] = result;
        } else {
          _branches.add(result);
        }
      });
      _updateShellActions();
    }
  }

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(BranchManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle(null);
    shell?.setActions([
      ElevatedButton.icon(
        onPressed: () => _navigateToForm(),
        icon: const Icon(Icons.add_location_alt_rounded, size: 18, color: Colors.white),
        label: const Text('NEW BRANCH'),
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
    final branches = _filteredBranches;
    return Container(
      color: AdminWebColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search branches by name or municipality...',
                prefixIcon: const Icon(Icons.search_rounded, color: AdminWebColors.accent),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = branches[index];
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
                          onPressed: () {
                            setState(
                                () => _branches.removeWhere((item) => item.id == b.id));
                          },
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
      ],
    ),
  );
}
}
