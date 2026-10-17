import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/branch.dart';
import '../../../models/sales_record.dart';
import '../../../services/excel_export_service.dart';
import '../admin_web_colors.dart';

/// Interactive modal dialog for previewing, filtering, and downloading the
/// dedicated Sales & Payroll Audit Report (.xlsx) for Brahms Food Ventures.
class SalesPayrollExportDialog extends StatefulWidget {
  final List<SalesRecord> records;
  final double cookRate;
  final double cutterRate;
  final double driverRate;
  final int driverDays;
  final int cookingSessions;

  const SalesPayrollExportDialog({
    super.key,
    required this.records,
    this.cookRate = 1100.0,
    this.cutterRate = 1100.0,
    this.driverRate = 650.0,
    this.driverDays = 25,
    this.cookingSessions = 7,
  });

  static Future<void> show(
    BuildContext context, {
    required List<SalesRecord> records,
    double cookRate = 1100.0,
    double cutterRate = 1100.0,
    double driverRate = 650.0,
    int driverDays = 25,
    int cookingSessions = 7,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SalesPayrollExportDialog(
        records: records,
        cookRate: cookRate,
        cutterRate: cutterRate,
        driverRate: driverRate,
        driverDays: driverDays,
        cookingSessions: cookingSessions,
      ),
    );
  }

  @override
  State<SalesPayrollExportDialog> createState() => _SalesPayrollExportDialogState();
}

enum _PayrollDateFilterPreset {
  allTime,
  today,
  thisWeek,
  firstCutoff,
  secondCutoff,
  thisMonth,
  custom,
}

class _SalesPayrollExportDialogState extends State<SalesPayrollExportDialog> {
  _PayrollDateFilterPreset _selectedPreset = _PayrollDateFilterPreset.thisMonth;
  String _selectedBranch = 'All Branches';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isGenerating = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _applyPreset(_PayrollDateFilterPreset.thisMonth);
  }

  void _applyPreset(_PayrollDateFilterPreset preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case _PayrollDateFilterPreset.allTime:
          _customStartDate = null;
          _customEndDate = null;
          break;
        case _PayrollDateFilterPreset.today:
          _customStartDate = DateTime(now.year, now.month, now.day);
          _customEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _PayrollDateFilterPreset.thisWeek:
          final monday = now.subtract(Duration(days: now.weekday - 1));
          _customStartDate = DateTime(monday.year, monday.month, monday.day);
          _customEndDate = now;
          break;
        case _PayrollDateFilterPreset.firstCutoff:
          _customStartDate = DateTime(now.year, now.month, 1);
          _customEndDate = DateTime(now.year, now.month, 15, 23, 59, 59);
          break;
        case _PayrollDateFilterPreset.secondCutoff:
          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          _customStartDate = DateTime(now.year, now.month, 16);
          _customEndDate = DateTime(now.year, now.month, lastDay, 23, 59, 59);
          break;
        case _PayrollDateFilterPreset.thisMonth:
          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          _customStartDate = DateTime(now.year, now.month, 1);
          _customEndDate = DateTime(now.year, now.month, lastDay, 23, 59, 59);
          break;
        case _PayrollDateFilterPreset.custom:
          break;
      }
    });
  }

  List<SalesRecord> get _matchingRecords {
    return widget.records.where((r) {
      if (_selectedBranch != 'All Branches') {
        if (!r.branchName.toLowerCase().contains(_selectedBranch.toLowerCase())) {
          return false;
        }
      }
      if (_customStartDate != null && r.date.isBefore(_customStartDate!)) {
        return false;
      }
      if (_customEndDate != null && r.date.isAfter(_customEndDate!)) {
        return false;
      }
      return true;
    }).toList();
  }

  double get _matchingSales =>
      _matchingRecords.fold(0.0, (sum, r) => sum + r.totalSalesAmount);

  double get _matchingWages =>
      _matchingRecords.fold(0.0, (sum, r) => sum + r.computedWage);

  double get _matchingRemittance =>
      _matchingRecords.fold(0.0, (sum, r) => sum + r.expectedCashRemittance);

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _customEndDate ?? DateTime.now(),
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
        _selectedPreset = _PayrollDateFilterPreset.custom;
        _customStartDate = picked.start;
        _customEndDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isGenerating = true);
    try {
      await ExcelExportService.exportSalesPayrollAuditReport(
        records: widget.records,
        cookRate: widget.cookRate,
        cutterRate: widget.cutterRate,
        driverRate: widget.driverRate,
        driverDays: widget.driverDays,
        cookingSessions: widget.cookingSessions,
        startDate: _customStartDate,
        endDate: _customEndDate,
        selectedBranchName: _selectedBranch,
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
                    'Matagumpay na na-download ang Sales & Payroll Audit Report (.xlsx)!',
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
            content: Text('Failed to generate Sales & Payroll Excel: $e'),
            backgroundColor: AdminWebColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matchingRecords;
    final totalSales = _matchingSales;
    final totalWages = _matchingWages;
    final totalRemit = _matchingRemittance;
    final df = DateFormat('MMM d, yyyy');

    final productionStaffSubtotal =
        (widget.cookRate * widget.cookingSessions) + (widget.cutterRate * widget.cookingSessions);
    final driverSubtotal = widget.driverRate * widget.driverDays;
    final commissaryPayroll = productionStaffSubtotal + driverSubtotal;

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
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2E7D32), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SALES & PAYROLL AUDIT EXPORT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                Text(
                  'Multi-Sheet Store Sales, Cash Remittance & Staff Payroll (.xlsx)',
                  style: TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminWebColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBranch,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AdminWebColors.accent),
                    items: [
                      const DropdownMenuItem(
                        value: 'All Branches',
                        child: Text('All Branches (Lahat ng 6 Sangay)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      ...kSampleBranches.map((b) => DropdownMenuItem(
                            value: b.name,
                            child: Text(b.name, style: const TextStyle(fontSize: 13)),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBranch = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '2. PILIIN ANG DATE RANGE O CUT-OFF PERIOD:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AdminWebColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip('This Month', _PayrollDateFilterPreset.thisMonth),
                  _presetChip('1st Cutoff (1-15)', _PayrollDateFilterPreset.firstCutoff),
                  _presetChip('2nd Cutoff (16-End)', _PayrollDateFilterPreset.secondCutoff),
                  _presetChip('This Week', _PayrollDateFilterPreset.thisWeek),
                  _presetChip('Today', _PayrollDateFilterPreset.today),
                  _presetChip('All Time', _PayrollDateFilterPreset.allTime),
                  _presetChip(
                    _selectedPreset == _PayrollDateFilterPreset.custom && _customStartDate != null
                        ? '${df.format(_customStartDate!)} - ${df.format(_customEndDate!)}'
                        : 'Custom Range...',
                    _PayrollDateFilterPreset.custom,
                    isPicker: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Live Audit Preview Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminWebColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminWebColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 16, color: AdminWebColors.accent),
                        const SizedBox(width: 6),
                        const Text(
                          'EXECUTIVE AUDIT PREVIEW',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AdminWebColors.textPrimary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${matches.length} Shifts Selected',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _previewRow('Gross Store Sales:', _currencyFormat.format(totalSales), isBold: true),
                    const SizedBox(height: 6),
                    _previewRow('Branch Cook Wages & Bilao Comm.:', _currencyFormat.format(totalWages), color: const Color(0xFFC2410C)),
                    const SizedBox(height: 6),
                    _previewRow('Cash Remittance to Owner:', _currencyFormat.format(totalRemit), color: const Color(0xFF047857), isBold: true),
                    const SizedBox(height: 6),
                    _previewRow('Commissary & Driver Payroll:', _currencyFormat.format(commissaryPayroll)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AdminWebColors.border.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AdminWebColors.textSecondary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Naglalaman ng 4 sheets: (1) Daily Sales & Remittance, (2) Branch Cooks Payroll, (3) Production & Driver Payroll, (4) Sales & Payroll Summary.',
                              style: TextStyle(fontSize: 10.5, color: AdminWebColors.textSecondary),
                            ),
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
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AdminWebColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : _handleExport,
          icon: _isGenerating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded, size: 16),
          label: Text(_isGenerating ? 'Generating Excel...' : 'Download Sales & Payroll (.xlsx)'),
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

  Widget _previewRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: AdminWebColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AdminWebColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _presetChip(String label, _PayrollDateFilterPreset preset, {bool isPicker = false}) {
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
          color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E7D32) : AdminWebColors.border,
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
