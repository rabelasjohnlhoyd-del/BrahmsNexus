import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/bilao_order.dart';
import '../models/branch.dart';
import '../models/sales_record.dart';
import '../models/inventory_batch.dart';
import '../models/branch_meat_inventory.dart';
import '../models/meat_dispatch.dart';
import '../models/supply_request.dart';
import '../models/financial_period.dart';
import 'excel_download_helper.dart';

/// Enterprise-grade Excel Export Engine for Brahms Food Ventures (Admin Web).
/// Generates multi-sheet .xlsx audit workbooks formatted for business owners,
/// financial auditing, BIR reconciliation, and final capstone defense.
class ExcelExportService {
  const ExcelExportService._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _shortDate = DateFormat('yyyy-MM-dd');
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  // ── UNIFIED EXECUTIVE CORPORATE PALETTE (Slate Navy Theme) ───────────────
  static final CellStyle _titleStyle = CellStyle(
    bold: true,
    fontSize: 13,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0F172A'),
  );

  static final CellStyle _headerStyle = CellStyle(
    bold: true,
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
  );

  static final CellStyle _sectionHeaderStyle = CellStyle(
    bold: true,
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#334155'),
  );

  static final CellStyle _subtotalStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#0F172A'),
    backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
  );

  static final CellStyle _grandTotalStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0F172A'),
  );

  static final CellStyle _metricLabelStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#334155'),
  );

  static final CellStyle _highlightMetricStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#0F172A'),
    backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
  );

  /// Generates and immediately downloads a comprehensive Executive Audit Report (.xlsx).
  static Future<void> exportExecutiveAuditReport({
    required List<BilaoOrder> orders,
    List<SalesRecord>? salesRecords,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedBranchName,
  }) async {
    final excel = Excel.createExcel();

    // Remove default 'Sheet1' once we create our custom sheets
    const defaultSheet = 'Sheet1';

    // Filter orders if date range or branch filter was specified
    final filteredOrders = orders.where((order) {
      if (selectedBranchName != null &&
          selectedBranchName != 'All Branches' &&
          selectedBranchName.isNotEmpty) {
        final bName = order.pickupBranchName ?? '';
        if (!bName.toLowerCase().contains(selectedBranchName.toLowerCase())) {
          return false;
        }
      }
      if (startDate != null && order.scheduledDateTime.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && order.scheduledDateTime.isAfter(endDate.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();

    // ── 1. SHEET 1: Executive KPI Summary ──────────────────────────────────
    _buildExecutiveSummarySheet(
      excel: excel,
      sheetName: 'Executive KPI Summary',
      orders: filteredOrders,
      startDate: startDate,
      endDate: endDate,
      selectedBranchName: selectedBranchName,
    );

    // ── 2. SHEET 2: Bilao Orders & Omnichannel Intake ──────────────────────
    _buildBilaoOrdersSheet(
      excel: excel,
      sheetName: 'Bilao Orders & Intake',
      orders: filteredOrders,
    );

    // ── 3. SHEET 3: Branch Performance & Breakdown ─────────────────────────
    _buildBranchBreakdownSheet(
      excel: excel,
      sheetName: 'Branch Sales Breakdown',
      orders: filteredOrders,
    );

    // ── 4. SHEET 4: Cook Commissions & Kitchen Log ─────────────────────────
    _buildCookCommissionsSheet(
      excel: excel,
      sheetName: 'Cook Commission Ledger',
      orders: filteredOrders,
    );

    // Remove the default empty Sheet1 if other sheets exist
    if (excel.sheets.containsKey(defaultSheet) && excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    // Save and download file
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Brahms_Bilao_Orders_Audit_$nowStr.xlsx';
      await saveAndLaunchExcel(Uint8List.fromList(fileBytes), fileName);
    }
  }

  /// Alias for exportExecutiveAuditReport explicitly named for Bilao Orders.
  static Future<void> exportBilaoOrdersAuditReport({
    required List<BilaoOrder> orders,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedBranchName,
  }) =>
      exportExecutiveAuditReport(
        orders: orders,
        startDate: startDate,
        endDate: endDate,
        selectedBranchName: selectedBranchName,
      );

  // ===========================================================================
  // SHEET 1: Executive KPI Summary
  // ===========================================================================
  static void _buildExecutiveSummarySheet({
    required Excel excel,
    required String sheetName,
    required List<BilaoOrder> orders,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedBranchName,
  }) {
    final sheet = excel[sheetName];

    // Compute key figures
    int totalBilaoCount = 0;
    double grossRevenue = 0.0;
    double totalCash = 0.0;
    double totalGcash = 0.0;
    double totalDeposit = 0.0;
    double totalCookCommissions = 0.0;
    int awaitingGcashCount = 0;

    int smallCount = 0;
    int mediumCount = 0;
    int largeCount = 0;

    for (final o in orders) {
      if (o.isCancelled) continue;
      final qty = o.quantity > 0 ? o.quantity : 1;
      totalBilaoCount += qty;
      final orderVal = o.size.price * qty;
      grossRevenue += orderVal;
      totalDeposit += o.depositAmount;

      if (o.paymentMethod == PaymentMethod.gcash) {
        totalGcash += orderVal;
      } else {
        totalCash += orderVal;
      }

      if (o.orderChannel == BilaoOrderChannel.branchOrder) {
        totalCookCommissions += (o.size.commission * qty);
      }

      if (o.paymentMethod == PaymentMethod.gcash && !o.gcashVerified) {
        awaitingGcashCount++;
      }

      switch (o.size) {
        case BilaoSize.small:
          smallCount += qty;
          break;
        case BilaoSize.medium:
          mediumCount += qty;
          break;
        case BilaoSize.large:
          largeCount += qty;
          break;
      }
    }

    final netRevenueEstimate = grossRevenue - totalCookCommissions;

    // Row 0: Title Banner
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('BRAHMS FOOD VENTURES — EXECUTIVE AUDIT REPORT');
    titleCell.cellStyle = _titleStyle;

    // Row 1: Subtitle
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      .value = TextCellValue('Generated on: ${_dateFormat.format(DateTime.now())}');

    final periodLabel = (startDate != null && endDate != null)
        ? 'Filter Period: ${_shortDate.format(startDate)} to ${_shortDate.format(endDate)}'
        : 'Filter Period: All Recorded Time';
    final branchLabel = selectedBranchName != null && selectedBranchName.isNotEmpty
        ? 'Branch Scope: $selectedBranchName'
        : 'Branch Scope: All 6 Outlets';

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      .value = TextCellValue('$periodLabel | $branchLabel');

    // Section 1: Financial Performance
    int row = 4;
    final s1Header0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    s1Header0.value = TextCellValue('KEY FINANCIAL METRICS');
    s1Header0.cellStyle = _sectionHeaderStyle;

    final s1Header1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    s1Header1.value = TextCellValue('AMOUNT / VALUE');
    s1Header1.cellStyle = _sectionHeaderStyle;

    final s1Header2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    s1Header2.value = TextCellValue('AUDIT REMARKS');
    s1Header2.cellStyle = _sectionHeaderStyle;
    row++;

    _writeKpiRow(sheet, row++, 'Gross Revenue (Total Benta)', _currency.format(grossRevenue), 'Total value of all confirmed bilao orders');
    _writeKpiRow(sheet, row++, 'Total Cash Collections (In-Store)', _currency.format(totalCash), 'Walk-in branch customer cash intake');
    _writeKpiRow(sheet, row++, 'Total GCash Collections (Digital Intake)', _currency.format(totalGcash), 'Advance & full digital payments');
    _writeKpiRow(sheet, row++, 'Total Initial Deposits / Downpayments', _currency.format(totalDeposit), 'Advance partial deposits recorded');
    _writeKpiRow(sheet, row++, 'Total Cook Commissions Payable', _currency.format(totalCookCommissions), 'Incentive payable to branch cooks (₱30/₱40/₱50)');
    _writeKpiRow(sheet, row++, 'ESTIMATED NET OPERATING REVENUE', _currency.format(netRevenueEstimate), 'Gross revenue minus cook incentives', isHighlight: true);

    // Section 2: Order Fulfillment & Volumes
    row += 2;
    final s2Header0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    s2Header0.value = TextCellValue('VOLUME & PRODUCTION METRICS');
    s2Header0.cellStyle = _sectionHeaderStyle;

    final s2Header1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    s2Header1.value = TextCellValue('RECORDED COUNT');
    s2Header1.cellStyle = _sectionHeaderStyle;

    final s2Header2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    s2Header2.value = TextCellValue('SPECIFICATIONS');
    s2Header2.cellStyle = _sectionHeaderStyle;
    row++;

    _writeKpiRow(sheet, row++, 'Total Bilao Units Sold', '$totalBilaoCount units', 'Aggregate volume sold');
    _writeKpiRow(sheet, row++, 'Small Bilao (10 Pax)', '$smallCount units', '₱650 unit price');
    _writeKpiRow(sheet, row++, 'Medium Bilao (15 Pax)', '$mediumCount units', '₱900 unit price');
    _writeKpiRow(sheet, row++, 'Large Bilao (20 Pax)', '$largeCount units', '₱1,300 unit price');
    _writeKpiRow(sheet, row++, 'Orders Awaiting GCash Proof', '$awaitingGcashCount order(s)', 'Kitchen lock pending proof verification');

    // Auto fit column widths
    sheet.setColumnWidth(0, 44.0);
    sheet.setColumnWidth(1, 26.0);
    sheet.setColumnWidth(2, 42.0);
  }

  static void _writeKpiRow(
    Sheet sheet,
    int row,
    String label,
    String value,
    String remarks, {
    bool isHighlight = false,
  }) {
    final cell0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell0.value = TextCellValue(label);
    cell0.cellStyle = isHighlight ? _highlightMetricStyle : _metricLabelStyle;

    final cell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    cell1.value = TextCellValue(value);
    if (isHighlight) cell1.cellStyle = _highlightMetricStyle;

    final cell2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    cell2.value = TextCellValue(remarks);
    if (isHighlight) cell2.cellStyle = _highlightMetricStyle;
  }

  // ===========================================================================
  // SHEET 2: Bilao Orders & Intake Details
  // ===========================================================================
  static void _buildBilaoOrdersSheet({
    required Excel excel,
    required String sheetName,
    required List<BilaoOrder> orders,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Order Ref ID',
      'Scheduled Date & Time',
      'Customer Name',
      'Contact Number',
      'Order Channel',
      'Fulfillment',
      'Branch Outlet',
      'Bilao Size',
      'Unit Price (₱)',
      'Qty',
      'Total Value (₱)',
      'Deposit Paid (₱)',
      'Payment Method',
      'GCash Ref No.',
      'GCash Verification',
      'Prep Status',
      'Delivery Status',
      'Delivery Address / Customer Notes',
    ];

    // Write Headers
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;
    double totalSum = 0.0;
    double totalDeposits = 0.0;
    int totalQty = 0;

    for (final order in orders) {
      final qty = order.quantity > 0 ? order.quantity : 1;
      final itemPrice = order.size.price;
      final orderVal = itemPrice * qty;
      totalSum += orderVal;
      totalDeposits += order.depositAmount;
      totalQty += qty;

      final branchDisplay = order.pickupBranchName != null && order.pickupBranchName!.isNotEmpty
          ? order.pickupBranchName!
          : (kSampleBranches.firstWhere(
              (b) => b.id == order.pickupBranchId,
              orElse: () => kSampleBranches.first,
            ).fullName);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(order.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(_dateFormat.format(order.scheduledDateTime));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = TextCellValue(order.customerName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = TextCellValue(order.contactNumber);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = TextCellValue(order.orderChannel.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = TextCellValue(order.fulfillmentType.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = TextCellValue(branchDisplay);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        .value = TextCellValue(order.size.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        .value = DoubleCellValue(itemPrice);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        .value = IntCellValue(qty);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        .value = DoubleCellValue(orderVal);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
        .value = DoubleCellValue(order.depositAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row))
        .value = TextCellValue(order.paymentMethod.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row))
        .value = TextCellValue(order.gcashRefNumber ?? 'N/A');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: row))
        .value = TextCellValue(order.gcashVerified ? 'VERIFIED' : 'AWAITING PROOF');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: row))
        .value = TextCellValue(order.preparationStatus.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: row))
        .value = TextCellValue(order.deliveryStatus.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: row))
        .value = TextCellValue(order.notes ?? order.deliveryAddress);

      row++;
    }

    // Total Row at the bottom
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL BILAO SALES');
    totalCell.cellStyle = _grandTotalStyle;

    for (int col = 1; col <= 8; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    final totalQtyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row));
    totalQtyCell.value = IntCellValue(totalQty);
    totalQtyCell.cellStyle = _grandTotalStyle;

    final totalSumCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row));
    totalSumCell.value = DoubleCellValue(totalSum);
    totalSumCell.cellStyle = _grandTotalStyle;

    final totalDepCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row));
    totalDepCell.value = DoubleCellValue(totalDeposits);
    totalDepCell.cellStyle = _grandTotalStyle;

    for (int col = 12; col <= 17; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    // Explicit widths for ALL 18 columns with generous padding
    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 22.0);
    sheet.setColumnWidth(2, 26.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 22.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 28.0);
    sheet.setColumnWidth(7, 16.0);
    sheet.setColumnWidth(8, 16.0);
    sheet.setColumnWidth(9, 12.0);
    sheet.setColumnWidth(10, 20.0);
    sheet.setColumnWidth(11, 20.0);
    sheet.setColumnWidth(12, 18.0);
    sheet.setColumnWidth(13, 22.0);
    sheet.setColumnWidth(14, 18.0);
    sheet.setColumnWidth(15, 18.0);
    sheet.setColumnWidth(16, 18.0);
    sheet.setColumnWidth(17, 40.0);
  }

  // ===========================================================================
  // SHEET 3: Branch Breakdown
  // ===========================================================================
  static void _buildBranchBreakdownSheet({
    required Excel excel,
    required String sheetName,
    required List<BilaoOrder> orders,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Branch Outlet',
      'Small Sold',
      'Medium Sold',
      'Large Sold',
      'Total Bilaos',
      'Gross Sales (₱)',
      'Cook Commissions (₱)',
      'Net Branch Share (₱)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    // Aggregate by branch
    final Map<String, _BranchAggregate> branchMap = {
      for (final b in kSampleBranches)
        b.fullName: _BranchAggregate(name: b.fullName),
    };

    for (final o in orders) {
      if (o.isCancelled) continue;
      final qty = o.quantity > 0 ? o.quantity : 1;
      final bName = o.pickupBranchName != null && o.pickupBranchName!.isNotEmpty
          ? o.pickupBranchName!
          : (kSampleBranches.firstWhere(
              (b) => b.id == o.pickupBranchId,
              orElse: () => kSampleBranches.first,
            ).fullName);

      final agg = branchMap.putIfAbsent(bName, () => _BranchAggregate(name: bName));
      agg.totalQty += qty;
      final val = o.size.price * qty;
      agg.grossRevenue += val;

      if (o.orderChannel == BilaoOrderChannel.branchOrder) {
        agg.cookCommission += (o.size.commission * qty);
      }

      switch (o.size) {
        case BilaoSize.small:
          agg.small += qty;
          break;
        case BilaoSize.medium:
          agg.medium += qty;
          break;
        case BilaoSize.large:
          agg.large += qty;
          break;
      }
    }

    int row = 1;
    int totSmall = 0;
    int totMed = 0;
    int totLarge = 0;
    int totQty = 0;
    double totGross = 0.0;
    double totCommission = 0.0;
    double totNet = 0.0;

    for (final agg in branchMap.values) {
      final netShare = agg.grossRevenue - agg.cookCommission;
      totSmall += agg.small;
      totMed += agg.medium;
      totLarge += agg.large;
      totQty += agg.totalQty;
      totGross += agg.grossRevenue;
      totCommission += agg.cookCommission;
      totNet += netShare;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(agg.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = IntCellValue(agg.small);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = IntCellValue(agg.medium);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = IntCellValue(agg.large);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = IntCellValue(agg.totalQty);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = DoubleCellValue(agg.grossRevenue);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = DoubleCellValue(agg.cookCommission);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        .value = DoubleCellValue(netShare);
      row++;
    }

    // Total Row
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL (ALL OUTLETS)');
    totalCell.cellStyle = _grandTotalStyle;

    final cell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    cell1.value = IntCellValue(totSmall);
    cell1.cellStyle = _grandTotalStyle;

    final cell2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    cell2.value = IntCellValue(totMed);
    cell2.cellStyle = _grandTotalStyle;

    final cell3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    cell3.value = IntCellValue(totLarge);
    cell3.cellStyle = _grandTotalStyle;

    final cell4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    cell4.value = IntCellValue(totQty);
    cell4.cellStyle = _grandTotalStyle;

    final cell5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    cell5.value = DoubleCellValue(totGross);
    cell5.cellStyle = _grandTotalStyle;

    final cell6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
    cell6.value = DoubleCellValue(totCommission);
    cell6.cellStyle = _grandTotalStyle;

    final cell7 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row));
    cell7.value = DoubleCellValue(totNet);
    cell7.cellStyle = _grandTotalStyle;

    sheet.setColumnWidth(0, 30.0);
    sheet.setColumnWidth(1, 16.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 16.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 22.0);
    sheet.setColumnWidth(6, 24.0);
    sheet.setColumnWidth(7, 24.0);
  }

  // ===========================================================================
  // SHEET 4: Cook Commission Ledger
  // ===========================================================================
  static void _buildCookCommissionsSheet({
    required Excel excel,
    required String sheetName,
    required List<BilaoOrder> orders,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Order Ref ID',
      'Schedule Date',
      'Branch Outlet',
      'Bilao Size',
      'Quantity',
      'Channel Eligibility',
      'Cook Commission Rate (₱)',
      'Total Cook Commission (₱)',
      'Cook Status / Notes',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;
    double grandCommission = 0.0;

    for (final o in orders) {
      if (o.isCancelled) continue;
      final qty = o.quantity > 0 ? o.quantity : 1;
      final bool isEligible = o.orderChannel == BilaoOrderChannel.branchOrder;
      final commRate = isEligible ? o.size.commission : 0.0;
      final totalComm = commRate * qty;
      grandCommission += totalComm;

      final branchDisplay = o.pickupBranchName != null && o.pickupBranchName!.isNotEmpty
          ? o.pickupBranchName!
          : (kSampleBranches.firstWhere(
              (b) => b.id == o.pickupBranchId,
              orElse: () => kSampleBranches.first,
            ).fullName);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(o.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(_shortDate.format(o.scheduledDateTime));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = TextCellValue(branchDisplay);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = TextCellValue(o.size.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = IntCellValue(qty);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = TextCellValue(isEligible ? 'Branch Walk-In (+Commission)' : 'Direct-to-Owner (Main Commissary)');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = DoubleCellValue(commRate);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        .value = DoubleCellValue(totalComm);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        .value = TextCellValue(o.preparationStatus.label);

      row++;
    }

    // Bottom Total
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL COMMISSIONS EARNED');
    totalCell.cellStyle = _grandTotalStyle;

    for (int col = 1; col <= 6; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    final commCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row));
    commCell.value = DoubleCellValue(grandCommission);
    commCell.cellStyle = _grandTotalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).cellStyle = _grandTotalStyle;

    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 20.0);
    sheet.setColumnWidth(2, 28.0);
    sheet.setColumnWidth(3, 16.0);
    sheet.setColumnWidth(4, 14.0);
    sheet.setColumnWidth(5, 34.0);
    sheet.setColumnWidth(6, 24.0);
    sheet.setColumnWidth(7, 26.0);
    sheet.setColumnWidth(8, 24.0);
  }

  // ===========================================================================
  // SALES & PAYROLL AUDIT WORKBOOK
  // ===========================================================================

  /// Generates and immediately downloads a comprehensive Sales & Payroll Audit Report (.xlsx).
  static Future<void> exportSalesPayrollAuditReport({
    required List<SalesRecord> records,
    double cookRate = 1100.0,
    double cutterRate = 1100.0,
    double driverRate = 650.0,
    int driverDays = 25,
    int cookingSessions = 7,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedBranchName,
  }) async {
    final excel = Excel.createExcel();
    const defaultSheet = 'Sheet1';

    final filteredRecords = records.where((r) {
      if (selectedBranchName != null &&
          selectedBranchName != 'All Branches' &&
          selectedBranchName != 'All' &&
          selectedBranchName.isNotEmpty) {
        if (!r.branchName.toLowerCase().contains(selectedBranchName.toLowerCase())) {
          return false;
        }
      }
      if (startDate != null && r.date.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && r.date.isAfter(endDate.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();

    filteredRecords.sort((a, b) => b.date.compareTo(a.date));

    // ── 1. SHEET 1: Daily Branch Sales & Cash Remittance ───────────────────
    _buildDailySalesSheet(
      excel: excel,
      sheetName: 'Daily Sales & Remittance',
      records: filteredRecords,
      startDate: startDate,
      endDate: endDate,
      selectedBranchName: selectedBranchName,
    );

    // ── 2. SHEET 2: Branch Cooks Monthly Payroll Summary ───────────────────
    _buildBranchCooksPayrollSheet(
      excel: excel,
      sheetName: 'Branch Cooks Payroll',
      records: filteredRecords,
    );

    // ── 3. SHEET 3: Commissary Production Staff & Driver Payroll ───────────
    _buildProductionDriverPayrollSheet(
      excel: excel,
      sheetName: 'Production & Driver Payroll',
      cookRate: cookRate,
      cutterRate: cutterRate,
      driverRate: driverRate,
      driverDays: driverDays,
      cookingSessions: cookingSessions,
    );

    // ── 4. SHEET 4: Sales & Payroll Summary (Executive KPIs) ───────────────
    _buildSalesPayrollSummarySheet(
      excel: excel,
      sheetName: 'Sales & Payroll Summary',
      records: filteredRecords,
      cookRate: cookRate,
      cutterRate: cutterRate,
      driverRate: driverRate,
      driverDays: driverDays,
      cookingSessions: cookingSessions,
    );

    if (excel.sheets.containsKey(defaultSheet) && excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Brahms_Sales_Payroll_Audit_$nowStr.xlsx';
      await saveAndLaunchExcel(Uint8List.fromList(fileBytes), fileName);
    }
  }

  static void _buildDailySalesSheet({
    required Excel excel,
    required String sheetName,
    required List<SalesRecord> records,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedBranchName,
  }) {
    final sheet = excel[sheetName];

    // Row 0: Title Banner
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('BRAHMS FOOD VENTURES — BRANCH DAILY SALES & REMITTANCE');
    titleCell.cellStyle = _titleStyle;

    // Row 1: Subtitle
    final periodLabel = (startDate != null && endDate != null)
        ? 'Period: ${_shortDate.format(startDate)} to ${_shortDate.format(endDate)}'
        : 'Period: All Recorded Dates';
    final branchLabel = (selectedBranchName != null && selectedBranchName.isNotEmpty && selectedBranchName != 'All Branches')
        ? 'Scope: $selectedBranchName'
        : 'Scope: All 6 Branches';

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      .value = TextCellValue('$branchLabel | $periodLabel | Generated: ${_dateFormat.format(DateTime.now())}');

    // Row 3: Table Headers
    final headers = [
      'Record Ref ID',
      'Sales Date',
      'Branch Outlet',
      'Staff / Cook Name',
      'Regular Sold',
      'Medium Sold',
      'B1T1 Sold',
      'Total Portions',
      'Gross Store Sales (₱)',
      'Cook Wage (₱)',
      'Bilao Comm. (₱)',
      'Total Cook Pay (₱)',
      'Cash Remittance to Owner (₱)',
      'Discrepancy Notes',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 4;
    int sumReg = 0;
    int sumMed = 0;
    int sumB1t1 = 0;
    int sumPortions = 0;
    double sumSales = 0.0;
    double sumBaseWage = 0.0;
    double sumBilaoComm = 0.0;
    double sumComputedWage = 0.0;
    double sumRemittance = 0.0;

    for (final r in records) {
      final reg = r.regularSold ?? 0;
      final med = r.mediumSold ?? 0;
      final b1t1 = r.b1t1OrdersSold ?? 0;
      final portions = r.displayPortions;
      final sales = r.totalSalesAmount;
      final baseWage = r.baseWage;
      final bilaoComm = r.bilaoCommission ?? 0.0;
      final computedWage = r.computedWage;
      final remittance = r.expectedCashRemittance;

      sumReg += reg;
      sumMed += med;
      sumB1t1 += b1t1;
      sumPortions += portions;
      sumSales += sales;
      sumBaseWage += baseWage;
      sumBilaoComm += bilaoComm;
      sumComputedWage += computedWage;
      sumRemittance += remittance;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(r.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(_shortDate.format(r.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(r.branchName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(r.employeeName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = IntCellValue(reg);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = IntCellValue(med);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = IntCellValue(b1t1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = IntCellValue(portions);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = DoubleCellValue(sales);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = DoubleCellValue(baseWage);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = DoubleCellValue(bilaoComm);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = DoubleCellValue(computedWage);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = DoubleCellValue(remittance);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row)).value = TextCellValue(r.discrepancyNote ?? 'Normal');
      row++;
    }

    // Grand Total Row
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL (${records.length} Recorded Shifts)');
    totalCell.cellStyle = _grandTotalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = _grandTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = _grandTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = _grandTotalStyle;

    final c4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    c4.value = IntCellValue(sumReg);
    c4.cellStyle = _grandTotalStyle;

    final c5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    c5.value = IntCellValue(sumMed);
    c5.cellStyle = _grandTotalStyle;

    final c6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
    c6.value = IntCellValue(sumB1t1);
    c6.cellStyle = _grandTotalStyle;

    final c7 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row));
    c7.value = IntCellValue(sumPortions);
    c7.cellStyle = _grandTotalStyle;

    final c8 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row));
    c8.value = DoubleCellValue(sumSales);
    c8.cellStyle = _grandTotalStyle;

    final c9 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row));
    c9.value = DoubleCellValue(sumBaseWage);
    c9.cellStyle = _grandTotalStyle;

    final c10 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row));
    c10.value = DoubleCellValue(sumBilaoComm);
    c10.cellStyle = _grandTotalStyle;

    final c11 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row));
    c11.value = DoubleCellValue(sumComputedWage);
    c11.cellStyle = _grandTotalStyle;

    final c12 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row));
    c12.value = DoubleCellValue(sumRemittance);
    c12.cellStyle = _grandTotalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row)).cellStyle = _grandTotalStyle;

    // Explicit widths
    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 28.0);
    sheet.setColumnWidth(3, 24.0);
    sheet.setColumnWidth(4, 16.0);
    sheet.setColumnWidth(5, 16.0);
    sheet.setColumnWidth(6, 16.0);
    sheet.setColumnWidth(7, 18.0);
    sheet.setColumnWidth(8, 22.0);
    sheet.setColumnWidth(9, 22.0);
    sheet.setColumnWidth(10, 18.0);
    sheet.setColumnWidth(11, 20.0);
    sheet.setColumnWidth(12, 26.0);
    sheet.setColumnWidth(13, 34.0);
  }

  static void _buildBranchCooksPayrollSheet({
    required Excel excel,
    required String sheetName,
    required List<SalesRecord> records,
  }) {
    final sheet = excel[sheetName];

    // Row 0: Title Banner
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('BRAHMS FOOD VENTURES — BRANCH COOKS PAYROLL SUMMARY');
    titleCell.cellStyle = _titleStyle;

    // Row 1: Subtitle
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      .value = TextCellValue('Consolidated monthly shift earnings from portions cooked and walk-in commissions');

    final headers = [
      'Staff / Cook Name',
      'Assigned Branch',
      'Recorded Shifts',
      'Regular Meals (pcs)',
      'Medium Meals (pcs)',
      'B1T1 Meals (pcs)',
      'Total Karne Portions',
      'Portion Base Wage (₱)',
      'Bilao Comm. (₱)',
      'Total Cook Earnings (₱)',
      'Avg. Pay / Shift (₱)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    final Map<String, _CookPayrollAggregate> cookMap = {};

    for (final r in records) {
      final key = '${r.employeeName}_${r.branchName}';
      final agg = cookMap.putIfAbsent(key, () => _CookPayrollAggregate(name: r.employeeName, branch: r.branchName));
      agg.shifts++;
      agg.regular += (r.regularSold ?? 0);
      agg.medium += (r.mediumSold ?? 0);
      agg.b1t1 += (r.b1t1OrdersSold ?? 0);
      agg.portions += r.displayPortions;
      agg.baseWage += r.baseWage;
      agg.bilaoComm += (r.bilaoCommission ?? 0.0);
      agg.totalWage += r.computedWage;
    }

    int row = 4;
    int totShifts = 0;
    int totReg = 0;
    int totMed = 0;
    int totB1t1 = 0;
    int totPortions = 0;
    double totBaseWage = 0.0;
    double totBilaoComm = 0.0;
    double totEarnings = 0.0;

    for (final agg in cookMap.values) {
      final avg = agg.shifts > 0 ? agg.totalWage / agg.shifts : 0.0;
      totShifts += agg.shifts;
      totReg += agg.regular;
      totMed += agg.medium;
      totB1t1 += agg.b1t1;
      totPortions += agg.portions;
      totBaseWage += agg.baseWage;
      totBilaoComm += agg.bilaoComm;
      totEarnings += agg.totalWage;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(agg.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(agg.branch);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = IntCellValue(agg.shifts);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(agg.regular);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = IntCellValue(agg.medium);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = IntCellValue(agg.b1t1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = IntCellValue(agg.portions);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = DoubleCellValue(agg.baseWage);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = DoubleCellValue(agg.bilaoComm);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = DoubleCellValue(agg.totalWage);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = DoubleCellValue(avg);
      row++;
    }

    // Total Row
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL ALL BRANCH COOKS');
    totalCell.cellStyle = _grandTotalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = _grandTotalStyle;

    final c2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    c2.value = IntCellValue(totShifts);
    c2.cellStyle = _grandTotalStyle;

    final c3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    c3.value = IntCellValue(totReg);
    c3.cellStyle = _grandTotalStyle;

    final c4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    c4.value = IntCellValue(totMed);
    c4.cellStyle = _grandTotalStyle;

    final c5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    c5.value = IntCellValue(totB1t1);
    c5.cellStyle = _grandTotalStyle;

    final c6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
    c6.value = IntCellValue(totPortions);
    c6.cellStyle = _grandTotalStyle;

    final c7 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row));
    c7.value = DoubleCellValue(totBaseWage);
    c7.cellStyle = _grandTotalStyle;

    final c8 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row));
    c8.value = DoubleCellValue(totBilaoComm);
    c8.cellStyle = _grandTotalStyle;

    final c9 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row));
    c9.value = DoubleCellValue(totEarnings);
    c9.cellStyle = _grandTotalStyle;

    final c10 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row));
    c10.value = DoubleCellValue(totShifts > 0 ? totEarnings / totShifts : 0.0);
    c10.cellStyle = _grandTotalStyle;

    // Explicit widths
    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 28.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 20.0);
    sheet.setColumnWidth(4, 20.0);
    sheet.setColumnWidth(5, 20.0);
    sheet.setColumnWidth(6, 22.0);
    sheet.setColumnWidth(7, 24.0);
    sheet.setColumnWidth(8, 20.0);
    sheet.setColumnWidth(9, 24.0);
    sheet.setColumnWidth(10, 22.0);
  }

  static void _buildProductionDriverPayrollSheet({
    required Excel excel,
    required String sheetName,
    required double cookRate,
    required double cutterRate,
    required double driverRate,
    required int driverDays,
    required int cookingSessions,
  }) {
    final sheet = excel[sheetName];

    // Row 0: Title Banner
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('BRAHMS FOOD VENTURES — PRODUCTION & DRIVER PAYROLL');
    titleCell.cellStyle = _titleStyle;

    // Row 1: Subtitle
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      .value = TextCellValue('Commissary batch cooking labor & inter-branch logistics driver wage');

    final headers = [
      'Department / Team',
      'Staff Role / Designation',
      'Daily Wage / Rate (₱)',
      'Sessions / Days Worked',
      'Total Compensation (₱)',
      'Operational Remarks',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    final cookPay = cookRate * cookingSessions;
    final cutterPay = cutterRate * cookingSessions;
    final prodSubtotal = cookPay + cutterPay;
    final driverPay = driverRate * driverDays;
    final grandTotal = prodSubtotal + driverPay;

    int row = 4;

    // 1. Production Head Cook
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Commissary Production');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Production Head Cook');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(cookRate);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(cookingSessions);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(cookPay);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Meat marinating and batch cooking');
    row++;

    // 2. Production Cutter
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Commissary Production');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Production Meat Cutter');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(cutterRate);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(cookingSessions);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(cutterPay);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Raw meat butchering and portion slicing');
    row++;

    // Production Subtotal
    final prodSub = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    prodSub.value = TextCellValue('SUB-TOTAL COMMISSARY LABOR');
    prodSub.cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = _subtotalStyle;
    final prodSubAmt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    prodSubAmt.value = DoubleCellValue(prodSubtotal);
    prodSubAmt.cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).cellStyle = _subtotalStyle;
    row += 2;

    // 3. Delivery Driver
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Logistics & Delivery');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Logistics Delivery Driver');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(driverRate);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(driverDays);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(driverPay);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Branch supply route (Absences deducted)');
    row += 2;

    // Grand Total Row
    final gName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    gName.value = TextCellValue('TOTAL PRODUCTION & DRIVER PAYROLL');
    gName.cellStyle = _grandTotalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = _grandTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = _grandTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = _grandTotalStyle;

    final gAmt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    gAmt.value = DoubleCellValue(grandTotal);
    gAmt.cellStyle = _grandTotalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).cellStyle = _grandTotalStyle;

    sheet.setColumnWidth(0, 28.0);
    sheet.setColumnWidth(1, 30.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 24.0);
    sheet.setColumnWidth(4, 26.0);
    sheet.setColumnWidth(5, 42.0);
  }

  static void _buildSalesPayrollSummarySheet({
    required Excel excel,
    required String sheetName,
    required List<SalesRecord> records,
    required double cookRate,
    required double cutterRate,
    required double driverRate,
    required int driverDays,
    required int cookingSessions,
  }) {
    final sheet = excel[sheetName];

    // Row 0: Title Banner
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('BRAHMS FOOD VENTURES — SALES & PAYROLL EXECUTIVE SUMMARY');
    titleCell.cellStyle = _titleStyle;

    // Row 1: Subtitle
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      .value = TextCellValue('Executive financial reconciliation of daily branch sales, cook payroll, and driver labor');

    // Section 1 Header
    final s1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
    s1.value = TextCellValue('1. STORE SALES & CASH REMITTANCE RECONCILIATION');
    s1.cellStyle = _sectionHeaderStyle;

    double totalStoreSales = 0.0;
    double totalCookWages = 0.0;
    double totalRemittance = 0.0;
    int totalPortions = 0;

    for (final r in records) {
      totalStoreSales += r.totalSalesAmount;
      totalCookWages += r.computedWage;
      totalRemittance += r.expectedCashRemittance;
      totalPortions += r.displayPortions;
    }

    final prodLaborTotal = (cookRate + cutterRate) * cookingSessions;
    final driverLaborTotal = driverRate * driverDays;
    final totalCompanyPayroll = totalCookWages + prodLaborTotal + driverLaborTotal;
    final netRetainedSales = totalStoreSales - totalCookWages;

    final kpis = <List<dynamic>>[
      ['Total Retail Store Sales (Gross Benta)', totalStoreSales, 'Gross in-store sales collected across branches'],
      ['Total Branch Cook Wages Paid', totalCookWages, 'Portion-based wages + walk-in bilao commissions earned'],
      ['Total Expected Cash Remittance to Owner', totalRemittance, 'Net cash to be remitted/collected by driver from branch tills'],
      ['Total Karne Portions Sold', '$totalPortions portions', 'Portions of regular, medium, and B1T1 meals prepared'],
      ['Commissary Production Staff Payroll', prodLaborTotal, '$cookingSessions Cooking sessions (Cook @ ₱${cookRate.toStringAsFixed(0)} + Cutter @ ₱${cutterRate.toStringAsFixed(0)})'],
      ['Logistics Delivery Driver Payroll', driverLaborTotal, '$driverDays Days rendered @ ₱${driverRate.toStringAsFixed(0)}/day'],
      ['COMBINED TOTAL COMPANY PAYROLL', totalCompanyPayroll, 'Sum of store cooks, commissary staff, and delivery driver wages'],
      ['Net Company Retained Sales', netRetainedSales, 'Retail store sales remaining after deducting branch cook wages'],
    ];

    int row = 4;
    for (final item in kpis) {
      final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      nameCell.value = TextCellValue(item[0].toString());

      final valCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      final bool isHighlight = item[0] == 'Total Expected Cash Remittance to Owner' || item[0] == 'COMBINED TOTAL COMPANY PAYROLL';
      if (item[1] is double) {
        valCell.value = DoubleCellValue(item[1] as double);
        if (isHighlight) {
          valCell.cellStyle = _highlightMetricStyle;
          nameCell.cellStyle = _highlightMetricStyle;
        }
      } else {
        valCell.value = TextCellValue(item[1].toString());
        if (isHighlight) {
          valCell.cellStyle = _highlightMetricStyle;
          nameCell.cellStyle = _highlightMetricStyle;
        }
      }

      final noteCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      noteCell.value = TextCellValue(item[2].toString());

      row++;
    }

    sheet.setColumnWidth(0, 44.0);
    sheet.setColumnWidth(1, 26.0);
    sheet.setColumnWidth(2, 42.0);
  }

  // ===========================================================================
  // INVENTORY & COMMISSARY AUDIT WORKBOOK
  // ===========================================================================

  /// Generates and immediately downloads a complete multi-sheet Inventory Audit Report (.xlsx).
  static Future<void> exportInventoryAuditReport({
    required List<KarneBatch> batches,
    required List<BranchMeatStock> branchStocks,
    required List<MeatDispatch> dispatches,
    required List<SupplyRequest> supplyRequests,
  }) async {
    final excel = Excel.createExcel();
    const defaultSheet = 'Sheet1';

    // ── 1. SHEET 1: Monthly Meat Batches ───────────────────────────────────
    _buildBatchesSheet(
      excel: excel,
      sheetName: 'Commissary Batches',
      batches: batches,
    );

    // ── 2. SHEET 2: Branch Daily Meat Stocks & Spoilage ────────────────────
    _buildBranchStocksSheet(
      excel: excel,
      sheetName: 'Branch Meat Stocks',
      stocks: branchStocks,
    );

    // ── 3. SHEET 3: Dispatches & Transfers ─────────────────────────────────
    _buildDispatchesSheet(
      excel: excel,
      sheetName: 'Dispatch & Transfer Logs',
      dispatches: dispatches,
    );

    // ── 4. SHEET 4: Supply Requests ────────────────────────────────────────
    _buildSupplyRequestsSheet(
      excel: excel,
      sheetName: 'Branch Supply Requests',
      requests: supplyRequests,
    );

    if (excel.sheets.containsKey(defaultSheet) && excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Brahms_Inventory_Audit_Report_$nowStr.xlsx';
      await saveAndLaunchExcel(Uint8List.fromList(fileBytes), fileName);
    }
  }

  static void _buildBatchesSheet({
    required Excel excel,
    required String sheetName,
    required List<KarneBatch> batches,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Batch Ref ID',
      'Monthly Batch Name',
      'Date Created',
      'Total Assigned (KG)',
      'Cooked (KG)',
      'Remaining (KG)',
      'Utilization %',
      '250g Target / Actual',
      '300g Target / Actual',
      '400g Target / Actual',
      'Cooking Status',
      'Cutter Report',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;
    double totalAssigned = 0;
    double totalCooked = 0;
    double totalRemaining = 0;

    for (final b in batches) {
      double used = 0;
      for (final s in b.sessions) {
        used += s.kilosCooked;
      }
      final remaining = (b.totalKilos - used).clamp(0, b.totalKilos).toDouble();
      final double utilPct = b.totalKilos > 0 ? (used / b.totalKilos) * 100 : 0.0;

      totalAssigned += b.totalKilos;
      totalCooked += used;
      totalRemaining += remaining;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(b.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(b.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = TextCellValue(_shortDate.format(b.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = DoubleCellValue(b.totalKilos);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = DoubleCellValue(used);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = DoubleCellValue(remaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = TextCellValue('${utilPct.toStringAsFixed(1)}%');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        .value = TextCellValue('${b.target250g ?? 0} / ${b.actual250g ?? 0}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        .value = TextCellValue('${b.target300g ?? 0} / ${b.actual300g ?? 0}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        .value = TextCellValue('${b.target400g ?? 0} / ${b.actual400g ?? 0}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        .value = TextCellValue(b.cookingStatus.toUpperCase());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
        .value = TextCellValue(b.cutterName != null ? 'Reported by ${b.cutterName}' : 'Pending Cutter');

      row++;
    }

    // Totals
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL COMMISSARY RAW MEAT');
    totalCell.cellStyle = _grandTotalStyle;

    for (int col = 1; col <= 2; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    final c3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    c3.value = DoubleCellValue(totalAssigned);
    c3.cellStyle = _grandTotalStyle;

    final c4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    c4.value = DoubleCellValue(totalCooked);
    c4.cellStyle = _grandTotalStyle;

    final c5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    c5.value = DoubleCellValue(totalRemaining);
    c5.cellStyle = _grandTotalStyle;

    for (int col = 6; col <= 11; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    // Explicit widths for ALL 12 columns
    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 32.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 22.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 18.0);
    sheet.setColumnWidth(7, 24.0);
    sheet.setColumnWidth(8, 24.0);
    sheet.setColumnWidth(9, 24.0);
    sheet.setColumnWidth(10, 20.0);
    sheet.setColumnWidth(11, 30.0);
  }

  static void _buildBranchStocksSheet({
    required Excel excel,
    required String sheetName,
    required List<BranchMeatStock> stocks,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Branch Outlet',
      'Inventory Date',
      '250g Reg Total',
      '250g Reg Left',
      '300g Med Total',
      '300g Med Left',
      '400g B1T1 Total',
      '400g B1T1 Left',
      'Total Meat Pcs Left',
      'Mayo Left',
      'Toyo Left',
      'Styro Left',
      'Spoilage Penalty (₱)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;
    int grandTotalPcsLeft = 0;
    double grandTotalPenalty = 0.0;

    for (final s in stocks) {
      final totalPcsLeft = s.regular250gRemaining + s.medium300gRemaining + s.b1t1_400gRemaining;
      grandTotalPcsLeft += totalPcsLeft;
      grandTotalPenalty += s.spoilagePenalty;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(s.branchName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(_shortDate.format(s.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = IntCellValue(s.regular250gTotal);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = IntCellValue(s.regular250gRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = IntCellValue(s.medium300gTotal);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = IntCellValue(s.medium300gRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = IntCellValue(s.b1t1_400gTotal);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        .value = IntCellValue(s.b1t1_400gRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        .value = IntCellValue(totalPcsLeft);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        .value = IntCellValue(s.mayoRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        .value = IntCellValue(s.toyoRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
        .value = IntCellValue(s.styroRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row))
        .value = DoubleCellValue(s.spoilagePenalty);

      row++;
    }

    // Total Row
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL ALL BRANCHES');
    totalCell.cellStyle = _grandTotalStyle;

    for (int col = 1; col <= 7; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    final c8 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row));
    c8.value = IntCellValue(grandTotalPcsLeft);
    c8.cellStyle = _grandTotalStyle;

    for (int col = 9; col <= 11; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    final c12 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row));
    c12.value = DoubleCellValue(grandTotalPenalty);
    c12.cellStyle = _grandTotalStyle;

    // Explicit widths for ALL 13 columns
    sheet.setColumnWidth(0, 28.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 16.0);
    sheet.setColumnWidth(4, 16.0);
    sheet.setColumnWidth(5, 16.0);
    sheet.setColumnWidth(6, 16.0);
    sheet.setColumnWidth(7, 16.0);
    sheet.setColumnWidth(8, 20.0);
    sheet.setColumnWidth(9, 14.0);
    sheet.setColumnWidth(10, 14.0);
    sheet.setColumnWidth(11, 14.0);
    sheet.setColumnWidth(12, 24.0);
  }

  static void _buildDispatchesSheet({
    required Excel excel,
    required String sheetName,
    required List<MeatDispatch> dispatches,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Dispatch Ref ID',
      'Date & Time',
      'Destination Branch',
      'Driver Name',
      '250g Regular (pcs)',
      '300g Medium (pcs)',
      '400g B1T1 (pcs)',
      'Total Meat Pcs',
      'Mayo (pcs)',
      'Toyo (pcs)',
      'Styro (pcs)',
      'Delivery Status',
      'Delivered At',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;
    int total250 = 0;
    int total300 = 0;
    int total400 = 0;
    int totalMeatAll = 0;

    for (final d in dispatches) {
      total250 += d.regular250gPcs;
      total300 += d.medium300gPcs;
      total400 += d.b1t1_400gPcs;
      totalMeatAll += d.totalMeatPcs;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(d.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(_dateFormat.format(d.createdAt));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = TextCellValue(d.destinationBranchName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = TextCellValue(d.driverName ?? 'Assigned Driver');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = IntCellValue(d.regular250gPcs);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = IntCellValue(d.medium300gPcs);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = IntCellValue(d.b1t1_400gPcs);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        .value = IntCellValue(d.totalMeatPcs);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        .value = IntCellValue(d.mayoPcs);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        .value = IntCellValue(d.toyoPcs);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        .value = IntCellValue(d.styroPcs);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
        .value = TextCellValue(d.status.toUpperCase());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row))
        .value = TextCellValue(d.deliveredAt != null ? _dateFormat.format(d.deliveredAt!) : 'In Transit / Pending');

      row++;
    }

    // Total Row
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalCell.value = TextCellValue('TOTAL DISPATCHES');
    totalCell.cellStyle = _grandTotalStyle;

    for (int col = 1; col <= 3; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    final c4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    c4.value = IntCellValue(total250);
    c4.cellStyle = _grandTotalStyle;

    final c5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    c5.value = IntCellValue(total300);
    c5.cellStyle = _grandTotalStyle;

    final c6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
    c6.value = IntCellValue(total400);
    c6.cellStyle = _grandTotalStyle;

    final c7 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row));
    c7.value = IntCellValue(totalMeatAll);
    c7.cellStyle = _grandTotalStyle;

    for (int col = 8; col <= 12; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _grandTotalStyle;
    }

    // Explicit widths for ALL 13 columns
    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 22.0);
    sheet.setColumnWidth(2, 28.0);
    sheet.setColumnWidth(3, 22.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 18.0);
    sheet.setColumnWidth(7, 20.0);
    sheet.setColumnWidth(8, 14.0);
    sheet.setColumnWidth(9, 14.0);
    sheet.setColumnWidth(10, 14.0);
    sheet.setColumnWidth(11, 18.0);
    sheet.setColumnWidth(12, 24.0);
  }

  static void _buildSupplyRequestsSheet({
    required Excel excel,
    required String sheetName,
    required List<SupplyRequest> requests,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Request ID',
      'Date Requested',
      'Item Description',
      'Requested By',
      'Current Status',
      'Owner Response / Remarks',
      'Response Date',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;
    for (final r in requests) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(r.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(_dateFormat.format(r.createdAt));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = TextCellValue(r.itemName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = TextCellValue(r.requestedBy);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = TextCellValue(r.status.label.toUpperCase());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = TextCellValue(r.ownerReply ?? 'Pending Review');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = TextCellValue(r.repliedAt != null ? _dateFormat.format(r.repliedAt!) : '—');

      row++;
    }

    // Explicit widths for ALL 7 columns
    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 22.0);
    sheet.setColumnWidth(2, 32.0);
    sheet.setColumnWidth(3, 24.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 38.0);
    sheet.setColumnWidth(6, 22.0);
  }

  // ===========================================================================
  // MONTHLY FINANCIALS & PROFIT/LOSS (P&L) WORKBOOK
  // ===========================================================================

  /// Generates and immediately downloads a comprehensive Monthly Financial & P&L Statement (.xlsx).
  static Future<void> exportMonthlyFinancialsReport({
    required FinancialPeriod period,
  }) async {
    final excel = Excel.createExcel();
    const defaultSheet = 'Sheet1';

    // ── 1. SHEET 1: Executive P&L Statement ────────────────────────────────
    _buildFinancialSummarySheet(
      excel: excel,
      sheetName: 'P&L Statement',
      period: period,
    );

    // ── 2. SHEET 2: Procurement & COGS Detail ──────────────────────────────
    _buildProcurementSheet(
      excel: excel,
      sheetName: 'Procurement & COGS',
      period: period,
    );

    // ── 3. SHEET 3: Labor & Store Overheads ────────────────────────────────
    _buildLaborOverheadsSheet(
      excel: excel,
      sheetName: 'Labor & Store Overheads',
      period: period,
    );

    if (excel.sheets.containsKey(defaultSheet) && excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final periodName = '${period.monthName}_${period.year}'.replaceAll(' ', '_');
      final fileName = 'Brahms_Financial_PnL_$periodName.xlsx';
      await saveAndLaunchExcel(Uint8List.fromList(fileBytes), fileName);
    }
  }

  static void _buildFinancialSummarySheet({
    required Excel excel,
    required String sheetName,
    required FinancialPeriod period,
  }) {
    final sheet = excel[sheetName];

    // Row 0: Title Banner
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('BRAHMS FOOD VENTURES — PROFIT & LOSS (P&L) STATEMENT');
    titleCell.cellStyle = _titleStyle;

    // Row 1: Subtitle
    final subCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    subCell.value = TextCellValue(
      'AUDIT PERIOD: ${period.monthName.toUpperCase()} ${period.year} | GENERATED: ${_dateFormat.format(DateTime.now())}',
    );

    // Row 3: Section 1 Header
    final s1Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
    s1Cell.value = TextCellValue('1. EXECUTIVE FINANCIAL HIGHLIGHTS & RETURN ON INVESTMENT (R.O.I)');
    s1Cell.cellStyle = _sectionHeaderStyle;

    final kpis = <List<dynamic>>[
      ['Projected Gross Revenue', period.grossRevenue, 'Target revenue from meat production output'],
      ['Total Cost of Goods Sold (Procurement)', period.totalProcurementCost, 'Raw ingredients, condiments, gas, packaging'],
      ['Total Labor Expenses', period.totalProductionLaborCost + period.totalDriverLaborCost + period.effectiveBranchCookLabor, 'Production cook, meat cutter, delivery driver, branch cooks'],
      ['Fixed Logistics Overheads', period.totalDailyFixedOverheads, 'Daddy’s Net delivery support + Trike gas allowance'],
      ['TOTAL MONTHLY OPERATING EXPENSES', period.totalExpenses, 'Sum of all procurement, labor, and logistics burn rate'],
      ['NET OPERATING PROFIT (EBITDA)', period.operatingProfit, 'Gross Revenue minus Total Operating Expenses'],
      ['Monthly Capital Benchmark (Target R.O.I)', period.roiInvestment, 'Target capital investment for the month'],
      ['Net Owner Return (Net Mav)', period.netMav, 'Real owner net earnings after full capital recovery'],
      ['Capital Remaining to Recoup', period.capitalRemainingToRecover, period.isRoiAchieved ? 'Fully recouped (100% achieved)' : 'Amount needed to reach break-even'],
      ['R.O.I Target Status', period.isRoiAchieved ? 'ACHIEVED (+₱${NumberFormat('#,##0.00').format(period.roiDifference)})' : 'IN PROGRESS (-₱${NumberFormat('#,##0.00').format(period.capitalRemainingToRecover)})', period.isRoiAchieved ? 'Target capital exceeded' : 'Below target investment margin'],
    ];

    int row = 4;
    for (final item in kpis) {
      final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      nameCell.value = TextCellValue(item[0].toString());

      final valCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      final bool isHighlight = item[0] == 'NET OPERATING PROFIT (EBITDA)' || item[0] == 'Net Owner Return (Net Mav)';
      if (item[1] is double) {
        valCell.value = DoubleCellValue(item[1] as double);
        if (isHighlight) {
          valCell.cellStyle = _highlightMetricStyle;
          nameCell.cellStyle = _highlightMetricStyle;
        }
      } else {
        valCell.value = TextCellValue(item[1].toString());
      }

      final noteCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      noteCell.value = TextCellValue(item[2].toString());

      row++;
    }

    row++; // Empty separator

    // Row: Section 2 - Meat Production & Gross Revenue
    final s2Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    s2Cell.value = TextCellValue('2. MEAT PRODUCTION OUTPUT & PROJECTED SALES REVENUE');
    s2Cell.cellStyle = _sectionHeaderStyle;
    row++;

    final revHeaders = ['Meat Size / Variant', 'Production Units (Pcs)', 'Unit Price (₱)', 'Gross Projected Sales (₱)', '% Share of Revenue'];
    for (int c = 0; c < revHeaders.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = TextCellValue(revHeaders[c]);
      cell.cellStyle = _headerStyle;
    }
    row++;

    final gross = period.grossRevenue > 0 ? period.grossRevenue : 1.0;
    final meatVariants = [
      ['Regular 250G', period.regular250gCount, 130.0, period.regular250gRevenue],
      ['Medium 300G', period.medium300gCount, 160.0, period.medium300gRevenue],
      ['Buy 1 Take 1 400G', period.b1t1400gCount, 210.0, period.b1t1400gRevenue],
    ];

    for (final v in meatVariants) {
      final count = v[1] as int;
      final price = v[2] as double;
      final total = v[3] as double;
      final share = (total / gross) * 100.0;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(v[0] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = IntCellValue(count);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(price);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue(total);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue('${share.toStringAsFixed(1)}%');
      row++;
    }

    // Revenue Total Row
    final revTotalName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    revTotalName.value = TextCellValue('TOTAL MEAT PRODUCTION REVENUE');
    revTotalName.cellStyle = _grandTotalStyle;

    final revTotalCount = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    revTotalCount.value = IntCellValue(period.totalProductionPcs);
    revTotalCount.cellStyle = _grandTotalStyle;

    final revDash = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    revDash.value = TextCellValue('—');
    revDash.cellStyle = _grandTotalStyle;

    final revTotalVal = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    revTotalVal.value = DoubleCellValue(period.grossRevenue);
    revTotalVal.cellStyle = _grandTotalStyle;

    final revTotalShare = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    revTotalShare.value = TextCellValue('100.0%');
    revTotalShare.cellStyle = _grandTotalStyle;
    row += 2;

    // Row: Section 3 - Expense Category Summary
    final s3Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    s3Cell.value = TextCellValue('3. OPERATING EXPENSES BREAKDOWN SUMMARY');
    s3Cell.cellStyle = _sectionHeaderStyle;
    row++;

    final expHeaders = ['Expense Category', 'Monthly Amount (₱)', '% Share of Expenses', 'Operational Notes'];
    for (int c = 0; c < expHeaders.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = TextCellValue(expHeaders[c]);
      cell.cellStyle = _headerStyle;
    }
    row++;

    final totalExp = period.totalExpenses > 0 ? period.totalExpenses : 1.0;
    final expRows = [
      ['Raw Ingredients & Procurement (COGS)', period.totalProcurementCost, 'Cooking oil, condiments, sugar, gas, packaging'],
      ['Commissary Production Labor', period.totalProductionLaborCost, '${period.productionCookingSessions} Cooking sessions (Cook @ ₱${period.productionCookDailyRate.toStringAsFixed(0)} + Cutter @ ₱${period.productionCutterDailyRate.toStringAsFixed(0)})'],
      ['Logistics Delivery Driver Labor', period.totalDriverLaborCost, '${period.driverWorkingDays} Working days @ ₱${period.driverDailyWage.toStringAsFixed(0)}/day'],
      ['Retail Branch Cooks Wages', period.effectiveBranchCookLabor, 'Consolidated cook compensation across 6 branches'],
      ['Daddy’s Net Delivery Support', period.totalDaddyNetCost, '${period.daddyNetDays} Operating days @ ₱${period.dailyDaddyNetRate.toStringAsFixed(0)}/day'],
      ['Tricycle Gas & Delivery Allowance', period.totalTrikeGasCost, '${period.trikeGasDays} Operating days @ ₱${period.dailyTrikeGasRate.toStringAsFixed(0)}/day'],
    ];

    for (final exp in expRows) {
      final amt = exp[1] as double;
      final share = (amt / totalExp) * 100.0;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(exp[0] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = DoubleCellValue(amt);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue('${share.toStringAsFixed(1)}%');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(exp[2] as String);
      row++;
    }

    // Expense Total Row
    final expTotalName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    expTotalName.value = TextCellValue('TOTAL OPERATING EXPENSES');
    expTotalName.cellStyle = _grandTotalStyle;

    final expTotalAmt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    expTotalAmt.value = DoubleCellValue(period.totalExpenses);
    expTotalAmt.cellStyle = _grandTotalStyle;

    final expTotalShare = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    expTotalShare.value = TextCellValue('100.0%');
    expTotalShare.cellStyle = _grandTotalStyle;

    final expTotalNote = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    expTotalNote.value = TextCellValue('Total monthly cash burn rate');
    expTotalNote.cellStyle = _grandTotalStyle;
    row += 2;

    // Row: Section 4 - Owner Notes
    if (period.notes.isNotEmpty) {
      final s4Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      s4Cell.value = TextCellValue('4. OWNER DIRECTIVES & MONTHLY NOTES');
      s4Cell.cellStyle = _sectionHeaderStyle;
      row++;

      final noteBody = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      noteBody.value = TextCellValue(period.notes);
    }

    sheet.setColumnWidth(0, 44.0);
    sheet.setColumnWidth(1, 26.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 40.0);
    sheet.setColumnWidth(4, 20.0);
  }

  static void _buildProcurementSheet({
    required Excel excel,
    required String sheetName,
    required FinancialPeriod period,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Procurement Category',
      'Item Description',
      'Cost / Price (₱)',
      'Payment Status',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;
    for (final group in period.procurementGroups) {
      for (final item in group.items) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(group.title);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(item.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = DoubleCellValue(item.price);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(item.isPaid ? 'PAID' : 'PENDING');
        row++;
      }

      // Group subtotal
      final catSubCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      catSubCell.value = TextCellValue('${group.title} Subtotal');
      catSubCell.cellStyle = _subtotalStyle;

      final countSubCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      countSubCell.value = TextCellValue('(${group.items.length} items)');
      countSubCell.cellStyle = _subtotalStyle;

      final valSubCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      valSubCell.value = DoubleCellValue(group.total);
      valSubCell.cellStyle = _subtotalStyle;

      final statusSubCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      statusSubCell.value = TextCellValue('—');
      statusSubCell.cellStyle = _subtotalStyle;

      row += 2; // Spacing after category
    }

    // Grand Total Row
    final gName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    gName.value = TextCellValue('TOTAL PROCUREMENT & COGS');
    gName.cellStyle = _grandTotalStyle;

    final gCount = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    gCount.value = TextCellValue('${period.procurementGroups.length} Categories');
    gCount.cellStyle = _grandTotalStyle;

    final gAmt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    gAmt.value = DoubleCellValue(period.totalProcurementCost);
    gAmt.cellStyle = _grandTotalStyle;

    final gStatus = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    gStatus.value = TextCellValue('CONFIRMED');
    gStatus.cellStyle = _grandTotalStyle;

    sheet.setColumnWidth(0, 32.0);
    sheet.setColumnWidth(1, 36.0);
    sheet.setColumnWidth(2, 24.0);
    sheet.setColumnWidth(3, 20.0);
  }

  static void _buildLaborOverheadsSheet({
    required Excel excel,
    required String sheetName,
    required FinancialPeriod period,
  }) {
    final sheet = excel[sheetName];

    final headers = [
      'Department / Category',
      'Role / Expense Item',
      'Daily Rate (₱)',
      'Days / Sessions',
      'Total Amount (₱)',
      'Operational Remarks',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    int row = 1;

    // 1. Commissary Production
    final prodCookAmt = period.productionCookingSessions * period.productionCookDailyRate;
    final prodCutterAmt = period.productionCookingSessions * period.productionCutterDailyRate;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Commissary Production');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Production Head Cook');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(period.productionCookDailyRate);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(period.productionCookingSessions);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(prodCookAmt);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Meat marinating and cooking');
    row++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Commissary Production');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Production Meat Cutter');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(period.productionCutterDailyRate);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(period.productionCookingSessions);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(prodCutterAmt);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Raw meat butchering and portioning');
    row++;

    // Production Subtotal
    final prodSub = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    prodSub.value = TextCellValue('SUB-TOTAL PRODUCTION LABOR');
    prodSub.cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = _subtotalStyle;
    final prodSubAmt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    prodSubAmt.value = DoubleCellValue(period.totalProductionLaborCost);
    prodSubAmt.cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).cellStyle = _subtotalStyle;
    row += 2;

    // 2. Logistics & Store Overheads
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Logistics & Overheads');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Delivery Driver');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(period.driverDailyWage);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(period.driverWorkingDays);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(period.totalDriverLaborCost);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Branch supply and meat delivery route');
    row++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Logistics & Overheads');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Daddy’s Net Delivery Support');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(period.dailyDaddyNetRate);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(period.daddyNetDays);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(period.totalDaddyNetCost);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Fixed delivery operations vehicle');
    row++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Logistics & Overheads');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Tricycle Gas Allowance');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(period.dailyTrikeGasRate);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(period.trikeGasDays);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(period.totalTrikeGasCost);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Fuel and maintenance for delivery tricycle');
    row++;

    // Logistics Subtotal
    final logSub = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    logSub.value = TextCellValue('SUB-TOTAL LOGISTICS & OVERHEADS');
    logSub.cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = _subtotalStyle;
    final logSubAmt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    logSubAmt.value = DoubleCellValue(period.totalDriverLaborCost + period.totalDailyFixedOverheads);
    logSubAmt.cellStyle = _subtotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).cellStyle = _subtotalStyle;
    row += 2;

    // 3. Retail Branch Store Cooks
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Branch Retail Store');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Branch Cooks Consolidated Wages');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue('—');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue('—');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(period.effectiveBranchCookLabor);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('Total actual payroll across 6 retail branches');
    row += 2;

    // Grand Total Row
    final gName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    gName.value = TextCellValue('TOTAL LABOR & OPERATING OVERHEADS');
    gName.cellStyle = _grandTotalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = _grandTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = _grandTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = _grandTotalStyle;

    final totalLaborOverheads = period.totalProductionLaborCost +
        period.totalDriverLaborCost +
        period.effectiveBranchCookLabor +
        period.totalDailyFixedOverheads;

    final gAmt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
    gAmt.value = DoubleCellValue(totalLaborOverheads);
    gAmt.cellStyle = _grandTotalStyle;

    final gRem = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    gRem.value = TextCellValue('Monthly total labor commitments');
    gRem.cellStyle = _grandTotalStyle;

    sheet.setColumnWidth(0, 30.0);
    sheet.setColumnWidth(1, 36.0);
    sheet.setColumnWidth(2, 20.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 26.0);
    sheet.setColumnWidth(5, 42.0);
  }
}


class _BranchAggregate {
  _BranchAggregate({required this.name});
  final String name;
  int small = 0;
  int medium = 0;
  int large = 0;
  int totalQty = 0;
  double grossRevenue = 0.0;
  double cookCommission = 0.0;
}

class _CookPayrollAggregate {
  _CookPayrollAggregate({required this.name, required this.branch});
  final String name;
  final String branch;
  int shifts = 0;
  int regular = 0;
  int medium = 0;
  int b1t1 = 0;
  int portions = 0;
  double baseWage = 0.0;
  double bilaoComm = 0.0;
  double totalWage = 0.0;
}

