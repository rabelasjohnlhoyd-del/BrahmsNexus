import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../models/staff_member.dart';
import '../../../services/assignment_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/rate_limiter.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

/// Owner assigns each Branch Cook to a branch for the current day.
/// Drivers and Production staff are excluded from this list.
class BranchAssignmentsScreen extends StatefulWidget {
  const BranchAssignmentsScreen({super.key});

  @override
  State<BranchAssignmentsScreen> createState() =>
      _BranchAssignmentsScreenState();
}

class _BranchAssignmentsScreenState extends State<BranchAssignmentsScreen> {
  // Current date (auto-updates on rebuild/init)
  final DateTime _today = DateTime.now();
  
  final _searchController = TextEditingController();
  String _query = '';
  int _currentPage = 0;
  static const int _pageSize = 5;

  List<Branch> _availableBranches = SupabaseService.getAllBranchesSync();

  // derive assignments from staff list, filtered to show only Branch Cooks
  late List<BranchAssignment> _assignments;

  // Draft: local-only changes before the owner confirms Save
  // Key = employeeId, Value = draft assignment
  final Map<String, BranchAssignment> _draftChanges = {};

  // Whether today's assignments have already been saved once
  bool _savedToday = false;

  @override
  void initState() {
    super.initState();
    _initializeAssignments();
    _checkSavedToday();
    _updateShellActions();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
    AuthService.syncApprovedUsersToStaffDirectory().then((_) {
      if (mounted) {
        _onAssignmentsChanged();
      }
    });
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentsChanged);
    _searchController.dispose();
    super.dispose();
  }

  StaffMember? _findStaff(List<StaffMember> staffList, String employeeId, String employeeName) {
    final cleanId = employeeId.trim().toLowerCase().replaceAll('-', '');
    final cleanName = employeeName.trim().toLowerCase();
    for (final s in staffList) {
      if (s.id.trim().toLowerCase() == employeeId.trim().toLowerCase()) return s;
      if (s.id.trim().toLowerCase().replaceAll('-', '') == cleanId) return s;
      if (s.username.isNotEmpty && s.username.trim().toLowerCase() == employeeId.trim().toLowerCase()) return s;
      if (cleanName.isNotEmpty && s.fullName.trim().toLowerCase() == cleanName) return s;
    }
    return null;
  }



  void _onAssignmentsChanged() {
    if (!mounted) return;
    final allStaff = SupabaseService.getAllStaff();
    final branchCooks = allStaff
        .where((s) =>
            !s.isArchived &&
            !s.position.toLowerCase().startsWith('production') &&
            (s.position == 'Branch Cook' ||
                s.position == 'Floating Cook' ||
                s.position.toLowerCase().contains('cook')))
        .toList();

    setState(() {
      for (int i = 0; i < _assignments.length; i++) {
        final a = _assignments[i];
        // Skip entries that have unsaved draft changes from the owner
        if (_draftChanges.containsKey(a.employeeId)) continue;
        final staff = _findStaff(branchCooks, a.employeeId, a.employeeName);
        if (staff == null) continue; // Never overwrite with a mismatched person!

        // AssignmentService.lockStatus() is called synchronously before any cloud writes,
        // so this cache is ALWAYS ahead of or equal to Supabase realtime data.
        final status = staff.username.isNotEmpty
            ? AssignmentService.getWorkStatus(staff.username,
                fallback: AssignmentService.getWorkStatus(a.employeeId, fallback: a.workStatus))
            : AssignmentService.getWorkStatus(a.employeeId, fallback: a.workStatus);

        // Same for branch — keep current a.branchName as fallback to avoid branch resetting.
        final branchName = staff.username.isNotEmpty
            ? AssignmentService.getAssignedBranch(staff.username,
                fallback: AssignmentService.getAssignedBranch(a.employeeId, fallback: a.branchName))
            : AssignmentService.getAssignedBranch(a.employeeId, fallback: a.branchName);

        final isUnassigned = branchName == 'N/A' || branchName.isEmpty;
        final branch = isUnassigned
            ? Branch.unassigned
            : _availableBranches.firstWhere(
                (b) => b.fullName == branchName,
                orElse: () => _availableBranches.isNotEmpty ? _availableBranches.first : Branch.unassigned,
              );
        _assignments[i] = a.copyWith(
          workStatus: status,
          branchId: branch.id,
          branchName: branch.fullName,
        );
      }

      // Add any newly registered cook who is not yet in _assignments
      for (final s in branchCooks) {
        final exists = _assignments.any((a) =>
            a.employeeId.trim().toLowerCase() == s.id.trim().toLowerCase() ||
            (s.username.isNotEmpty &&
                a.employeeId.trim().toLowerCase() == s.username.trim().toLowerCase()) ||
            (a.employeeName.isNotEmpty &&
                a.employeeName.trim().toLowerCase() == s.fullName.trim().toLowerCase()));
        if (!exists) {
          final cachedStatus = s.username.isNotEmpty
              ? AssignmentService.getWorkStatus(s.username,
                  fallback: AssignmentService.getWorkStatus(s.id,
                      fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty))
              : AssignmentService.getWorkStatus(s.id,
                  fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty);
          final cachedBranch = s.username.isNotEmpty
              ? AssignmentService.getAssignedBranch(s.username,
                  fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch))
              : AssignmentService.getAssignedBranch(s.id, fallback: s.branch);
          final isUnassigned =
              (cachedBranch == 'N/A' || cachedBranch.isEmpty) && (s.branch == 'N/A' || s.branch.isEmpty);
          final branch = isUnassigned
              ? Branch.unassigned
              : _availableBranches.firstWhere(
                  (b) => b.fullName == cachedBranch,
                  orElse: () => _availableBranches.firstWhere(
                    (b) => b.fullName == s.branch,
                    orElse: () => _availableBranches.isNotEmpty
                        ? _availableBranches.first
                        : Branch.unassigned,
                  ),
                );
          _assignments.add(BranchAssignment(
            id: 'ba-${s.id}',
            employeeId: s.id,
            employeeName: s.fullName,
            branchId: branch.id,
            branchName: branch.fullName,
            date: _today,
            workStatus: cachedStatus,
          ));
        }
      }
    });
  }

  void _initializeAssignments() async {
    // Read from live/in-memory staff profiles
    final allStaff = SupabaseService.getAllStaff();
    final branchCooks = allStaff
        .where((s) =>
            !s.isArchived &&
            !s.position.toLowerCase().startsWith('production') &&
            (s.position == 'Branch Cook' ||
                s.position == 'Floating Cook' ||
                s.position.toLowerCase().contains('cook')))
        .toList();
    
    // 1. Synchronously read from AssignmentService cache first
    _assignments = branchCooks.map((s) {
      final cachedStatus = AssignmentService.getWorkStatus(
        s.username,
        fallback: AssignmentService.getWorkStatus(
          s.id,
          fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
        ),
      );
      final cachedBranch = AssignmentService.getAssignedBranch(
        s.username,
        fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch),
      );
      final isUnassigned = (cachedBranch == 'N/A' || cachedBranch.isEmpty) && (s.branch == 'N/A' || s.branch.isEmpty);
      final branch = isUnassigned
          ? Branch.unassigned
          : _availableBranches.firstWhere(
              (b) => b.fullName == cachedBranch,
              orElse: () => (s.branch.isNotEmpty && s.branch != 'N/A')
                  ? _availableBranches.firstWhere((b) => b.fullName == s.branch, orElse: () => Branch.unassigned)
                  : Branch.unassigned,
            );

      return BranchAssignment(
        id: 'ba-${s.id}',
        employeeId: s.id,
        employeeName: s.fullName,
        branchId: branch.id,
        branchName: branch.fullName,
        date: _today,
        workStatus: cachedStatus,
      );
    }).toList();

    // 2. Refresh from Supabase and Firestore cloud
    try {
      final loadedBranches = await SupabaseService.getBranches();
      if (mounted && loadedBranches.isNotEmpty) {
        setState(() => _availableBranches = loadedBranches);
      }
      await SupabaseService.refreshStaffFromRemote();
      await AssignmentService.ensureInitialized();
      if (mounted) {
        _onAssignmentsChanged();
      }
    } catch (_) {}
    _checkSavedToday();
  }

  @override
  void didUpdateWidget(BranchAssignmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]); 
  }

  Future<void> _checkSavedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('assignment_saved_date') ?? '';
    final todayStr = '${_today.year}-${_today.month.toString().padLeft(2, '0')}-${_today.day.toString().padLeft(2, '0')}';
    if (mounted) {
      setState(() => _savedToday = savedDate == todayStr);
    }
  }

  void _updateBranch(BranchAssignment target, Branch branch) {
    final originalIndex = _assignments.indexWhere((item) =>
        item.employeeId == target.employeeId ||
        item.employeeName.trim().toLowerCase() == target.employeeName.trim().toLowerCase());
    if (originalIndex == -1) return;
    final a = _assignments[originalIndex];
    final updated = a.copyWith(
      branchId: branch.id,
      branchName: branch.fullName,
    );
    setState(() {
      _assignments[originalIndex] = updated;
      _draftChanges[a.employeeId] = updated;
    });
  }

  void _updateStatus(BranchAssignment target, WorkStatus status) {
    final originalIndex = _assignments.indexWhere((item) =>
        item.employeeId == target.employeeId ||
        item.employeeName.trim().toLowerCase() == target.employeeName.trim().toLowerCase());
    if (originalIndex == -1) return;
    final a = _assignments[originalIndex];
    if (a.workStatus == status) return;
    final updated = a.copyWith(workStatus: status);
    setState(() {
      _assignments[originalIndex] = updated;
      _draftChanges[a.employeeId] = updated;
    });
  }

  void _setRestDayAll() {
    setState(() {
      for (int i = 0; i < _assignments.length; i++) {
        final updated = _assignments[i].copyWith(workStatus: WorkStatus.restDay);
        _assignments[i] = updated;
        _draftChanges[updated.employeeId] = updated;
      }
    });
  }

  Future<void> _saveAll() async {
    if (_savedToday) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Already Saved Today', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
          content: const Text(
            'Assignments have already been saved for today. To prevent accidental changes to active sales data, assignments can only be saved once per day.\n\nIf you really need to change something, please contact the system administrator.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Rate limit: prevent hammering Supabase with rapid save presses
    if (!RateLimiter.tryAction(
      key: 'admin_save_assignments',
      cooldown: const Duration(seconds: 10),
    )) {
      final secs = RateLimiter.remainingCooldownSeconds('admin_save_assignments');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $secs second(s) before saving again.')),
      );
      return;
    }

    // Check for duplicate on-duty cooks per branch
    final onDutyList = _assignments.where((a) => a.workStatus == WorkStatus.onDuty).toList();
    final Map<String, List<String>> branchOccupants = {};
    for (final a in onDutyList) {
      final bName = a.branchName.trim();
      if (bName.isEmpty || bName == 'Unassigned' || bName == 'N/A') continue;
      branchOccupants.putIfAbsent(bName, () => []).add(a.employeeName);
    }
    final conflicts = branchOccupants.entries.where((e) => e.value.length > 1).toList();
    if (conflicts.isNotEmpty) {
      final conflictDetails = conflicts.map((c) => '• ${c.key}:\n  - ${c.value.join("\n  - ")}').join('\n\n');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Assignment Conflict Detected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
          content: Text(
            'Cannot save because more than one cook is set to On Duty at the same branch:\n\n'
            '$conflictDetails\n\n'
            'Please set one of them to Rest Day or reassign to a vacant branch before saving.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.accent, foregroundColor: Colors.white),
              child: const Text('OK, I WILL FIX THIS'),
            ),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog
    final onDutyCount = _assignments.where((a) => a.workStatus == WorkStatus.onDuty).length;
    final restDayCount = _assignments.where((a) => a.workStatus == WorkStatus.restDay).length;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.save_rounded, color: AdminWebColors.accent, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text('Confirm Save Assignments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to save today\'s assignments?\n\n'
          '• $onDutyCount staff ON DUTY\n'
          '• $restDayCount staff on REST DAY\n\n'
          'This action can only be done once today. Once saved, assignments cannot be changed until tomorrow.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('YES, SAVE NOW'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Commit all draft changes to AssignmentService + cloud
    final allStaff = SupabaseService.getAllStaff();
    for (final a in _assignments) {
      final bNameClean = a.branchName.trim().toLowerCase();
      final hasRealBranch = bNameClean.isNotEmpty && bNameClean != 'n/a' && bNameClean != 'unassigned';
      if (!hasRealBranch && a.workStatus != WorkStatus.restDay) continue;

      final staff = _findStaff(allStaff, a.employeeId, a.employeeName);
      final username = (staff != null && staff.username.isNotEmpty) ? staff.username : a.employeeId;

      // NOW write to AssignmentService cache + cloud
      AssignmentService.lockStatus(
        username: username,
        employeeId: a.employeeId,
        status: a.workStatus,
        branchName: a.branchName,
      );
      if (hasRealBranch) {
        AssignmentService.lockBranch(
          username: username,
          employeeId: a.employeeId,
          branchName: a.branchName,
        );
      }
      await AssignmentService.setAssignment(
        username: username,
        employeeId: a.employeeId,
        employeeName: a.employeeName,
        branchId: a.branchId,
        branchName: hasRealBranch ? a.branchName : '',
        status: a.workStatus,
      );
    }

    // Mark as saved today
    final prefs = await SharedPreferences.getInstance();
    final todayStr = '${_today.year}-${_today.month.toString().padLeft(2, '0')}-${_today.day.toString().padLeft(2, '0')}';
    await prefs.setString('assignment_saved_date', todayStr);
    _draftChanges.clear();

    if (!mounted) return;
    setState(() => _savedToday = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Branch assignments saved successfully! Staff can now log in.'),
        backgroundColor: Color(0xFF059669),
      ),
    );

    final adminName = AuthService.currentAppUser?.fullName ?? 'Admin';
    FirestoreService.logActivity(
      actor: adminName,
      role: 'Admin',
      action: 'Saved branch assignments for ${_today.day}/${_today.month}/${_today.year}',
      detail: '$onDutyCount on duty, $restDayCount rest day',
      type: 'Staff',
    ).catchError((_) {});
  }

  List<BranchAssignment> get _filteredAssignments {
    if (_query.trim().isEmpty) return _assignments;
    final q = _query.toLowerCase().trim();
    return _assignments.where((a) => a.employeeName.toLowerCase().contains(q)).toList();
  }

  String _formatToday() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[_today.month - 1]} ${_today.day}, ${_today.year}';
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAssignments;

    return Container(
      color: AdminWebColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Controls
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 650;

                  final dateBadge = Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AdminWebColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: isWide
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      mainAxisSize:
                          isWide ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        const Icon(Icons.event_available_rounded,
                            size: 18, color: AdminWebColors.accent),
                        const SizedBox(width: 10),
                        Text(
                          'ASSIGNMENT DATE: ${_formatToday().toUpperCase()}',
                          style: const TextStyle(
                            color: AdminWebColors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );

                  final restDayAllBtn = OutlinedButton.icon(
                    onPressed: _savedToday ? null : _setRestDayAll,
                    icon: const Icon(Icons.hotel_rounded, size: 16),
                    label: const Text(
                      'REST DAY ALL',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: BorderSide(
                        color: _savedToday ? const Color(0xFFCBD5E1) : const Color(0xFFDC2626),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );

                  final saveBtn = ElevatedButton.icon(
                    onPressed: _savedToday ? null : _saveAll,
                    icon: Icon(
                      _savedToday ? Icons.lock_rounded : Icons.save_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      _savedToday ? 'SAVED FOR TODAY' : 'SAVE ASSIGNMENTS',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _savedToday ? const Color(0xFF94A3B8) : AdminWebColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        dateBadge,
                        const Spacer(),
                        restDayAllBtn,
                        const SizedBox(width: 10),
                        saveBtn,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dateBadge,
                      const SizedBox(height: 10),
                      restDayAllBtn,
                      const SizedBox(height: 8),
                      saveBtn,
                    ],
                  );
                },
              ),
            ),

            // Search Bar
            GlassCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() {
                  _query = v;
                  _currentPage = 0;
                }),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(50),
                ],
                decoration: InputDecoration(
                  hintText: 'SEARCH STAFF BY NAME...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminWebColors.accent),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _currentPage = 0;
                            });
                          },
                        ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Summary KPI Chips
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildKpiChip(
                  label: 'TOTAL COOKS',
                  count: list.length,
                  color: AdminWebColors.textPrimary,
                  bgColor: Colors.white,
                  borderColor: AdminWebColors.border,
                ),
                _buildKpiChip(
                  label: 'ON DUTY (MAY PASOK)',
                  count: list.where((a) => a.workStatus == WorkStatus.onDuty).length,
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0),
                  icon: Icons.check_circle_rounded,
                ),
                _buildKpiChip(
                  label: 'REST DAY (DAY OFF)',
                  count: list.where((a) => a.workStatus == WorkStatus.restDay).length,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                  borderColor: const Color(0xFFFECACA),
                  icon: Icons.hotel_rounded,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Assignments List
            Expanded(
              child: list.isEmpty
                ? const Center(child: Text('No matching staff found.', style: TextStyle(color: AdminWebColors.textSecondary)))
                : Builder(
                    builder: (context) {
                      final safeTotalPages = ((list.length + _pageSize - 1) / _pageSize).floor().clamp(1, 99999);
                      final safePage = _currentPage.clamp(0, safeTotalPages - 1);
                      final pageItemCount = (list.length - (safePage * _pageSize)).clamp(0, _pageSize);

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: pageItemCount,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final a = list[(safePage * _pageSize) + index];
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth >= 700;
                                    return _AssignmentCard(
                                      key: ValueKey('card-${a.employeeId}-${a.employeeName}'),
                                      assignment: a,
                                      allAssignments: _assignments,
                                      branches: _availableBranches,
                                      isWide: isWide,
                                      onBranchChanged: (branch) => _updateBranch(a, branch),
                                      onStatusChanged: (status) => _updateStatus(a, status),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          AdminPaginationBar(
                            currentPage: safePage,
                            totalItems: list.length,
                            pageSize: _pageSize,
                            onPageChanged: (p) => setState(() => _currentPage = p),
                          ),
                        ],
                      );
                    },
                  ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiChip({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    super.key,
    required this.assignment,
    required this.allAssignments,
    required this.branches,
    required this.isWide,
    required this.onBranchChanged,
    required this.onStatusChanged,
  });

  final BranchAssignment assignment;
  final List<BranchAssignment> allAssignments;
  final List<Branch> branches;
  final bool isWide;
  final ValueChanged<Branch> onBranchChanged;
  final ValueChanged<WorkStatus> onStatusChanged;

  static StaffMember? _findStaff(List<StaffMember> staffList, String employeeId, String employeeName) {
    final cleanId = employeeId.trim().toLowerCase().replaceAll('-', '');
    final cleanName = employeeName.trim().toLowerCase();
    for (final s in staffList) {
      if (s.id.trim().toLowerCase() == employeeId.trim().toLowerCase()) return s;
      if (s.id.trim().toLowerCase().replaceAll('-', '') == cleanId) return s;
      if (s.username.isNotEmpty && s.username.trim().toLowerCase() == employeeId.trim().toLowerCase()) return s;
      if (cleanName.isNotEmpty && s.fullName.trim().toLowerCase() == cleanName) return s;
    }
    return null;
  }

  static String _getTwoInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '?';
  }

  static Widget _buildInitialsText(String name, bool isOnDuty) {
    return Text(
      _getTwoInitials(name),
      style: TextStyle(
        color: isOnDuty ? AdminWebColors.accent : Colors.grey.shade600,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOnDuty = assignment.workStatus == WorkStatus.onDuty;

    // Check if another cook is currently ON DUTY at this same branch (conflict).
    // Skip N/A / Unassigned branches — they are not real branches and would cause false conflicts.
    BranchAssignment? conflictingOnDutyCook;
    final conflictBranchClean = assignment.branchId.trim().toLowerCase();
    final isNoConflictBranch = conflictBranchClean.isEmpty || conflictBranchClean == 'n/a' || conflictBranchClean == 'unassigned';
    if (isOnDuty && !isNoConflictBranch) {
      for (final other in allAssignments) {
        final otherBranchClean = other.branchId.trim().toLowerCase();
        final otherIsUnassigned = otherBranchClean.isEmpty || otherBranchClean == 'n/a' || otherBranchClean == 'unassigned';
        if (otherIsUnassigned) continue;
        final samePerson = other.employeeId == assignment.employeeId ||
            (other.employeeName.isNotEmpty &&
                other.employeeName.trim().toLowerCase() == assignment.employeeName.trim().toLowerCase());
        if (!samePerson &&
            other.workStatus == WorkStatus.onDuty &&
            other.branchId == assignment.branchId) {
          conflictingOnDutyCook = other;
          break;
        }
      }
    }

    final matchedStaff = _findStaff(SupabaseService.getAllStaff(), assignment.employeeId, assignment.employeeName);
    final photoUrl = matchedStaff?.photoUrl ?? '';

    Widget avatarChild;
    if (photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          final bytes = base64Decode(photoUrl.split(',').last);
          avatarChild = ClipOval(
            child: Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitialsText(assignment.employeeName, isOnDuty)),
          );
        } catch (_) {
          avatarChild = _buildInitialsText(assignment.employeeName, isOnDuty);
        }
      } else {
        avatarChild = ClipOval(
          child: Image.network(photoUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitialsText(assignment.employeeName, isOnDuty)),
        );
      }
    } else {
      avatarChild = _buildInitialsText(assignment.employeeName, isOnDuty);
    }

    final avatarAndName = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isOnDuty
                ? AdminWebColors.accent.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: isOnDuty
                  ? AdminWebColors.accent.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: avatarChild,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                assignment.employeeName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOnDuty
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOnDuty
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnDuty
                          ? Icons.check_circle_rounded
                          : Icons.hotel_rounded,
                      size: 13,
                      color: isOnDuty
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnDuty
                          ? 'On Duty Today (Can log in)'
                          : 'On Rest Day (Cannot log in)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOnDuty
                            ? const Color(0xFF065F46)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),
              if (assignment.branchName == 'N/A' || assignment.branchId == 'unassigned') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text(
                        'N/A: Select a branch below',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (conflictingOnDutyCook != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      Text(
                        'Conflict: ${conflictingOnDutyCook.employeeName.split(" ").first} is also On Duty!',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final isUnassigned = assignment.branchId == 'unassigned' || assignment.branchName == 'N/A';
    final branchDropdown = DropdownButtonFormField<String>(
      key: ValueKey('dd-${assignment.employeeId}-${assignment.branchId}-${assignment.workStatus.name}'),
      initialValue: isUnassigned
          ? 'unassigned'
          : (branches.any((b) => b.id == assignment.branchId)
              ? assignment.branchId
              : (branches.isNotEmpty ? branches.first.id : 'unassigned')),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: isUnassigned
            ? 'ASSIGNED BRANCH (NOT ASSIGNED YET)'
            : (isOnDuty ? 'ASSIGNED BRANCH' : 'ASSIGNED BRANCH (OFF TODAY)'),
        isDense: true,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.0,
          color: isUnassigned
              ? const Color(0xFFDC2626)
              : (isOnDuty ? AdminWebColors.textSecondary : const Color(0xFF94A3B8)),
        ),
        prefixIcon: Icon(
          isUnassigned
              ? Icons.warning_amber_rounded
              : (isOnDuty ? Icons.storefront_rounded : Icons.pause_circle_outline_rounded),
          size: 20,
          color: isUnassigned
              ? const Color(0xFFDC2626)
              : (isOnDuty ? AdminWebColors.accent : const Color(0xFF94A3B8)),
        ),
      ),
      items: [
        if (isUnassigned)
          const DropdownMenuItem<String>(
            value: 'unassigned',
            child: Text(
              'N/A — SELECT A BRANCH TO ASSIGN',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ...branches.map((b) {
          BranchAssignment? occupiedCook;
          for (final other in allAssignments) {
            final samePerson = other.employeeId == assignment.employeeId ||
                (other.employeeName.isNotEmpty &&
                    other.employeeName.trim().toLowerCase() == assignment.employeeName.trim().toLowerCase());
            if (!samePerson &&
                other.workStatus == WorkStatus.onDuty &&
                other.branchId == b.id) {
              occupiedCook = other;
              break;
            }
          }
          final isOccupied = occupiedCook != null;
          final isCurrent = b.id == assignment.branchId;

          // If cook is ON DUTY, branches occupied by other ON DUTY cooks are disabled
          final isSelectable = !isOnDuty || !isOccupied || isCurrent;

          Widget itemChild;
          if (isOnDuty && isOccupied && !isCurrent) {
            itemChild = Text(
              '${b.fullName.toUpperCase()} — (Occupied: ${occupiedCook.employeeName.split(" ").first})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            );
          } else if (isOnDuty && isOccupied && isCurrent) {
            itemChild = Text(
              '${b.fullName.toUpperCase()} (Conflict: ${occupiedCook.employeeName.split(" ").first})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            );
          } else {
            itemChild = Text(
              isOnDuty
                  ? b.fullName.toUpperCase()
                  : '${b.fullName.toUpperCase()} (Rest Day)',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOnDuty ? null : const Color(0xFF94A3B8),
              ),
            );
          }

          return DropdownMenuItem<String>(
            value: b.id,
            enabled: isSelectable,
            child: itemChild,
          );
        }),
      ],
      onChanged: (branchId) {
        if (branchId != null && branchId != 'unassigned') {
          final branch = kSampleBranches.firstWhere((b) => b.id == branchId);
          onBranchChanged(branch);
        }
      },
    );

    final statusToggle = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ON DUTY BUTTON
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onStatusChanged(WorkStatus.onDuty),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isOnDuty ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isOnDuty
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnDuty ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 16,
                      color: isOnDuty ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ON DUTY',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isOnDuty ? FontWeight.w800 : FontWeight.w600,
                        color: isOnDuty ? Colors.white : const Color(0xFF475569),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // REST DAY BUTTON
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onStatusChanged(WorkStatus.restDay),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: !isOnDuty ? const Color(0xFFEF4444) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !isOnDuty
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !isOnDuty ? Icons.hotel_rounded : Icons.radio_button_unchecked,
                      size: 16,
                      color: !isOnDuty ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'REST DAY',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: !isOnDuty ? FontWeight.w800 : FontWeight.w600,
                        color: !isOnDuty ? Colors.white : const Color(0xFF475569),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: conflictingOnDutyCook != null ? const Color(0xFFFCA5A5) : null,
      child: isWide
          ? Row(
              children: [
                Expanded(flex: 3, child: avatarAndName),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: branchDropdown),
                const SizedBox(width: 24),
                statusToggle,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                avatarAndName,
                const SizedBox(height: 16),
                branchDropdown,
                const SizedBox(height: 14),
                Center(child: statusToggle),
              ],
            ),
    );
  }
}
