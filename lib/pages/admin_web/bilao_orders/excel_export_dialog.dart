import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/bilao_order.dart';
import '../../../models/branch.dart';
import '../../../services/excel_export_service.dart';
import '../admin_web_colors.dart';

/// Interactive Modal Dialog for filtering and downloading the
/// Executive Audit Report (.xlsx) for Brahms Food Ventures.
class ExcelExportDialog extends StatefulWidget {
  final List<BilaoOrder> allOrders;

  const ExcelExportDialog({
    super.key,
    required this.allOrders,
  });

  static Future<void> show(BuildContext context, {required List<BilaoOrder> orders}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ExcelExportDialog(allOrders: orders),
    );
  }

  @override
  State<ExcelExportDialog> createState() => _ExcelExportDialogState();
}

enum _DateFilterPreset {
  allTime,
  today,
  thisWeek,
  firstCutoff,
  secondCutoff,
  thisMonth,
  custom,
}

class _ExcelExportDialogState extends State<ExcelExportDialog> {
  _DateFilterPreset _selectedPreset = _DateFilterPreset.thisMonth;
  String _selectedBranch = 'All Branches';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _applyPreset(_DateFilterPreset.thisMonth);
  }

  void _applyPreset(_DateFilterPreset preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case _DateFilterPreset.allTime:
          _customStartDate = null;
          _customEndDate = null;
          break;
        case _DateFilterPreset.today:
          _customStartDate = DateTime(now.year, now.month, now.day);
          _customEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _DateFilterPreset.thisWeek:
          final monday = now.subtract(Duration(days: now.weekday - 1));
          _customStartDate = DateTime(monday.year, monday.month, monday.day);
          _customEndDate = now;
          break;
        case _DateFilterPreset.firstCutoff:
          _customStartDate = DateTime(now.year, now.month, 1);
          _customEndDate = DateTime(now.year, now.month, 15, 23, 59, 59);
          break;
        case _DateFilterPreset.secondCutoff:
          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          _customStartDate = DateTime(now.year, now.month, 16);
          _customEndDate = DateTime(now.year, now.month, lastDay, 23, 59, 59);
          break;
        case _DateFilterPreset.thisMonth:
          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          _customStartDate = DateTime(now.year, now.month, 1);
          _customEndDate = DateTime(now.year, now.month, lastDay, 23, 59, 59);
          break;
        case _DateFilterPreset.custom:
          // Keep current dates
          break;
      }
    });
  }

  List<BilaoOrder> get _matchingOrders {
    return widget.allOrders.where((order) {
      if (_selectedBranch != 'All Branches') {
        final bName = order.pickupBranchName ?? '';
        if (!bName.toLowerCase().contains(_selectedBranch.toLowerCase())) {
          return false;
        }
      }
      if (_customStartDate != null && order.scheduledDateTime.isBefore(_customStartDate!)) {
        return false;
      }
      if (_customEndDate != null &&
          order.scheduledDateTime.isAfter(_customEndDate!.add(const Duration(seconds: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  double get _matchingRevenue {
    double total = 0.0;
    for (final o in _matchingOrders) {
      if (!o.isCancelled) {
        total += o.size.price * (o.quantity > 0 ? o.quantity : 1);
      }
    }
    return total;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? now.subtract(const Duration(days: 7)),
        end: _customEndDate ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminWebColors.accent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = _DateFilterPreset.custom;
        _customStartDate = picked.start;
        _customEndDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isGenerating = true);
    try {
      await ExcelExportService.exportBilaoOrdersAuditReport(
        orders: widget.allOrders,
        startDate: _customStartDate,
        endDate: _customEndDate,
        selectedBranchName: _selectedBranch,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Matagumpay na na-download ang Bilao Orders Audit Report (.xlsx)!'),
            backgroundColor: AdminWebColors.success,
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
            content: Text('Failed to generate Excel: $e'),
            backgroundColor: AdminWebColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matchingOrders;
    final totalRev = _matchingRevenue;
    final df = DateFormat('MMM d, yyyy');

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
              color: AdminWebColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_view_rounded, color: AdminWebColors.accent, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BILAO ORDERS AUDIT EXPORT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                Text(
                  'Multi-Sheet Bilao Orders & Cook Commission Report (.xlsx)',
                  style: TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '1. PILIIN ANG SANGAY (BRANCH SCOPE):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AdminWebColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminWebColors.border),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBranch,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminWebColors.accent),
                    items: [
                      'All Branches',
                      for (final b in kSampleBranches) b.fullName,
                    ].map((name) {
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(
                          name == 'All Branches' ? '🌟 All 6 Branches (Consolidated Master Report)' : name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: name == 'All Branches' ? FontWeight.w700 : FontWeight.w500,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBranch = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '2. PILIIN ANG PETSA O CUT-OFF PERIOD:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AdminWebColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip('All Time', _DateFilterPreset.allTime),
                  _presetChip('Today', _DateFilterPreset.today),
                  _presetChip('This Week', _DateFilterPreset.thisWeek),
                  _presetChip('1st-15th Cutoff', _DateFilterPreset.firstCutoff),
                  _presetChip('16th-End Cutoff', _DateFilterPreset.secondCutoff),
                  _presetChip('This Month', _DateFilterPreset.thisMonth),
                  _presetChip('Custom Range...', _DateFilterPreset.custom, isPicker: true),
                ],
              ),
              const SizedBox(height: 14),
              // Current Period Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AdminWebColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminWebColors.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AdminWebColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _customStartDate != null && _customEndDate != null
                            ? '${df.format(_customStartDate!)}  —  ${df.format(_customEndDate!)}'
                            : 'All Recorded Transactions (Complete Ledger)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary),
                      ),
                    ),
                    if (_selectedPreset == _DateFilterPreset.custom)
                      InkWell(
                        onTap: _pickDateRange,
                        child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminWebColors.accent)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Live Preview Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AdminWebColors.accent.withValues(alpha: 0.08),
                      AdminWebColors.accent.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MATCHING ORDERS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary)),
                          const SizedBox(height: 3),
                          Text('${matches.length} Bilao Orders', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminWebColors.textPrimary)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: AdminWebColors.border),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESTIMATED VALUE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary)),
                          const SizedBox(height: 3),
                          Text(
                            '\u20b1${totalRev.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminWebColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isGenerating || matches.isEmpty ? null : _handleExport,
          icon: _isGenerating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_isGenerating ? 'Generating Excel...' : 'Download Bilao Orders Audit (.xlsx)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminWebColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _presetChip(String label, _DateFilterPreset preset, {bool isPicker = false}) {
    final isSelected = _selectedPreset == preset;
    return InkWell(
      onTap: () {
        if (isPicker) {
          _pickDateRange();
        } else {
          _applyPreset(preset);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AdminWebColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AdminWebColors.accent : AdminWebColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AdminWebColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
