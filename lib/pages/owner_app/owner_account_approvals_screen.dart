import 'package:flutter/cupertino.dart';
import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/registration_request.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';

/// Mobile Account Approvals screen — allows the Owner to review
/// pending Staff registration requests on the go.
///
/// Reads live from Firestore via [AuthService.watchAllUsers] — the
/// same source Admin Web's Account Approvals page uses — so a
/// decision made on either surface shows up on both immediately.
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

  List<RegistrationRequest> _applyFilters(List<RegistrationRequest> all) {
    return all.where((r) {
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
    final isReset = newStatus == AccountStatus.pending;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(isReset
            ? 'Reset to Pending'
            : (isApprove ? 'Approve Account' : 'Reject Account')),
        content: Text(
          isReset
              ? 'Are you sure you want to move ${request.fullName} back to Pending?'
              : (isApprove
                  ? 'Are you sure you want to approve ${request.fullName}? They will be permitted to log in immediately.'
                  : 'Are you sure you want to reject the registration for ${request.fullName}?'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: !isApprove && !isReset,
            child: Text(isReset ? 'Reset' : (isApprove ? 'Approve' : 'Reject')),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success =
                  await AuthService.updateAccountStatus(request.id, newStatus);
              if (!mounted) return;
              if (!success) {
                showCupertinoDialog<void>(
                  context: context,
                  builder: (errCtx) => CupertinoAlertDialog(
                    title: const Text('Error'),
                    content: const Text(
                        'Failed to update account status. Please check your network connection and try again.'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('OK'),
                        onPressed: () => Navigator.of(errCtx).pop(),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showChangeStatusSheet(RegistrationRequest request) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Change Status: ${request.fullName}'),
        message: Text('Current status: ${request.status.label.toUpperCase()}'),
        actions: [
          if (request.status != AccountStatus.approved)
            CupertinoActionSheetAction(
              child: const Text('Approve Account'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleDecision(request, AccountStatus.approved);
              },
            ),
          if (request.status != AccountStatus.rejected)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('Reject Account'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleDecision(request, AccountStatus.rejected);
              },
            ),
          if (request.status != AccountStatus.pending)
            CupertinoActionSheetAction(
              child: const Text('Reset to Pending'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleDecision(request, AccountStatus.pending);
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Account Approvals',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: AuthService.watchAllUsers(),
          builder: (context, snapshot) {
            final isLoading = !snapshot.hasData;

            // Owner never appears here — there is exactly one
            // pre-seeded Owner account and it never goes through
            // registration, so this list is Staff/Driver applications
            // only.
            final allRequests = (snapshot.data ?? [])
                .where((u) => u.role != UserRole.owner)
                .map(RegistrationRequest.fromAppUser)
                .toList();

            final pendingCount = allRequests
                .where((r) => r.status == AccountStatus.pending)
                .length;
            final items = _applyFilters(allRequests);

            return Column(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                            pendingCount > 0
                                ? 'Pending ($pendingCount)'
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
                  child: isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons
                                          .person_crop_circle_badge_checkmark,
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
                                  onApprove: () => _handleDecision(
                                      req, AccountStatus.approved),
                                  onReject: () => _handleDecision(
                                      req, AccountStatus.rejected),
                                  onChangeStatus: () =>
                                      _showChangeStatusSheet(req),
                                );
                              },
                            ),
                ),
              ],
            );
          },
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
    this.onChangeStatus,
  });

  final RegistrationRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onChangeStatus;

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
                    request.fullName.trim().isNotEmpty
                        ? request.fullName.trim().substring(0, 1).toUpperCase()
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
                    request.displayRole.toUpperCase(),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      if (request.age.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· Age: ${request.age}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
                  if (request.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.mail,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (request.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.location,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (request.driverLicenseNumber.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: request.isLicenseVerified
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            request.isLicenseVerified
                                ? CupertinoIcons.checkmark_seal_fill
                                : CupertinoIcons.exclamationmark_triangle,
                            size: 12,
                            color: request.isLicenseVerified
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.isLicenseVerified
                                ? 'LTO Verified: ${request.driverLicenseNumber}'
                                : 'License: ${request.driverLicenseNumber}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: request.isLicenseVerified
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  Expanded(
                    child: Text(
                      isApproved ? 'Approved Account' : 'Rejected Registration',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isApproved
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                  if (onChangeStatus != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: onChangeStatus,
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
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
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}


