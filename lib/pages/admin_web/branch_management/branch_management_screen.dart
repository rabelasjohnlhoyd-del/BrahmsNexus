import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../admin_web_colors.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () => _showBranchDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search branches...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _query = ''); }) : null,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final b = branches[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AdminWebColors.accent.withValues(alpha: 0.1),
                      child: const Icon(Icons.storefront, color: AdminWebColors.accent),
                    ),
                    title: Text(b.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Route Priority: ${b.dailyRouteSequence}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showBranchDialog(b)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AdminWebColors.error),
                          onPressed: () {
                            setState(() => _branches.removeWhere((item) => item.id == b.id));
                          },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBranchDialog(),
        label: const Text('Add Branch'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
