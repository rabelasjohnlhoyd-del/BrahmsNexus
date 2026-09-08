import 'package:flutter/cupertino.dart';
import '../../models/transfer_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/driver_top_actions.dart';
import 'stock_transfer_detail_screen.dart';

/// StockTransferPage — branches that requested extra meat or gas, and
/// which branch (suggested source) it should be picked up from.
///
/// NOTE: The "suggested source" is STATIC/MOCK for now (a
/// proximity-based example: Gatid -> Labuin -> Pila -> Nanhaya/San
/// Francisco). The real DSS logic (proximity + available stock) will
/// be done in the backend phase — pure frontend for now.
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
      suggestedSourceBranchName: 'Brgy. Labuin, Pila',
    ),
    const TransferRequest(
      id: 'tr2',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      type: TransferRequestType.gas,
      suggestedSourceBranchName: 'Brgy. Sta. Clara Sur, Pila',
    ),
  ];

  void _updateStatus(String id, TransferRequestStatus status) {
    setState(() {
      final index = _requests.indexWhere((r) => r.id == id);
      if (index != -1) {
        _requests[index] = _requests[index].copyWith(status: status);
      }
    });
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
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.pastelBrown.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.arrow_2_squarepath,
                            size: 32, color: AppColors.accent),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Transfers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'There are no pending stock transfer requests right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const DriverSectionHeader(
                    label: 'Pending Transfers',
                    icon: CupertinoIcons.arrow_2_squarepath,
                  ),
                  const SizedBox(height: 10),
                  ..._requests.map((request) {
                    final icon = request.type == TransferRequestType.meat
                        ? CupertinoIcons.square_stack_3d_up_fill
                        : CupertinoIcons.flame_fill;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.of(context).push<
                              TransferRequestStatus>(
                            CupertinoPageRoute(
                              builder: (_) =>
                                  StockTransferDetailScreen(request: request),
                            ),
                          );
                          if (result != null) {
                            _updateStatus(request.id, result);
                          }
                        },
                        child: DriverCard(
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.pastelBrown.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: AppColors.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${request.type.label} — ${request.branchName}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Pick up from: ${request.suggestedSourceBranchName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(request.status)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  request.status.label,
                                  style: TextStyle(
                                    color: _statusColor(request.status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
