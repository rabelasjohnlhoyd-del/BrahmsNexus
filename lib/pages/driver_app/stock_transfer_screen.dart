import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, ScaffoldMessenger, SnackBar;
import '../../models/meat_dispatch.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_pagination_bar.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/driver_top_actions.dart';

/// StockTransferPage — shows pending meat dispatches from Owner/Admin.
/// Driver sees the list, then taps "Delivered" once stock is handed over.
/// Real-time: once delivered, the branch inventory updates instantly on
/// all connected apps (Owner, Admin Web, Staff).
class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  int _pendingPage = 0;
  int _deliveredPage = 0;
  static const int _pageSize = 5;
  StreamSubscription<List<MeatDispatch>>? _dispatchesSub;
  List<MeatDispatch> _dispatches = [];
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _dispatchesSub = FirestoreService.watchMeatDispatches().listen((all) {
      if (mounted) {
        setState(() {
          // Show pending dispatches first, then recently delivered ones
          _dispatches = all;
        });
      }
    });
  }

  @override
  void dispose() {
    _dispatchesSub?.cancel();
    super.dispose();
  }

  Future<void> _markDelivered(MeatDispatch dispatch) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('I-confirm ang Delivery?'),
        content: Text(
          'Naihatid na ba ang karne sa ${dispatch.destinationBranchName}?\n\n${dispatch.itemsSummary}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hindi pa'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oo, Naihatid na!'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(dispatch.id));
    final success = await FirestoreService.markDispatchAsDelivered(dispatch);
    if (mounted) {
      setState(() => _processingIds.remove(dispatch.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Na-deliver na! Nag-update na ang inventory ng ${dispatch.destinationBranchName}.'
                : 'May error. Subukan ulit.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _dispatches.where((d) => !d.isDelivered).toList();
    final delivered = _dispatches.where((d) => d.isDelivered).toList();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Stock Transfer',
        trailing: DriverTopActions(),
      ),
      child: SafeArea(
        child: _dispatches.isEmpty
            ? _buildEmptyState()
            : Builder(
                builder: (context) {
                  final pendingTotal = pending.length;
                  final pendingPages = (pendingTotal / _pageSize).ceil();
                  final effectivePendingPage = pendingPages == 0 ? 0 : _pendingPage.clamp(0, pendingPages - 1);
                  final pagedPending = pending.skip(effectivePendingPage * _pageSize).take(_pageSize).toList();

                  final deliveredTotal = delivered.length;
                  final deliveredPages = (deliveredTotal / _pageSize).ceil();
                  final effectiveDeliveredPage = deliveredPages == 0 ? 0 : _deliveredPage.clamp(0, deliveredPages - 1);
                  final pagedDelivered = delivered.skip(effectiveDeliveredPage * _pageSize).take(_pageSize).toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pending.isNotEmpty) ...[
                        const DriverSectionHeader(
                          label: 'Pending Deliveries',
                          icon: CupertinoIcons.arrow_up_bin_fill,
                        ),
                        const SizedBox(height: 12),
                        ...pagedPending.map((d) => _buildDispatchCard(d)),
                        AppPaginationBar(
                          currentPage: effectivePendingPage,
                          totalItems: pendingTotal,
                          pageSize: _pageSize,
                          onPageChanged: (page) => setState(() => _pendingPage = page),
                        ),
                      ],
                      if (delivered.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const DriverSectionHeader(
                          label: 'Naihatid Na',
                          icon: CupertinoIcons.checkmark_shield_fill,
                        ),
                        const SizedBox(height: 12),
                        ...pagedDelivered.map((d) => _buildDispatchCard(d)),
                        AppPaginationBar(
                          currentPage: effectiveDeliveredPage,
                          totalItems: deliveredTotal,
                          pageSize: _pageSize,
                          onPageChanged: (page) => setState(() => _deliveredPage = page),
                        ),
                      ],
                    ],
                  );
                },
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
            const Text('Walang Dispatch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Wala pang pending na meat dispatch mula sa Owner.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchCard(MeatDispatch dispatch) {
    final isDelivered = dispatch.isDelivered;
    final isProcessing = _processingIds.contains(dispatch.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DriverCard(
        highlighted: isDelivered,
        borderColor: isDelivered ? AppColors.success : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isDelivered ? AppColors.success : AppColors.accent).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.square_stack_3d_up_fill,
                    size: 18,
                    color: isDelivered ? AppColors.success : AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispatch.destinationBranchName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${dispatch.createdAt.month}/${dispatch.createdAt.day} · ${dispatch.createdAt.hour.toString().padLeft(2, '0')}:${dispatch.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isDelivered)
                  const Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success, size: 22),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Meat variant breakdown
            if (dispatch.regular250gPcs > 0) ...[
              _buildVariantRow('250g Regular', dispatch.regular250gPcs),
              const SizedBox(height: 6),
            ],
            if (dispatch.medium300gPcs > 0) ...[
              _buildVariantRow('300g Medium', dispatch.medium300gPcs),
              const SizedBox(height: 6),
            ],
            if (dispatch.b1t1_400gPcs > 0) ...[
              _buildVariantRow('400g B1T1', dispatch.b1t1_400gPcs),
              const SizedBox(height: 6),
            ],

            // Supplies breakdown
            if (dispatch.mayoPcs > 0) ...[
              _buildVariantRow('Mayo', dispatch.mayoPcs),
              const SizedBox(height: 6),
            ],
            if (dispatch.styroPcs > 0) ...[
              _buildVariantRow('Styro', dispatch.styroPcs),
              const SizedBox(height: 6),
            ],
            if (dispatch.toyoPcs > 0) ...[
              _buildVariantRow('Toyo', dispatch.toyoPcs),
              const SizedBox(height: 6),
            ],

            const SizedBox(height: 6),

            // Total + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meat Total: ${dispatch.totalPcs} pcs',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.accent),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isDelivered ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDelivered ? 'DELIVERED' : 'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDelivered ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),

            // Deliver button (only for pending)
            if (!isDelivered) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: isProcessing ? CupertinoColors.systemGrey3 : AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: isProcessing ? null : () => _markDelivered(dispatch),
                  child: isProcessing
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text(
                          'Naihatid na ✓',
                          style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVariantRow(String label, int pcs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Text('$pcs pcs', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ],
    );
  }
}
