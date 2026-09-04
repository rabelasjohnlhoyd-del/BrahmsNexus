import 'package:flutter/material.dart';
import '../../../models/account_status.dart';
import '../../../models/registration_request.dart';
import '../../../models/user_role.dart';
import '../../../theme/app_theme.dart';

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
      role: UserRole.driver,
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
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _requests.where((r) => r.status == AccountStatus.pending).toList();
    final decided =
        _requests.where((r) => r.status != AccountStatus.pending).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Approvals',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review new Staff/Driver registrations before they can log in.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Walang pending na registration sa ngayon.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...pending.map(
                    (r) => _RequestCard(
                      request: r,
                      onAccept: () => _decide(r, AccountStatus.approved),
                      onReject: () => _decide(r, AccountStatus.rejected),
                    ),
                  ),
                if (decided.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Previously Decided',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
        return AppColors.warning;
      case AccountStatus.approved:
        return AppColors.success;
      case AccountStatus.rejected:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.pastelBrown,
              child: Text(
                request.fullName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '@${request.username} · ${request.role.label} · '
                    '${request.contactNumber}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onAccept != null && onReject != null) ...[
              IconButton(
                icon: const Icon(Icons.check_circle, color: AppColors.success),
                tooltip: 'Accept',
                onPressed: onAccept,
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: AppColors.error),
                tooltip: 'Reject',
                onPressed: onReject,
              ),
            ] else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.label,
                  style: TextStyle(
                    color: _statusColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
