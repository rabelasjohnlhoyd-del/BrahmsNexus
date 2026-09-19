import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../models/staff_member.dart';
import '../../../services/assignment_service.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

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

  // derive assignments from staff list, filtered to show only Branch Cooks
  late List<BranchAssignment> _assignments;

  @override
  void initState() {
    super.initState();
    _initializeAssignments();
    _updateShellActions();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
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
    final branchCooks = allStaff.where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook').toList();
    setState(() {
      for (int i = 0; i < _assignments.length; i++) {
        final a = _assignments[i];
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
            : kSampleBranches.firstWhere(
                (b) => b.fullName == branchName,
                orElse: () => kSampleBranches.first,
              );
        _assignments[i] = a.copyWith(
          workStatus: status,
          branchId: branch.id,
          branchName: branch.fullName,
        );
      }
    });
  }

  void _initializeAssignments() async {
    // Read from live/in-memory staff profiles
    final allStaff = SupabaseService.getAllStaff();
    final branchCooks = allStaff.where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook').toList();
    
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
          : kSampleBranches.firstWhere(
              (b) => b.fullName == cachedBranch,
              orElse: () => (s.branch.isNotEmpty && s.branch != 'N/A')
                  ? kSampleBranches.firstWhere((b) => b.fullName == s.branch, orElse: () => Branch.unassigned)
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
      await AssignmentService.ensureInitialized();
      if (mounted) {
        _onAssignmentsChanged();
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(BranchAssignmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeAssignments();
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]); 
  }

  void _updateBranch(BranchAssignment target, Branch branch) async {
    final originalIndex = _assignments.indexWhere((item) =>
        item.employeeId == target.employeeId ||
        item.employeeName.trim().toLowerCase() == target.employeeName.trim().toLowerCase());
    if (originalIndex == -1) return;

    final a = _assignments[originalIndex];

    final allStaff = SupabaseService.getAllStaff();
    final staff = _findStaff(allStaff, a.employeeId, a.employeeName);
    final username = (staff != null && staff.username.isNotEmpty) ? staff.username : a.employeeId;

    // Lock branch in cache immediately before async call
    AssignmentService.lockBranch(
      username: username,
      employeeId: a.employeeId,
      branchName: branch.fullName,
    );

    setState(() {
      _assignments[originalIndex] = a.copyWith(
        branchId: branch.id,
        branchName: branch.fullName,
      );
    });

    await AssignmentService.setAssignment(
      username: username,
      employeeId: a.employeeId,
      employeeName: a.employeeName,
      branchId: branch.id,
      branchName: branch.fullName,
      status: a.workStatus,
    );
  }

  void _updateStatus(BranchAssignment target, WorkStatus status) async {
    final originalIndex = _assignments.indexWhere((item) =>
        item.employeeId == target.employeeId ||
        item.employeeName.trim().toLowerCase() == target.employeeName.trim().toLowerCase());
    if (originalIndex == -1) return;

    final a = _assignments[originalIndex];
    if (a.workStatus == status) return;

    final allStaff = SupabaseService.getAllStaff();
    final staff = _findStaff(allStaff, a.employeeId, a.employeeName);
    final username = (staff != null && staff.username.isNotEmpty) ? staff.username : a.employeeId;

    // Lock status in cache immediately (optimistic UI without annoying popups)
    AssignmentService.lockStatus(
      username: username,
      employeeId: a.employeeId,
      status: status,
      branchName: a.branchName,
    );

    setState(() {
      _assignments[originalIndex] = a.copyWith(workStatus: status);
    });

    final isRest = status == WorkStatus.restDay;
    await SupabaseService.toggleStaffActive(a.employeeId, !isRest);
    if (staff != null && staff.username.isNotEmpty) {
      await SupabaseService.toggleStaffActiveByUsername(staff.username, !isRest);
    }

    await AssignmentService.setAssignment(
      username: username,
      employeeId: a.employeeId,
      employeeName: a.employeeName,
      branchId: a.branchId,
      branchName: a.branchName,
      status: status,
    );
  }

  void _saveAll() async {
    // Check for duplicate on-duty cooks per branch
    final onDutyList = _assignments.where((a) => a.workStatus == WorkStatus.onDuty).toList();
    final Map<String, List<String>> branchOccupants = {};
    for (final a in onDutyList) {
      branchOccupants.putIfAbsent(a.branchName, () => []).add(a.employeeName);
    }
    final conflicts = branchOccupants.entries.where((e) => e.value.length > 1).toList();
    if (conflicts.isNotEmpty) {
      final conflictDetails = conflicts.map((c) => '• ${c.key}:\n  - ${c.value.join("\n  - ")}').join('\n\n');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('May Conflict sa Assignments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
          content: Text(
            'Hindi mai-save dahil may mahigit sa isang cook na naka-On Duty sa parehong branch:\n\n'
            '$conflictDetails\n\n'
            'Pakiusap i-Rest Day ang isa sa kanila o ilipat sa ibang bakanteng branch bago i-save.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.accent, foregroundColor: Colors.white),
              child: const Text('OK, AAYUSIN KO'),
            ),
          ],
        ),
      );
      return;
    }

    final allStaff = SupabaseService.getAllStaff();
    for (final a in _assignments) {
      final staff = _findStaff(allStaff, a.employeeId, a.employeeName);
      final username = (staff != null && staff.username.isNotEmpty) ? staff.username : a.employeeId;
      await AssignmentService.setAssignment(
        username: username,
        employeeId: a.employeeId,
        employeeName: a.employeeName,
        branchId: a.branchId,
        branchName: a.branchName,
        status: a.workStatus,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Branch assignments & Rest Days saved to cloud successfully!')),
    );
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
              padding: const EdgeInsets.only(bottom: 24, top: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 18, color: AdminWebColors.accent),
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
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                    label: const Text('SAVE ASSIGNMENTS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminWebColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            GlassCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'SEARCH STAFF BY NAME...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminWebColors.accent),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
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
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = list[index];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;
                          return _AssignmentCard(
                            key: ValueKey('card-${a.employeeId}-${a.employeeName}'),
                            assignment: a,
                            allAssignments: _assignments,
                            isWide: isWide,
                            onBranchChanged: (branch) => _updateBranch(a, branch),
                            onStatusChanged: (status) => _updateStatus(a, status),
                          );
                        },
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
    required this.isWide,
    required this.onBranchChanged,
    required this.onStatusChanged,
  });

  final BranchAssignment assignment;
  final List<BranchAssignment> allAssignments;
  final bool isWide;
  final ValueChanged<Branch> onBranchChanged;
  final ValueChanged<WorkStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final bool isOnDuty = assignment.workStatus == WorkStatus.onDuty;

    // Check if another cook is currently ON DUTY at this same branch (conflict)
    BranchAssignment? conflictingOnDutyCook;
    if (isOnDuty) {
      for (final other in allAssignments) {
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
          child: Text(
            assignment.employeeName.isNotEmpty
                ? assignment.employeeName.substring(0, 1).toUpperCase()
                : '?',
            style: TextStyle(
              color: isOnDuty ? AdminWebColors.accent : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
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
                          ? 'May duty ngayon (Puwede mag-login)'
                          : 'Naka-Rest Day (Bawal mag-login)',
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
                        'N/A: Piliin ang Branch sa ibaba',
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
                        'Conflict: Naka-Duty rin si ${conflictingOnDutyCook.employeeName.split(" ").first}!',
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
          : (kSampleBranches.any((b) => b.id == assignment.branchId)
              ? assignment.branchId
              : kSampleBranches.first.id),
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
              '⚠️ N/A — PILIIN ANG BRANCH NA ILALAGAY',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ...kSampleBranches.map((b) {
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
              '${b.fullName.toUpperCase()} — (May Duty: ${occupiedCook.employeeName.split(" ").first})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            );
          } else if (isOnDuty && isOccupied && isCurrent) {
            itemChild = Text(
              '${b.fullName.toUpperCase()} ⚠️ (Conflict: ${occupiedCook.employeeName.split(" ").first})',
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
