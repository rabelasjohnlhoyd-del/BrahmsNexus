import 'package:flutter/material.dart';
import '../../../models/account_status.dart';
import '../../../models/app_user.dart';
import '../../../models/registration_request.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

/// Owner reviews new Staff/Driver registrations here and Accepts or
/// Rejects them. Only after Accept can that account log in.
///
/// Reads live from Firestore via [AuthService.watchAllUsers] — the
/// same source the Owner App's mobile Account Approvals screen uses
/// — so an application approved/rejected on either surface is
/// reflected on both immediately, instead of each keeping its own
/// separate hardcoded mock list.
class AccountApprovalsScreen extends StatefulWidget {
  const AccountApprovalsScreen({super.key});

  @override
  State<AccountApprovalsScreen> createState() =>
      _AccountApprovalsScreenState();
}

class _AccountApprovalsScreenState extends State<AccountApprovalsScreen> {
  void _decide(RegistrationRequest request, AccountStatus status) async {
    await AuthService.updateAccountStatus(request.id, status);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${request.fullName} — marked as ${status.label}',
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(AccountApprovalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: StreamBuilder<List<AppUser>>(
        stream: AuthService.watchAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Could not load accounts. Check your connection.',
                style: TextStyle(color: AdminWebColors.textSecondary),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Owner never appears here — there is exactly one pre-seeded
          // Owner account and it never goes through registration, so
          // this list is Staff/Driver applications only.
          final requests = snapshot.data!
              .where((u) => u.role != UserRole.owner)
              .map(RegistrationRequest.fromAppUser)
              .toList();

          final pending = requests
              .where((r) => r.status == AccountStatus.pending)
              .toList();
          final decided = requests
              .where((r) => r.status != AccountStatus.pending)
              .toList();
          final pendingCount = pending.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminWebColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AdminWebColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions_rounded,
                              size: 14, color: AdminWebColors.warning),
                          const SizedBox(width: 8),
                          Text(
                            '$pendingCount PENDING',
                            style: const TextStyle(
                              color: AdminWebColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: [
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.how_to_reg_rounded,
                                  size: 48, color: AdminWebColors.border),
                              SizedBox(height: 12),
                              Text(
                                'No pending registrations right now.',
                                style: TextStyle(
                                    color: AdminWebColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const Text(
                        'Pending Review',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminWebColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...pending.map(
                        (r) => _RequestCard(
                          request: r,
                          onAccept: () =>
                              _decide(r, AccountStatus.approved),
                          onReject: () =>
                              _decide(r, AccountStatus.rejected),
                        ),
                      ),
                    ],
                    if (decided.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Recently Decided',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminWebColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...decided.map(
                        (r) => _RequestCard(
                          request: r,
                          onChangeStatus: (s) => _decide(r, s),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.onAccept,
    this.onReject,
    this.onChangeStatus,
  });

  final RegistrationRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final void Function(AccountStatus)? onChangeStatus;

  Color _statusColor() {
    switch (request.status) {
      case AccountStatus.pending:
        return AdminWebColors.warning;
      case AccountStatus.approved:
        return AdminWebColors.success;
      case AccountStatus.rejected:
        return AdminWebColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final initial = request.fullName.trim().isNotEmpty
        ? request.fullName.trim().substring(0, 1).toUpperCase()
        : '?';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 550;

          final avatar = CircleAvatar(
            radius: 20,
            backgroundColor: AdminWebColors.accent.withValues(alpha: 0.1),
            child: Text(
              initial,
              style: const TextStyle(
                color: AdminWebColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    request.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AdminWebColors.textPrimary,
                    ),
                  ),
                  if (request.age.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminWebColors.surfaceTint,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AdminWebColors.border),
                      ),
                      child: Text(
                        'Age: ${request.age}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '@${request.username} · ${request.displayRole} · ${request.contactNumber}${request.email.isNotEmpty ? ' · ${request.email}' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AdminWebColors.textSecondary,
                ),
              ),
              if (request.address.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: AdminWebColors.accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (request.driverLicenseNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: request.isLicenseVerified
                            ? AdminWebColors.success.withValues(alpha: 0.1)
                            : AdminWebColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: request.isLicenseVerified
                              ? AdminWebColors.success.withValues(alpha: 0.3)
                              : AdminWebColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            request.isLicenseVerified
                                ? Icons.verified_rounded
                                : Icons.badge_outlined,
                            size: 12,
                            color: request.isLicenseVerified
                                ? AdminWebColors.success
                                : AdminWebColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.isLicenseVerified
                                ? 'LTO Verified: ${request.driverLicenseNumber}'
                                : 'License: ${request.driverLicenseNumber}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: request.isLicenseVerified
                                  ? AdminWebColors.success
                                  : AdminWebColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (request.driverLicenseExpiry.isNotEmpty)
                      Text(
                        'Exp: ${request.driverLicenseExpiry}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );

          final actions = onAccept != null && onReject != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('REJECT'),
                      style: TextButton.styleFrom(
                        foregroundColor: AdminWebColors.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('APPROVE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminWebColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        request.status.label.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (onChangeStatus != null) ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<AccountStatus>(
                        tooltip: 'Change Decision',
                        icon: const Icon(Icons.more_vert_rounded,
                            size: 18, color: AdminWebColors.textSecondary),
                        onSelected: onChangeStatus,
                        itemBuilder: (context) => [
                          if (request.status != AccountStatus.approved)
                            const PopupMenuItem(
                              value: AccountStatus.approved,
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 16, color: AdminWebColors.success),
                                  SizedBox(width: 8),
                                  Text('Approve Account'),
                                ],
                              ),
                            ),
                          if (request.status != AccountStatus.rejected)
                            const PopupMenuItem(
                              value: AccountStatus.rejected,
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_rounded,
                                      size: 16, color: AdminWebColors.error),
                                  SizedBox(width: 8),
                                  Text('Reject Account'),
                                ],
                              ),
                            ),
                          if (request.status != AccountStatus.pending)
                            const PopupMenuItem(
                              value: AccountStatus.pending,
                              child: Row(
                                children: [
                                  Icon(Icons.pending_actions_rounded,
                                      size: 16, color: AdminWebColors.warning),
                                  SizedBox(width: 8),
                                  Text('Move to Pending'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: actions,
                ),
              ],
            );
          }

          return Row(
            children: [
              avatar,
              const SizedBox(width: 16),
              Expanded(child: details),
              actions,
            ],
          );
        },
      ),
    );
  }
}



