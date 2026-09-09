import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/transfer_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/driver_top_actions.dart';

/// StockTransferPage — handles requests from branches for extra stock.
/// Logic: Staff requests -> Owner approves -> Driver picks up from Warehouse (Owner's house) -> Delivers to Branch.
class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final List<TransferRequest> _requests = [
    const TransferRequest(
      id: 'tr1',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      type: TransferRequestType.meat,
      suggestedSourceBranchName: 'Main Warehouse (Owner\'s House)',
    ),
    const TransferRequest(
      id: 'tr2',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      type: TransferRequestType.gas,
      suggestedSourceBranchName: 'Main Warehouse (Owner\'s House)',
    ),
  ];

  void _confirmAction(String id, String action, TransferRequestStatus nextStatus) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Confirm Action'),
        content: Text('Sigurado ka bang na-execute mo na ang step: "$action"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                final index = _requests.indexWhere((r) => r.id == id);
                if (index != -1) {
                  _requests[index] = _requests[index].copyWith(status: nextStatus);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Step "$action" recorded.')),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TransferRequestStatus status) {
    switch (status) {
      case TransferRequestStatus.pending:
        return AppColors.warning;
      case TransferRequestStatus.photoTaken:
        return AppColors.accent;
      case TransferRequestStatus.submitted:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Stock Transfer',
        trailing: DriverTopActions(),
      ),
      child: SafeArea(
        child: _requests.isEmpty
            ? _buildEmptyState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const DriverSectionHeader(
                    label: 'Active Transfers',
                    icon: CupertinoIcons.arrow_2_squarepath,
                  ),
                  const SizedBox(height: 12),
                  ..._requests.map((request) => _buildRequestCard(request)),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.pastelBrown.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.checkmark_shield_fill, size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            const Text('All Clear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('No pending stock transfer requests from Owner.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(TransferRequest request) {
    final bool isPending = request.status == TransferRequestStatus.pending;
    final bool isPickedUp = request.status == TransferRequestStatus.photoTaken;
    final bool isDone = request.status == TransferRequestStatus.submitted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DriverCard(
        highlighted: isDone,
        borderColor: isDone ? AppColors.accent : null, // Brown border when all steps are done
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _statusColor(request.status).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    request.type == TransferRequestType.meat ? CupertinoIcons.square_stack_3d_up_fill : CupertinoIcons.flame_fill,
                    size: 18, color: _statusColor(request.status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.branchName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                      Text('Request: ${request.type.label}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (isDone)
                  const Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success, size: 22),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            
            // Workflow Steps
            _buildStepRow(
              label: 'Pick up from Warehouse',
              isCompleted: isPickedUp || isDone,
              isActive: isPending,
              onTap: () => _confirmAction(request.id, 'Picked up from Warehouse', TransferRequestStatus.photoTaken),
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              label: 'Deliver to Branch',
              isCompleted: isDone,
              isActive: isPickedUp,
              onTap: () => _confirmAction(request.id, 'Delivered to Branch', TransferRequestStatus.submitted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({required String label, required bool isCompleted, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Opacity(
        opacity: (isActive || isCompleted) ? 1.0 : 0.4,
        child: Row(
          children: [
            Icon(
              isCompleted ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
              size: 20, color: isCompleted ? AppColors.success : (isActive ? AppColors.accent : AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isActive)
              const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

