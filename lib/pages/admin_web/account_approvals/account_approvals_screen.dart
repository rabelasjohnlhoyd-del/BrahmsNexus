import 'package:flutter/material.dart';
import '../../../models/account_status.dart';
import '../../../models/registration_request.dart';
import '../../../models/user_role.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

/// Owner reviews new Staff/Driver registrations here and Accepts or
/// Rejects them. Only after Accept can that account log in.
///
/// NOTE: Front-end-only — uses mock in-memory data for now. Once
/// Supabase is wired up (backend phase), this will read/write the
/// real accounts table and the Accept/Reject actions will update the
/// account's status there.
class AccountApprovalsScreen extends StatefulWidget {
  const AccountApprovalsScreen({super.key});

  @override
  State<AccountApprovalsScreen> createState() =>
      _AccountApprovalsScreenState();
}

class _AccountApprovalsScreenState extends State<AccountApprovalsScreen> {
  final List<RegistrationRequest> _requests = [
    RegistrationRequest(
      id: '1',
      fullName: 'Juan Dela Cruz',
      username: 'juan.delacruz',
      contactNumber: '0917 123 4567',
      role: UserRole.staff,
    ),
    RegistrationRequest(
      id: '2',
      fullName: 'Pedro Santos',
      username: 'pedro.santos',
      contactNumber: '0917 987 6543',
      role: UserRole.staff,
    ),
  ];

  void _decide(RegistrationRequest request, AccountStatus status) {
    setState(() {
      final index = _requests.indexWhere((r) => r.id == request.id);
      if (index != -1) {
        _requests[index] = request.copyWith(status: status);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${request.fullName} — marked as ${status.label}',
        ),
      ),
    );
    _updateShellActions();
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
    final pendingCount = _requests.where((r) => r.status == AccountStatus.pending).length;
    
    shell?.setActions([
      if (pendingCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AdminWebColors.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pending_actions_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '$pendingCount PENDING',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _requests.where((r) => r.status == AccountStatus.pending).toList();
    final decided =
        _requests.where((r) => r.status != AccountStatus.pending).toList();

    return Container(
      color: AdminWebColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
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
                          Icon(Icons.how_to_reg_rounded, size: 48, color: AdminWebColors.border),
                          SizedBox(height: 12),
                          Text(
                            'No pending registrations right now.',
                            style: TextStyle(color: AdminWebColors.textSecondary),
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
                      onAccept: () => _decide(r, AccountStatus.approved),
                      onReject: () => _decide(r, AccountStatus.rejected),
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
                  ...decided.map((r) => _RequestCard(request: r)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.onAccept,
    this.onReject,
  });

  final RegistrationRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

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

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AdminWebColors.accent.withValues(alpha: 0.1),
            child: Text(
              request.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AdminWebColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${request.username} · ${request.role.label} · ${request.contactNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onAccept != null && onReject != null) ...[
            TextButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('REJECT'),
              style: TextButton.styleFrom(foregroundColor: AdminWebColors.error),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('APPROVE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
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
        ],
      ),
    );
  }
}

