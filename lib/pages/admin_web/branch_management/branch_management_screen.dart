import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';
import '../../../widgets/admin_page_header.dart';
import '../../../widgets/primary_button.dart';

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

  void _showBranchDialog([Branch? branch]) {
    final isEdit = branch != null;
    final nameController = TextEditingController(text: branch?.name);
    final municipalityController = TextEditingController(text: branch?.municipality);
    final sequenceController = TextEditingController(text: branch?.dailyRouteSequence.toString() ?? '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Branch' : 'Add New Branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Branch Name (e.g. Brgy. Gatid)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: municipalityController,
              decoration: const InputDecoration(labelText: 'Municipality'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sequenceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily Route Sequence'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newBranch = Branch(
                id: isEdit ? branch.id : 'br${_branches.length + 1}',
                name: nameController.text,
                municipality: municipalityController.text,
                dailyRouteSequence: int.tryParse(sequenceController.text) ?? 1,
              );
              setState(() {
                if (isEdit) {
                  final index = _branches.indexWhere((b) => b.id == branch.id);
                  _branches[index] = newBranch;
                } else {
                  _branches.add(newBranch);
                }
              });
              Navigator.pop(context);
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branches = _filteredBranches;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Branch Management',
            subtitle: 'Add, edit, or remove store locations and their route sequences.',
            actions: [
              PrimaryButton(
                label: 'NEW BRANCH',
                icon: Icons.add_location_alt_rounded,
                onPressed: () => _showBranchDialog(),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
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
                          onPressed: () => _showBranchDialog(b),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
