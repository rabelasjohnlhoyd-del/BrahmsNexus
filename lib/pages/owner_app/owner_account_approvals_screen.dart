import 'package:flutter/cupertino.dart';
import '../../models/account_status.dart';
import '../../models/registration_request.dart';
import '../../models/user_role.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';

/// Mobile Account Approvals screen — allows the Owner to review
/// pending Staff registration requests on the go.
class OwnerAccountApprovalsScreen extends StatefulWidget {
  const OwnerAccountApprovalsScreen({super.key});

  @override
  State<OwnerAccountApprovalsScreen> createState() =>
      _OwnerAccountApprovalsScreenState();
}

class _OwnerAccountApprovalsScreenState
    extends State<OwnerAccountApprovalsScreen> {
  int _filterIndex = 0; // 0 = Pending, 1 = Approved, 2 = Rejected, 3 = All
  String _searchQuery = '';

  final List<RegistrationRequest> _requests = [
    RegistrationRequest(
      id: '1',
      fullName: 'Juan Dela Cruz',
      username: 'juan.delacruz',
      contactNumber: '0917 123 4567',
      role: UserRole.staff,
      status: AccountStatus.pending,
      dateRequested: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    RegistrationRequest(
      id: '2',
      fullName: 'Pedro Santos',
      username: 'pedro.santos',
      contactNumber: '0917 987 6543',
      role: UserRole.staff,
      status: AccountStatus.pending,
      dateRequested: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    RegistrationRequest(
      id: '3',
      fullName: 'Maria Teresa Reyes',
      username: 'maria.reyes',
      contactNumber: '0918 222 3344',
      role: UserRole.staff,
      status: AccountStatus.approved,
      dateRequested: DateTime.now().subtract(const Duration(days: 1)),
    ),
    RegistrationRequest(
      id: '4',
      fullName: 'Antonio Luna',
      username: 'antonio.luna',
      contactNumber: '0919 444 5566',
      role: UserRole.staff,
      status: AccountStatus.rejected,
      dateRequested: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  int get _pendingCount =>
      _requests.where((r) => r.status == AccountStatus.pending).length;

  List<RegistrationRequest> get _filteredRequests {
    return _requests.where((r) {
      if (_filterIndex == 0 && r.status != AccountStatus.pending) return false;
      if (_filterIndex == 1 && r.status != AccountStatus.approved) return false;
      if (_filterIndex == 2 && r.status != AccountStatus.rejected) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = r.fullName.toLowerCase().contains(query);
        final matchesUsername = r.username.toLowerCase().contains(query);
        final matchesPhone = r.contactNumber.contains(query);
        if (!matchesName && !matchesUsername && !matchesPhone) return false;
      }
      return true;
    }).toList();
  }

  void _handleDecision(RegistrationRequest request, AccountStatus newStatus) {
    final isApprove = newStatus == AccountStatus.approved;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(isApprove ? 'Approve Account' : 'Reject Account'),
        content: Text(
          isApprove
              ? 'Are you sure you want to approve ${request.fullName}? They will be permitted to log in immediately.'
              : 'Are you sure you want to reject the registration for ${request.fullName}?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: !isApprove,
            child: Text(isApprove ? 'Approve' : 'Reject'),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                final idx = _requests.indexWhere((r) => r.id == request.id);
                if (idx != -1) {
                  _requests[idx] = request.copyWith(status: newStatus);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredRequests;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Account Approvals',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                placeholder: 'Search applicant name, username, phone...',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _filterIndex,
                  thumbColor: CupertinoColors.white,
                  backgroundColor: AppColors.cardCream,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        _pendingCount > 0
                            ? 'Pending ($_pendingCount)'
                            : 'Pending',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _filterIndex == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _filterIndex == 0
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Approved',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _filterIndex == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _filterIndex == 1
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Rejected',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _filterIndex == 2
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _filterIndex == 2
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    3: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'All',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _filterIndex == 3
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _filterIndex == 3
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) setState(() => _filterIndex = val);
                  },
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.person_crop_circle_badge_checkmark,
                              size: 44,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching requests'
                                  : 'No accounts in this category',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Newly registered staff will appear here for approval.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final req = items[index];
                        return _ApplicantCard(
                          request: req,
                          onApprove: () =>
                              _handleDecision(req, AccountStatus.approved),
                          onReject: () =>
                              _handleDecision(req, AccountStatus.rejected),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final RegistrationRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == AccountStatus.pending;
    final isApproved = request.status == AccountStatus.approved;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StaffCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    request.fullName.isNotEmpty
                        ? request.fullName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${request.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.role.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.phone,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    request.contactNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(request.dateRequested),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: StaffButton(
                      label: 'Reject',
                      color: AppColors.cardCream,
                      textColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onPressed: onReject,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StaffButton(
                      label: 'Approve',
                      color: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onPressed: onApprove,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    isApproved
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.xmark_circle_fill,
                    size: 16,
                    color: isApproved
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isApproved ? 'Approved Account' : 'Rejected Registration',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isApproved
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
