import 'dart:async';
import '../../../services/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/branch.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';
import 'branch_form_screen.dart';
import 'branch_status_screen.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  int _selectedTab = 0; // 0: Live Branch Status, 1: Branch Directory
  List<Branch> _branches = List<Branch>.from(kSampleBranches);
  final _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = false;
  StreamSubscription? _statusSub;
  final Map<String, bool> _branchOpenMap = {};
  final Map<String, bool> _branchClosedMap = {};

  int _currentPage = 0;
  static const int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _updateShellActions();
    _listenToStatus();
  }

  void _listenToStatus() {
    _statusSub = FirebaseFirestore.instance.collection('branch_status').snapshots().listen((snap) {
      if (!mounted) return;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      setState(() {
        _branchOpenMap.clear();
        _branchClosedMap.clear();
        for (final doc in snap.docs) {
          final data = doc.data();
          final rawBId = (data['branchId']?.toString() ?? doc.id).toLowerCase();
          final cookName = data['cookName']?.toString() ?? '';
          final bId = rawBId;
          // Also compute the canonical branchId (br1..br6) for cross-matching
          final canonId = AttendanceService.normalizeBranchId(rawBId, cookName);
          final rawIsOpen = data['isOpen'] == true;
          final isClosed = data['isClosed'] == true;
          final lastTapType = data['lastTapType'] as String?;
          final openedDateStr = data['openedDateStr'] as String?;
          final closedDateStr = data['closedDateStr'] as String?;
          final hasRfidArrivalToday = lastTapType == 'deployment_opening' && openedDateStr == todayStr;
          // Closed today by retrieval tap
          final isClosedByRetrieval = lastTapType == 'retrieval_closing' && closedDateStr == todayStr;

          // Open if cook has tapped arrival RFID today and branch is not closed by retrieval
          final isOpen = !isClosed && !isClosedByRetrieval && (rawIsOpen || hasRfidArrivalToday);

          // Store under primary key
          _branchOpenMap[bId] = isOpen;
          _branchClosedMap[bId] = isClosed || isClosedByRetrieval;

          // Also store under canonical ID (br1..br6) so tile lookup never mismatches
          if (canonId.isNotEmpty && canonId != bId && canonId != 'unassigned' && canonId != 'commissary') {
            _branchOpenMap[canonId] = isOpen;
            _branchClosedMap[canonId] = isClosed || isClosedByRetrieval;
          }
        }
      });
    });
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
    _statusSub?.cancel();
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

    if (!mounted) return;
    _updateShellActions();

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
    shell?.setTitle(_selectedTab == 0 ? 'BRANCH STATUS OVERVIEW' : 'BRANCH MANAGEMENT');
    shell?.setActions([]);
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    bool isCompact = false,
  }) {
    final isSelected = _selectedTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedTab = index);
          _updateShellActions();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 18,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AdminWebColors.accent
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AdminWebColors.accent
                  : AdminWebColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isCompact ? 15 : 16,
                color: isSelected ? Colors.white : AdminWebColors.textSecondary,
              ),
              SizedBox(width: isCompact ? 5 : 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AdminWebColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branches = _filteredBranches;
    final isNarrowScreen = MediaQuery.of(context).size.width < 600;
    return Container(
      color: AdminWebColors.background,
      padding: EdgeInsets.symmetric(
        horizontal: isNarrowScreen ? 12 : 24,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Top Tab Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              if (isWide) {
                return Row(
                  children: [
                    _buildTabButton(
                      index: 0,
                      label: 'LIVE STORE STATUS',
                      icon: Icons.store_rounded,
                    ),
                    const SizedBox(width: 10),
                    _buildTabButton(
                      index: 1,
                      label: 'BRANCH DIRECTORY',
                      icon: Icons.format_list_bulleted_rounded,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      index: 0,
                      label: 'LIVE STATUS',
                      icon: Icons.store_rounded,
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      index: 1,
                      label: 'DIRECTORY',
                      icon: Icons.format_list_bulleted_rounded,
                      isCompact: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (_selectedTab == 0)
            const Expanded(child: BranchStatusScreen(isEmbedded: true))
          else ...[
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
                                final bLower = b.id.toLowerCase();
                final bCanon = AttendanceService.normalizeBranchId(bLower, b.name);
                final isOpen = ((_branchOpenMap[bLower] ?? _branchOpenMap[bCanon]) == true)
                    && ((_branchClosedMap[bLower] ?? _branchClosedMap[bCanon]) != true);
                                return GlassCard(
                                  padding: EdgeInsets.zero,
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _navigateToForm(b),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: AdminWebColors.accent.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(Icons.storefront_rounded,
                                                  color: AdminWebColors.accent, size: 20),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          b.fullName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w700,
                                                            color: AdminWebColors.textPrimary,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: isOpen
                                                              ? AdminWebColors.success.withValues(alpha: 0.12)
                                                              : AdminWebColors.textSecondary.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(5),
                                                          border: Border.all(
                                                            color: isOpen
                                                                ? AdminWebColors.success.withValues(alpha: 0.3)
                                                                : AdminWebColors.textSecondary.withValues(alpha: 0.3),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              isOpen
                                                                  ? Icons.lock_open_rounded
                                                                  : Icons.lock_rounded,
                                                              size: 10,
                                                              color: isOpen
                                                                  ? AdminWebColors.success
                                                                  : AdminWebColors.textSecondary,
                                                            ),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              isOpen ? 'OPEN' : 'CLOSED',
                                                              style: TextStyle(
                                                                fontSize: 9.5,
                                                                fontWeight: FontWeight.w800,
                                                                color: isOpen
                                                                    ? AdminWebColors.success
                                                                    : AdminWebColors.textSecondary,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Daily Route Priority: ${b.dailyRouteSequence}',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: AdminWebColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.edit_note_rounded,
                                                  color: AdminWebColors.accent, size: 21),
                                              onPressed: () => _navigateToForm(b),
                                              tooltip: 'Edit Branch',
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.delete_outline_rounded,
                                                  color: AdminWebColors.error, size: 19),
                                              onPressed: () => _confirmDelete(b),
                                              tooltip: 'Delete Branch',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          AdminPaginationBar(
                            currentPage: _currentPage,
                            totalItems: branches.length,
                            pageSize: _pageSize,
                            onPageChanged: (p) => setState(() => _currentPage = p),
                          ),
                        ],
                      ),
          ),
          ],
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
}

