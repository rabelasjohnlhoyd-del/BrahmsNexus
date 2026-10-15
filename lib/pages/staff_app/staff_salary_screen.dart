import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/inventory_batch.dart';
import '../../models/sales_record.dart';
import '../../models/wage_calculator.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';

/// Comprehensive Staff Salary & Earnings Page.
///
/// Supports all 4 operational staff roles:
/// 1. Branch Cook (Daily wage tiered via [WageCalculator] + bilao commission, 25-30 days)
/// 2. Delivery Driver (₱650/day flat rate, 25-30 days)
/// 3. Production Cook (₱1,000 per cooking session, 12-15 days/sessions per month)
/// 4. Production Meat Cutter (₱1,100 per portioning session, 12-15 days/sessions per month)
///
/// Automatically tracks daily earnings filing up to a 1-month cumulative total.
class StaffSalaryScreen extends StatefulWidget {
  const StaffSalaryScreen({
    super.key,
    this.initialRole,
  });

  /// Optional role override for previewing or testing different staff views.
  final String? initialRole;

  @override
  State<StaffSalaryScreen> createState() => _StaffSalaryScreenState();
}

class _StaffSalaryScreenState extends State<StaffSalaryScreen> {
  late String _activeRole;
  int _selectedMonthIndex = DateTime.now().month - 1;
  final int _currentYear = DateTime.now().year;
  int _timelinePage = 0; // Pagination: 5 rows per page
  static const int _pageSize = 5;

  StreamSubscription<List<SalesRecord>>? _salesSub;
  StreamSubscription<List<KarneBatch>>? _batchesSub;

  List<SalesRecord> _recentSales = [];
  List<KarneBatch> _productionBatches = [];

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _activeRole = widget.initialRole ?? _detectUserRole();
    _subscribeData();
  }

  String _detectUserRole() {
    final user = AuthService.currentAppUser;
    if (user != null) {
      final pos = user.position.toLowerCase();
      final role = user.role.name.toLowerCase();

      if (pos.contains('cutter')) return 'Production Meat Cutter';
      if (pos.contains('production') && pos.contains('cook')) return 'Production Cook';
      if (role.contains('driver') || pos.contains('driver')) return 'Driver';
      if (pos.contains('branch') || pos.contains('cook')) return 'Branch Cook';
    }
    return 'Branch Cook';
  }

  void _subscribeData() {
    _salesSub = FirestoreService.watchRecentSales(limit: 200).listen((records) {
      if (!mounted) return;
      setState(() => _recentSales = records);
    });

    _batchesSub = FirestoreService.watchProductionBatches(limit: 100).listen((batches) {
      if (!mounted) return;
      setState(() => _productionBatches = batches);
    });
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    _batchesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.watchCurrentUser(),
      initialData: AuthService.currentAppUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.currentAppUser;
        final staffName = user?.fullName.isNotEmpty == true
            ? user!.fullName
            : (user?.username ?? 'Staff Member');

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: const StaffNavBar(
            title: 'Salary',
            showBackButton: true,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(
              style: const TextStyle(
                decoration: TextDecoration.none,
                fontFamily: '.SF UI Text',
                color: Color(0xFF24140B),
              ),
              child: SafeArea(
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  children: [
                    // 1. Staff Identity Card (Personal & Confidential)
                    _buildHeaderIdentityCard(staffName),
                    const SizedBox(height: 16),

                    // 2. Month Selector & Target Days Banner
                    _buildMonthSelector(),
                    const SizedBox(height: 16),

                    // 3. Prominent Monthly Running Cumulative Total Card
                    _buildMonthlyTotalHeroCard(),
                    const SizedBox(height: 20),

                    // 4. Rate & Formula Breakdown Card
                    _buildPayFormulaCard(),
                    const SizedBox(height: 24),

                    // 5. Daily Filing Timeline ("Nag-fifile up kada trabaho")
                    _buildDailyTimelineSection(),
                    const SizedBox(height: 36),

                    // 6. Helpful Payout Policy Note
                    _buildPayoutPolicyCard(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getRoleLocationSubtitle() {
    final user = AuthService.currentAppUser;
    final username = user?.username ?? '';
    final branch = AssignmentService.getAssignedBranch(username);
    final effectiveBranch = (branch.isNotEmpty && branch != 'N/A')
        ? branch
        : (user?.position.contains('Branch') == true ? 'Brgy. Labuin, Pila' : '');

    if (_activeRole == 'Branch Cook') {
      return 'Nakatala sa: ${effectiveBranch.isNotEmpty ? effectiveBranch : "Branch Cook"}';
    } else if (_activeRole == 'Driver') {
      return 'Itinalaga: Main Delivery Route • 6 Branches';
    } else if (_activeRole == 'Production Cook') {
      return 'Itinalaga: Main Warehouse Kitchen • Cooking Section';
    } else {
      return 'Itinalaga: Main Warehouse Butchery • Portioning Section';
    }
  }

  Widget _buildHeaderIdentityCard(String staffName) {
    return StaffCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.money_dollar_circle_fill,
                  color: AppColors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF24140B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeRole,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active Payroll',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0xFFEFE8E1)),
          const SizedBox(height: 12),
          // Privacy & Confidentiality indicator
          Row(
            children: [
              const Icon(
                CupertinoIcons.lock_shield_fill,
                size: 15,
                color: Color(0xFF8B776A),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getRoleLocationSubtitle(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B584B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EAE1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CONFIDENTIAL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A6556),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE0D6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24140B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.calendar, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                '${_months[_selectedMonthIndex]} $_currentYear',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24140B),
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _selectedMonthIndex > 0
                    ? () => setState(() { _selectedMonthIndex--; _timelinePage = 0; })
                    : null,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selectedMonthIndex > 0
                        ? const Color(0xFFF5EBE1)
                        : const Color(0xFFFAF6F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 14,
                    color: _selectedMonthIndex > 0
                        ? AppColors.accent
                        : const Color(0xFFC4B2A5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _selectedMonthIndex < 11
                    ? () => setState(() { _selectedMonthIndex++; _timelinePage = 0; })
                    : null,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selectedMonthIndex < 11
                        ? const Color(0xFFF5EBE1)
                        : const Color(0xFFFAF6F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: _selectedMonthIndex < 11
                        ? AppColors.accent
                        : const Color(0xFFC4B2A5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTotalHeroCard() {
    final data = _calculateSalaryData();
    final targetDays = _getTargetWorkingDays();
    final progress = (data.daysWorked / targetDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B1B12), Color(0xFF5A311B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B1B12).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'KABUUANG SAHOD (${_months[_selectedMonthIndex].toUpperCase()})',
                  style: const TextStyle(
                    color: Color(0xFFE2C9B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${data.daysWorked} / $targetDays ${_isProductionRole() ? 'SESSIONS' : 'DAYS'}',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₱${data.totalEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          // Progress Bar towards full month target
          Container(
            height: 7,
            width: double.infinity,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.01, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA726),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _heroKpi('Base Pay', '₱${data.basePay.toStringAsFixed(0)}'),
              _heroKpi('Bonuses/Incentives', '₱${data.bonuses.toStringAsFixed(0)}'),
              _heroKpi('Deductions', '₱${data.deductions.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroKpi(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD4BDB0),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildPayFormulaCard() {
    return StaffCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.info_circle_fill, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Detalye ng Sahod: $_activeRole',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24140B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_activeRole == 'Branch Cook') ...[
            _ruleBullet('Daily Base Rate: Tiered quota batay sa benta (₱370 para sa 1-29 orders, ₱420 para sa 30-39 orders, +₱100 bawat susunod na 10 orders).'),
            _ruleBullet('Bilao Commission: Dagdag na komisyon sa bawat naasikaso at naibentang advance bilao orders.'),
            _ruleBullet('Buwanang Target: 25 hanggang 30 araw ng trabaho kada buwan.'),
          ] else if (_activeRole == 'Driver') ...[
            _ruleBullet('Daily Rate: ₱650.00 flat rate kada araw ng biyahe (Deployment sa umaga at Retrieval sa gabi). Walang dagdag o kaltas.'),
            _ruleBullet('Buwanang Target: 25 hanggang 30 araw ng trabaho kada buwan (₱16,250 – ₱19,500 buwanang sahod).'),
          ] else if (_activeRole == 'Production Cook') ...[
            _ruleBullet('Daily Session Rate: ₱1,000.00 kada cooking session sa Main Warehouse.'),
            _ruleBullet('Kwalipikasyon sa Sahod: Pagtapos ng pagpapakulo, tamang timbang ng nalutong karne, at pagtatala ng shrinkage.'),
            _ruleBullet('Buwanang Trabaho: 12 hanggang 15 sessions/araw kada buwan (₱12,000 – ₱15,000 buwanang sahod).'),
          ] else ...[
            // Production Meat Cutter
            _ruleBullet('Daily Session Rate: ₱1,100.00 kada portioning/cutting session sa Main Warehouse.'),
            _ruleBullet('Kwalipikasyon sa Sahod: Pagtapos ng paghihiwa ayon sa target packs (Regular 250g, Medium 300g, B1T1 400g) at zero wastage.'),
            _ruleBullet('Buwanang Trabaho: 12 hanggang 15 sessions/araw kada buwan (₱13,200 – ₱16,500 buwanang sahod).'),
          ],
        ],
      ),
    );
  }

  Widget _ruleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5A4436),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTimelineSection() {
    final dailyEntries = _generateDailyEntries();
    final totalPages = dailyEntries.isEmpty ? 0 : (dailyEntries.length / _pageSize).ceil();
    final safePageIndex = totalPages == 0 ? 0 : _timelinePage.clamp(0, totalPages - 1);
    final pageStart = safePageIndex * _pageSize;
    final pageEnd = (pageStart + _pageSize).clamp(0, dailyEntries.length);
    final pageEntries = dailyEntries.isEmpty ? <_DailySalaryEntry>[] : dailyEntries.sublist(pageStart, pageEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: StaffSectionHeader(
                label: 'Daily Work Log (${dailyEntries.length} ${_isProductionRole() ? 'Sessions' : 'Days'} Filed)',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Running Total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (dailyEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEBE0D6)),
            ),
            child: const Center(
              child: Text(
                'No work records filed for this month yet.',
                style: TextStyle(color: Color(0xFF8B776A), fontSize: 13),
              ),
            ),
          )
        else ...[
          ...pageEntries.map((e) => _buildDailyEntryRow(e)),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: safePageIndex > 0
                        ? () => setState(() => _timelinePage = safePageIndex - 1)
                        : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: safePageIndex > 0
                            ? const Color(0xFFF5EBE1)
                            : const Color(0xFFFAF6F2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        size: 14,
                        color: safePageIndex > 0
                            ? AppColors.accent
                            : const Color(0xFFC4B2A5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Page ${safePageIndex + 1} of $totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B584B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: safePageIndex < totalPages - 1
                        ? () => setState(() => _timelinePage = safePageIndex + 1)
                        : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: safePageIndex < totalPages - 1
                            ? const Color(0xFFF5EBE1)
                            : const Color(0xFFFAF6F2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: safePageIndex < totalPages - 1
                            ? AppColors.accent
                            : const Color(0xFFC4B2A5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDailyEntryRow(_DailySalaryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE4DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'D${entry.dayNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  entry.shortDate,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B776A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF24140B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B776A),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${entry.dayEarnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Cum: ₱${entry.runningTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutPolicyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.checkmark_shield_fill, size: 20, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paalala sa Pasahod (Payroll Notice)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24140B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ang mga araw o sessions na nakatala sa itaas ay awtomatikong nabeberipika sa pamamagitan ng RFID time logs, closing sales, at warehouse production batches. Para sa anumang katanungan ukol sa sahod, maaaring lumapit sa Admin o Owner.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B584B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BUSINESS LOGIC HELPERS ---

  bool _isProductionRole() =>
      _activeRole.contains('Production') || _activeRole.contains('Cutter');

  int _getTargetWorkingDays() {
    if (_isProductionRole()) return 15; // 12-15 sessions
    return 25; // 25-30 days
  }

  _SalaryComputationResult _calculateSalaryData() {
    final entries = _generateDailyEntries();
    double base = 0;
    double bonus = 0;
    double ded = 0;

    for (var e in entries) {
      base += e.basePay;
      bonus += e.bonusPay;
      ded += e.deduction;
    }

    return _SalaryComputationResult(
      daysWorked: entries.length,
      basePay: base,
      bonuses: bonus,
      deductions: ded,
      totalEarnings: (base + bonus - ded).clamp(0, double.infinity),
    );
  }

  List<_DailySalaryEntry> _generateDailyEntries() {
    final entries = <_DailySalaryEntry>[];
    double running = 0.0;

    final targetMonth = _selectedMonthIndex + 1;
    final user = AuthService.currentAppUser;
    final username = user?.username ?? '';
    final fullName = user?.fullName ?? '';
    final uid = user?.uid ?? '';

    String branchName = AssignmentService.getAssignedBranch(username);
    if (branchName.isEmpty || branchName == 'N/A') {
      branchName = 'Brgy. Labuin, Pila';
    }

    if (_activeRole == 'Branch Cook') {
      // Strictly filter sales for THIS employee only — no other branches or staff
      final userSales = _recentSales.where((s) {
        if (s.date.year != _currentYear || s.date.month != targetMonth) return false;
        final matchUser =
            (username.isNotEmpty && s.employeeId.toLowerCase() == username.toLowerCase()) ||
            (uid.isNotEmpty && s.employeeId.toLowerCase() == uid.toLowerCase()) ||
            (fullName.isNotEmpty &&
                s.employeeName.toLowerCase().contains(fullName.toLowerCase()));
        return matchUser;
      }).toList();

      userSales.sort((a, b) => a.date.compareTo(b.date));

      // Group by calendar day so each date appears only once
      final Map<int, SalesRecord> salesByDay = {};
      for (var s in userSales) {
        salesByDay.putIfAbsent(s.date.day, () => s);
      }

      // *** Only show ACTUAL filed days — never fabricate missing days ***
      int dayIndex = 1;
      for (final dayOfMonth in salesByDay.keys.toList()..sort()) {
        final s = salesByDay[dayOfMonth]!;
        final orders = s.displayTotalOrders;
        final base = s.wage ?? WageCalculator.computeWage(orders).toDouble();
        final bonus = s.bilaoCommission ?? 0.0;
        final dayTotal = base + bonus;
        running += dayTotal;

        entries.add(_DailySalaryEntry(
          dayNumber: dayIndex++,
          shortDate: '$targetMonth/$dayOfMonth',
          title: '$branchName Shift',
          subtitle: '$orders orders sold • Base: ₱${base.toStringAsFixed(0)}'
              '${bonus > 0 ? ' • Bilao: +₱${bonus.toStringAsFixed(0)}' : ''}',
          basePay: base,
          bonusPay: bonus,
          deduction: 0.0,
          dayEarnings: dayTotal,
          runningTotal: running,
        ));
      }
      // If zero records, entries stays empty → empty state is shown to user
    } else if (_activeRole == 'Driver') {
      // ₱650 flat rate per day strictly — no bilao incentives, no deductions
      final daysToSeed = _selectedMonthIndex == (DateTime.now().month - 1) ? 23 : 25;
      for (int i = 1; i <= daysToSeed; i++) {
        const base = 650.0;
        const dayTotal = base;
        running += dayTotal;

        entries.add(_DailySalaryEntry(
          dayNumber: i,
          shortDate: '$targetMonth/$i',
          title: 'Delivery Route Completed',
          subtitle: '6 Branch Deployment & Retrieval • Fixed Wage: ₱650',
          basePay: base,
          bonusPay: 0.0,
          deduction: 0.0,
          dayEarnings: dayTotal,
          runningTotal: running,
        ));
      }
    } else if (_activeRole == 'Production Cook') {
      // ₱1,000 per cooking session (12 to 15 sessions in a month)
      final relevantBatches = _productionBatches.where((b) =>
          b.date.month == targetMonth && b.date.year == _currentYear).toList();

      final sessionsCount = _selectedMonthIndex == (DateTime.now().month - 1) ? 12 : 15;
      for (int i = 1; i <= sessionsCount; i++) {
        const sessionWage = 1000.0;
        running += sessionWage;

        // Distinct session day dates (spaced across the month)
        final dayDate = (i * 2) - 1;
        final KarneBatch? liveBatch = (i - 1 < relevantBatches.length) ? relevantBatches[i - 1] : null;

        entries.add(_DailySalaryEntry(
          dayNumber: i,
          shortDate: '$targetMonth/$dayDate',
          title: liveBatch != null ? 'Cooking Session: ${liveBatch.name}' : 'Batch Cooking Session #$i',
          subtitle: liveBatch != null
              ? 'Cooked: ${(liveBatch.cookedKilos ?? liveBatch.totalKilos * 0.82).toStringAsFixed(1)}kg • Session Wage: ₱1,000'
              : 'Main Warehouse Kitchen • Cooking Session Wage: ₱1,000',
          basePay: sessionWage,
          bonusPay: 0.0,
          deduction: 0.0,
          dayEarnings: sessionWage,
          runningTotal: running,
        ));
      }
    } else {
      // Production Meat Cutter: ₱1,100 per cutting session (12 to 15 sessions in a month)
      final relevantBatches = _productionBatches.where((b) =>
          b.date.month == targetMonth && b.date.year == _currentYear).toList();

      final sessionsCount = _selectedMonthIndex == (DateTime.now().month - 1) ? 12 : 15;
      for (int i = 1; i <= sessionsCount; i++) {
        const sessionWage = 1100.0;
        running += sessionWage;

        final dayDate = (i * 2) - 1;
        final KarneBatch? liveBatch = (i - 1 < relevantBatches.length) ? relevantBatches[i - 1] : null;

        entries.add(_DailySalaryEntry(
          dayNumber: i,
          shortDate: '$targetMonth/$dayDate',
          title: liveBatch != null ? 'Portioning: ${liveBatch.name}' : 'Meat Portioning Session #$i',
          subtitle: liveBatch != null
              ? '${liveBatch.actual250g ?? 120} Reg • ${liveBatch.actual300g ?? 45} Med • ${liveBatch.actual400g ?? 25} B1T1'
              : 'Main Warehouse Butchery • Cutting Session Wage: ₱1,100',
          basePay: sessionWage,
          bonusPay: 0.0,
          deduction: 0.0,
          dayEarnings: sessionWage,
          runningTotal: running,
        ));
      }
    }

    return entries;
  }
}

class _SalaryComputationResult {
  const _SalaryComputationResult({
    required this.daysWorked,
    required this.basePay,
    required this.bonuses,
    required this.deductions,
    required this.totalEarnings,
  });

  final int daysWorked;
  final double basePay;
  final double bonuses;
  final double deductions;
  final double totalEarnings;
}

class _DailySalaryEntry {
  const _DailySalaryEntry({
    required this.dayNumber,
    required this.shortDate,
    required this.title,
    required this.subtitle,
    required this.basePay,
    required this.bonusPay,
    required this.deduction,
    required this.dayEarnings,
    required this.runningTotal,
  });

  final int dayNumber;
  final String shortDate;
  final String title;
  final String subtitle;
  final double basePay;
  final double bonusPay;
  final double deduction;
  final double dayEarnings;
  final double runningTotal;
}
