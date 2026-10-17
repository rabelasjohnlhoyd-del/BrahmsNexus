import 'package:flutter/material.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/meat_dispatch.dart';
import '../../../models/supply_request.dart';
import '../../../services/excel_export_service.dart';
import '../admin_web_colors.dart';

/// Modal dialog for previewing and downloading the Inventory & Commissary Audit Sheet (.xlsx).
class InventoryExportDialog extends StatefulWidget {
  final List<KarneBatch> batches;
  final List<BranchMeatStock> branchStocks;
  final List<MeatDispatch> dispatches;
  final List<SupplyRequest> supplyRequests;

  const InventoryExportDialog({
    super.key,
    required this.batches,
    required this.branchStocks,
    required this.dispatches,
    required this.supplyRequests,
  });

  static Future<void> show(
    BuildContext context, {
    required List<KarneBatch> batches,
    required List<BranchMeatStock> branchStocks,
    required List<MeatDispatch> dispatches,
    required List<SupplyRequest> supplyRequests,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => InventoryExportDialog(
        batches: batches,
        branchStocks: branchStocks,
        dispatches: dispatches,
        supplyRequests: supplyRequests,
      ),
    );
  }

  @override
  State<InventoryExportDialog> createState() => _InventoryExportDialogState();
}

class _InventoryExportDialogState extends State<InventoryExportDialog> {
  bool _isGenerating = false;

  Future<void> _handleDownload() async {
    setState(() => _isGenerating = true);
    try {
      await ExcelExportService.exportInventoryAuditReport(
        batches: widget.batches,
        branchStocks: widget.branchStocks,
        dispatches: widget.dispatches,
        supplyRequests: widget.supplyRequests,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Matagumpay na na-download ang Inventory Audit Report (.xlsx)!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate Inventory Excel: $e'),
            backgroundColor: AdminWebColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalBatchKg = 0;
    double totalCookedKg = 0;
    for (final b in widget.batches) {
      totalBatchKg += b.totalKilos;
      for (final s in b.sessions) {
        totalCookedKg += s.kilosCooked;
      }
    }
    final remainingWarehouseKg = (totalBatchKg - totalCookedKg).clamp(0, totalBatchKg);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2E7D32), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVENTORY AUDIT EXPORT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                Text(
                  'Multi-Sheet Excel (.xlsx) Stock & Meat Reconciliation',
                  style: TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'I-export ang kumpletong estado ng bodega, karne, mga sangay, at mga dispatch transfer para sa financial reconciliation at cost-of-goods accounting:',
              style: TextStyle(fontSize: 12.5, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 16),
            // Metrics Preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminWebColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminWebColors.border),
              ),
              child: Column(
                children: [
                  _metricRow('Monthly Batches Tracked', '${widget.batches.length} Batch(es)', Icons.calendar_month_rounded),
                  const Divider(height: 16),
                  _metricRow('Total Meat in Warehouse', '${remainingWarehouseKg.toStringAsFixed(1)} KG left of ${totalBatchKg.toStringAsFixed(0)} KG', Icons.scale_rounded),
                  const Divider(height: 16),
                  _metricRow('Branch Outlets Monitored', '${widget.branchStocks.length} Stores', Icons.storefront_rounded),
                  const Divider(height: 16),
                  _metricRow('Transfer & Dispatch Logs', '${widget.dispatches.length} Record(s)', Icons.local_shipping_outlined),
                  const Divider(height: 16),
                  _metricRow('Branch Supply Requests', '${widget.supplyRequests.length} Request(s)', Icons.assignment_outlined),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF2E7D32)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'May kasamang 4 worksheets: Commissary Batches, Branch Meat Stocks, Dispatch Logs, at Supply Requests.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : _handleDownload,
          icon: _isGenerating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_isGenerating ? 'Generating Excel...' : 'Download Inventory Excel (.xlsx)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _metricRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminWebColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.textPrimary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminWebColors.textPrimary),
        ),
      ],
    );
  }
}
