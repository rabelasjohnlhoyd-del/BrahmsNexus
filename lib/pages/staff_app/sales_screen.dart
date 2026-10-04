import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, InkWell, LinearProgressIndicator, ClipRRect;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../models/branch_meat_inventory.dart';
import '../../models/sales_record.dart';
import '../../models/staff_member.dart';
import '../../models/app_notification.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../services/input_validators.dart';
import '../auth/mock_accounts.dart';
import '../../services/tutorial_service.dart';
import '../../widgets/guided_tour_overlay.dart';
import 'staff_bilao_orders_screen.dart';
import 'staff_shell.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

/// Represents a single order punched during the shift in the Quick POS
class ShiftTallyItem {
  const ShiftTallyItem({
    required this.id,
    required this.name,
    required this.price,
    required this.timestamp,
    required this.category,
  });

  final String id;
  final String name;
  final int price;
  final DateTime timestamp;
  final String category; // 'reg_sisig', 'reg_bagnet', 'med_sisig', 'med_bagnet', 'b1t1_sisig_bagnet', 'b1t1_bagnet_bagnet'
}

/// Sales tab — Features Cook Quick POS / Order Tallying & Wastage Spoilage Reporting:
/// Branch cook taps buttons for customer orders as they happen during the shift.
/// Stock is automatically deducted real-time in Firestore, triggering Low Stock Alerts.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  static final GlobalKey<SalesScreenState> globalKey = GlobalKey<SalesScreenState>();

  @override
  State<SalesScreen> createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> {
  BranchDailyInventory? _todayInventory;
  BranchMeatStock? _branchMeatStock;
  SalesRecord? _todaySalesRecord;
  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';
  StreamSubscription<BranchDailyInventory?>? _inventorySub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  StreamSubscription<SalesRecord?>? _todaySalesSub;

  // Shift Tally Counters
  int _countRegSisig = 0;
  int _countRegBagnet = 0;
  int _countMedSisig = 0;
  int _countMedBagnet = 0;
  int _countB1t1SisigBagnet = 0;
  int _countB1t1BagnetBagnet = 0;

  final List<ShiftTallyItem> _tallyHistory = [];

  final _karneController = TextEditingController(); // Regular 250g
  final _mayoController = TextEditingController();
  final _styroController = TextEditingController();
  final _toyoController = TextEditingController();
  final _mediumController = TextEditingController(); // Medium 300g
  final _b1t1Controller = TextEditingController(); // B1T1 400g

  // ── Guided Tour Keys (Live Spotlight) ───────────────────────────
  final GlobalKey _posButtonKey = GlobalKey();
  final GlobalKey _spoilageButtonKey = GlobalKey();
  final GlobalKey _inventoryMetersKey = GlobalKey();
  final GlobalKey _closingSalesKey = GlobalKey();

  bool _submitted = false;

  // ── Rate Limiting & Debounce ─────────────────────────────────────────────
  bool _isPunching = false;
  bool _isUndoing = false;
  int _spoilageReportsThisShift = 0;
  static const int _maxSpoilagePerShift = 5;

  int get _allocatedRegular => _effectiveStock.regular250gTotal;
  int get _allocatedMedium => _effectiveStock.medium300gTotal;
  int get _allocatedB1t1 => _effectiveStock.b1t1_400gTotal;
  int get _allocatedMayo => _effectiveStock.mayoTotal;
  int get _allocatedToyo => _effectiveStock.toyoTotal;
  int get _allocatedStyro => _effectiveStock.styroTotal;

  BranchMeatStock get _effectiveStock {
    if (_branchMeatStock != null) {
      return _branchMeatStock!;
    }
    if (_todayInventory?.actualReceived != null) {
      final ar = _todayInventory!.actualReceived!;
      return BranchMeatStock(
        branchId: _currentBranchId,
        branchName: _currentBranchName,
        date: DateTime.now(),
        regular250gTotal: ar.regular,
        regular250gRemaining: ar.regular,
        medium300gTotal: ar.medium,
        medium300gRemaining: ar.medium,
        b1t1_400gTotal: ar.b1t1,
        b1t1_400gRemaining: ar.b1t1,
        mayoTotal: ar.mayo,
        mayoRemaining: ar.mayo,
        styroTotal: ar.styro,
        styroRemaining: ar.styro,
        toyoTotal: ar.toyo,
        toyoRemaining: ar.toyo,
      );
    }
    return BranchMeatStock.defaultForBranch(
      kSampleBranches.firstWhere((b) => b.id == _currentBranchId, orElse: () => kSampleBranches.first),
    );
  }

  @override
  void initState() {
    super.initState();
    AssignmentService.ensureInitialized();
    _setupBranchAndStreams();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
    _karneController.addListener(_onFieldChanged);
    _mediumController.addListener(_onFieldChanged);
    _b1t1Controller.addListener(_onFieldChanged);
    _mayoController.addListener(_onFieldChanged);
    _toyoController.addListener(_onFieldChanged);
    _styroController.addListener(_onFieldChanged);
    _maybeTriggerGuidedTour();
  }

  void startTour() {
    _launchGuidedTour();
  }

  Future<void> _maybeTriggerGuidedTour() async {
    final seen = await TutorialService.hasSeenTutorial('cook_spotlight');
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _launchGuidedTour();
    }
  }

  void _launchGuidedTour() {
    if (!mounted) return;
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _posButtonKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '4. Pagtatala ng Benta (Quick POS)',
          instruction: 'PINDUTIN: I-tap ang "+1 REGULAR SISIG" button sa ibaba.',
          explanation:
              'Sa tuwing may bibili ng Regular Sisig, pindutin ito. Awtomatikong magre-record ng benta (₱130) at mababawasan ang 250g karne at sangkap sa metro.',
          tip: 'Punch each order in real-time. Huwag ipunin sa dulo ng shift.',
          onTargetTapped: () {
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: _spoilageButtonKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '5. Pag-ulat ng Spoilage (Tapon / Panis)',
          instruction: 'PINDUTIN: I-tap ang "Spoilage" button.',
          explanation:
              'Kung may karne na nahulog sa sahig o nasunog, i-report agad dito ang bilang at dahilan upang maging tumpak ang audit.',
          tip: 'May safety cap: bawal ang negative at may wage deduction penalty kapag nasayang.',
          onTargetTapped: () {
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: _inventoryMetersKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '6. Real-Time Inventory Meters',
          instruction: 'PINDUTIN: I-tap ang metro ng karne upang magpatuloy.',
          explanation:
              'Dito mo mababantayan ang natitirang stock ng karne, mayo, toyo, at styro. Mabilis na nagbabago ang kulay kapag papalapit na sa low stock threshold.',
          tip: 'Maging alerto kapag nagkulay dilaw o pula ang metro ng Regular o Medium meat.',
          onTargetTapped: () {
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: _closingSalesKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '7. End of Day Closing Sales & Remittance',
          instruction: 'PINDUTIN: I-tap ang "Submit Final Closing Sales".',
          explanation:
              'Sa pagtatapos ng shift, dito mo isusumite ang final report. Awtomatikong ibabawas ang iyong sweldo at komisyon para sa eksaktong remittance sa driver.',
          tip: 'I-double check ang bilang bago mag-submit dahil pinal na ang ulat na ito.',
          onTargetTapped: () {
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: StaffShell.bilaoTabKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '8. Pumunta sa Bilao Orders Tab',
          instruction: 'PINDUTIN: I-tap ang "Bilao" tab sa ibaba upang magpatuloy sa Bilao Orders tutorial.',
          explanation:
              'Dito mo ilalagay at babantayan ang mga advance Bilao package orders para sa iyong branch.',
          tip: 'Pindutin ang Bilao tab sa ibaba upang magpatuloy sa Bilao tutorial.',
          onTargetTapped: () async {
            StaffShell.tabController.index = 2;
            await Future.delayed(const Duration(milliseconds: 350));
            (StaffBilaoOrdersScreen.globalKey.currentState as dynamic)?.startTour();
          },
        ),
      ],
      onCompleted: () => TutorialService.markTutorialSeen('cook_spotlight'),
      onSkipped: () => TutorialService.markTutorialSeen('cook_spotlight'),
    );
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _onAssignmentChanged() {
    if (mounted) {
      _setupBranchAndStreams();
    }
  }

  void _setupBranchAndStreams() {
    final username = AuthService.currentUsername;
    final currentUid = AuthService.currentUserId;

    var assignedBranchName = AssignmentService.getAssignedBranch(username);
    if (assignedBranchName.isEmpty && currentUid.isNotEmpty) {
      assignedBranchName = AssignmentService.getAssignedBranch(currentUid);
    }
    if (assignedBranchName.isEmpty) {
      final allStaff = SupabaseService.getAllStaff();
      final match = allStaff.firstWhere(
        (s) => s.username.toLowerCase() == username.toLowerCase() ||
               s.id == currentUid ||
               s.id.replaceAll('-', '') == currentUid.replaceAll('-', ''),
        orElse: () => StaffMember(id: '', firstName: '', lastName: '', username: '', branch: '', position: ''),
      );
      if (match.branch.isNotEmpty && match.branch != 'N/A') {
        assignedBranchName = match.branch;
      }
    }
    if (assignedBranchName.isEmpty) {
      final mock = kMockAccounts[username.toLowerCase()];
      if (mock != null && mock.branchName.isNotEmpty) {
        assignedBranchName = mock.branchName;
      }
    }

    Branch? matchedBranch;
    if (assignedBranchName.isNotEmpty) {
      for (final b in kSampleBranches) {
        if (b.fullName.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            b.name.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            assignedBranchName.toLowerCase().contains(b.name.toLowerCase())) {
          matchedBranch = b;
          break;
        }
      }
    }
    matchedBranch ??= kSampleBranches.first;
    _currentBranchId = matchedBranch.id;
    _currentBranchName = matchedBranch.fullName;
    _loadTallyFromCache();

    // Fast one-shot fetch so verification status is instantly active without delay
    FirestoreService.getTodayBranchInventory(
      branchId: matchedBranch.id,
      branchName: matchedBranch.fullName,
      date: DateTime.now(),
    ).then((inv) {
      if (mounted && inv != null) {
        setState(() {
          _todayInventory = inv;
        });
      }
    });

    _inventorySub?.cancel();
    _inventorySub = FirestoreService.watchTodayBranchInventory(
      branchId: matchedBranch.id,
      branchName: matchedBranch.fullName,
      date: DateTime.now(),
    ).listen((inv) {
      if (mounted) {
        setState(() {
          if (inv == null && _todayInventory != null && _isInventoryVerified) {
            return;
          }
          _todayInventory = inv;
        });
      }
    });

    _meatStocksSub?.cancel();
    _meatStocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) {
        final match = stocks.firstWhere(
          (s) => s.branchId == _currentBranchId,
          orElse: () => BranchMeatStock.defaultForBranch(matchedBranch!),
        );
        setState(() {
          _branchMeatStock = match;
          _syncControllersWithStock(match);
        });
      }
    });

    _todaySalesSub?.cancel();
    _todaySalesSub = FirestoreService.watchTodayBranchSales(
      branchId: matchedBranch.id,
      date: DateTime.now(),
    ).listen((sales) {
      if (mounted) {
        setState(() {
          _todaySalesRecord = sales;
          if (sales != null) {
            _submitted = true;
            final rs = sales.remainingStock;
            if (rs != null) {
              _karneController.text = rs.regular.toString();
              _mediumController.text = rs.medium.toString();
              _b1t1Controller.text = rs.b1t1.toString();
              _mayoController.text = rs.mayo.toString();
              _toyoController.text = rs.toyo.toString();
              _styroController.text = rs.styro.toString();
            }
          }
        });
      }
    });
  }

  void _syncControllersWithStock(BranchMeatStock stock) {
    if (_submitted) return;
    _karneController.text = stock.regular250gRemaining.toString();
    _mediumController.text = stock.medium300gRemaining.toString();
    _b1t1Controller.text = stock.b1t1_400gRemaining.toString();
    _mayoController.text = stock.mayoRemaining.toString();
    _toyoController.text = stock.toyoRemaining.toString();
    _styroController.text = stock.styroRemaining.toString();
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentChanged);
    _karneController.removeListener(_onFieldChanged);
    _mediumController.removeListener(_onFieldChanged);
    _b1t1Controller.removeListener(_onFieldChanged);
    _mayoController.removeListener(_onFieldChanged);
    _toyoController.removeListener(_onFieldChanged);
    _styroController.removeListener(_onFieldChanged);
    _inventorySub?.cancel();
    _meatStocksSub?.cancel();
    _todaySalesSub?.cancel();
    _karneController.dispose();
    _mayoController.dispose();
    _styroController.dispose();
    _toyoController.dispose();
    _mediumController.dispose();
    _b1t1Controller.dispose();
    super.dispose();
  }

  // Quick Order Punching Action
  void _punchOrder({
    required String name,
    required int price,
    required String category,
    required int regDeduct,
    required int medDeduct,
    required int b1t1Deduct,
    required int mayoDeduct,
    required int toyoDeduct,
    required int styroDeduct,
  }) async {
    if (_submitted || _isPunching) return;
    setState(() => _isPunching = true);

    try {
      if (!_isInventoryVerified) {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Inventory Verification Required'),
            content: const Text(
              'Please complete "Verify: Count What You Actually Received" on the Home tab before punching sales.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final currentStock = _effectiveStock;

      if (regDeduct > 0 && currentStock.regular250gRemaining < regDeduct) {
        _showOutOfStockDialog('Regular Meat (250g)');
        return;
      }
      if (medDeduct > 0 && currentStock.medium300gRemaining < medDeduct) {
        _showOutOfStockDialog('Medium Meat (300g)');
        return;
      }
      if (b1t1Deduct > 0 && currentStock.b1t1_400gRemaining < b1t1Deduct) {
        _showOutOfStockDialog('B1T1 Meat (400g)');
        return;
      }
      if (mayoDeduct > 0 && currentStock.mayoRemaining < mayoDeduct) {
        _showOutOfStockDialog('Mayo');
        return;
      }
      if (toyoDeduct > 0 && currentStock.toyoRemaining < toyoDeduct) {
        _showOutOfStockDialog('Toyo');
        return;
      }
      if (styroDeduct > 0 && currentStock.styroRemaining < styroDeduct) {
        _showOutOfStockDialog('Styro');
        return;
      }

      final updatedStock = currentStock.copyWith(
        regular250gRemaining: (currentStock.regular250gRemaining - regDeduct).clamp(0, 999),
        medium300gRemaining: (currentStock.medium300gRemaining - medDeduct).clamp(0, 999),
        b1t1_400gRemaining: (currentStock.b1t1_400gRemaining - b1t1Deduct).clamp(0, 999),
        mayoRemaining: (currentStock.mayoRemaining - mayoDeduct).clamp(0, 999),
        toyoRemaining: (currentStock.toyoRemaining - toyoDeduct).clamp(0, 999),
        styroRemaining: (currentStock.styroRemaining - styroDeduct).clamp(0, 999),
      );

      setState(() {
        _branchMeatStock = updatedStock;
        _syncControllersWithStock(updatedStock);
        if (category == 'reg_sisig') _countRegSisig++;
        if (category == 'reg_bagnet') _countRegBagnet++;
        if (category == 'med_sisig') _countMedSisig++;
        if (category == 'med_bagnet') _countMedBagnet++;
        if (category == 'b1t1_sisig_bagnet') _countB1t1SisigBagnet++;
        if (category == 'b1t1_bagnet_bagnet') _countB1t1BagnetBagnet++;

        _tallyHistory.insert(
          0,
          ShiftTallyItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            price: price,
            timestamp: DateTime.now(),
            category: category,
          ),
        );
      });

      await FirestoreService.saveBranchMeatStock(updatedStock);
      await _saveTallyToCache();
    } finally {
      // 350ms cooldown prevents accidental fast double-taps while keeping UI responsive
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) setState(() => _isPunching = false);
    }
  }

  Future<void> _saveTallyToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final key = 'tally_${_currentBranchId}_$dateStr';
      final data = {
        'regSisig': _countRegSisig,
        'regBagnet': _countRegBagnet,
        'medSisig': _countMedSisig,
        'medBagnet': _countMedBagnet,
        'b1t1SisigBagnet': _countB1t1SisigBagnet,
        'b1t1BagnetBagnet': _countB1t1BagnetBagnet,
        'history': _tallyHistory.map((item) => {
          'id': item.id,
          'name': item.name,
          'price': item.price,
          'timestamp': item.timestamp.millisecondsSinceEpoch,
          'category': item.category,
        }).toList(),
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadTallyFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final key = 'tally_${_currentBranchId}_$dateStr';
      final raw = prefs.getString(key);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _countRegSisig = data['regSisig'] as int? ?? 0;
          _countRegBagnet = data['regBagnet'] as int? ?? 0;
          _countMedSisig = data['medSisig'] as int? ?? 0;
          _countMedBagnet = data['medBagnet'] as int? ?? 0;
          _countB1t1SisigBagnet = data['b1t1SisigBagnet'] as int? ?? 0;
          _countB1t1BagnetBagnet = data['b1t1BagnetBagnet'] as int? ?? 0;
          final hist = data['history'] as List<dynamic>? ?? [];
          _tallyHistory.clear();
          for (final h in hist) {
            final map = h as Map<String, dynamic>;
            _tallyHistory.add(ShiftTallyItem(
              id: map['id']?.toString() ?? '',
              name: map['name']?.toString() ?? '',
              price: (map['price'] as num?)?.toInt() ?? 0,
              timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
              category: map['category']?.toString() ?? '',
            ));
          }
        });
      }
    } catch (_) {}
  }

  void _undoLastOrder() async {
    if (_tallyHistory.isEmpty || _submitted || _isUndoing) return;
    setState(() => _isUndoing = true);

    try {
      final last = _tallyHistory.removeAt(0);
      final currentStock = _effectiveStock;

      int addReg = 0, addMed = 0, addB1t1 = 0, addMayo = 0, addToyo = 0, addStyro = 0;
      if (last.category == 'reg_sisig') {
        _countRegSisig--;
        addReg = 1; addMayo = 1; addStyro = 1;
      } else if (last.category == 'reg_bagnet') {
        _countRegBagnet--;
        addReg = 1; addToyo = 1; addStyro = 1;
      } else if (last.category == 'med_sisig') {
        _countMedSisig--;
        addMed = 1; addMayo = 1; addStyro = 1;
      } else if (last.category == 'med_bagnet') {
        _countMedBagnet--;
        addMed = 1; addToyo = 1; addStyro = 1;
      } else if (last.category == 'b1t1_sisig_bagnet') {
        _countB1t1SisigBagnet--;
        addB1t1 = 1; addMayo = 1; addToyo = 1; addStyro = 2;
      } else if (last.category == 'b1t1_bagnet_bagnet') {
        _countB1t1BagnetBagnet--;
        addB1t1 = 1; addToyo = 2; addStyro = 2;
      }

      final restoredStock = currentStock.copyWith(
        regular250gRemaining: (currentStock.regular250gRemaining + addReg).clamp(0, currentStock.regular250gTotal),
        medium300gRemaining: (currentStock.medium300gRemaining + addMed).clamp(0, currentStock.medium300gTotal),
        b1t1_400gRemaining: (currentStock.b1t1_400gRemaining + addB1t1).clamp(0, currentStock.b1t1_400gTotal),
        mayoRemaining: (currentStock.mayoRemaining + addMayo).clamp(0, currentStock.mayoTotal),
        toyoRemaining: (currentStock.toyoRemaining + addToyo).clamp(0, currentStock.toyoTotal),
        styroRemaining: (currentStock.styroRemaining + addStyro).clamp(0, currentStock.styroTotal),
      );

      setState(() {
        _branchMeatStock = restoredStock;
        _syncControllersWithStock(restoredStock);
      });

      await FirestoreService.saveBranchMeatStock(restoredStock);
      await _saveTallyToCache();
    } finally {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _isUndoing = false);
    }
  }

  void _showWastageDialog() {
    if (_spoilageReportsThisShift >= _maxSpoilagePerShift) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Report Limit Reached'),
          content: Text(
            'Maximum $_maxSpoilagePerShift spoilage reports allowed per shift.\n\nIf you have additional spoilage to record, please contact management or the Owner directly.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    String selectedItem = 'Regular Meat (250g)';
    final qtyController = TextEditingController(text: '1');
    final reasonController = TextEditingController();
    String? errorMsg;

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Report Spoilage / Wastage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Report spoiled, dropped, or burned items. Spoiled items count as inventory loss and deduct cost from your daily wage/commission.',
                style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  showCupertinoModalPopup<void>(
                    context: ctx,
                    builder: (popupCtx) => CupertinoActionSheet(
                      title: const Text('Select Spoiled Item'),
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () {
                            setDialogState(() => selectedItem = 'Regular Meat (250g)');
                            Navigator.pop(popupCtx);
                          },
                          child: const Text('Regular Meat (250g) — ₱130 penalty'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            setDialogState(() => selectedItem = 'Medium Meat (300g)');
                            Navigator.pop(popupCtx);
                          },
                          child: const Text('Medium Meat (300g) — ₱160 penalty'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            setDialogState(() => selectedItem = 'B1T1 Meat (400g)');
                            Navigator.pop(popupCtx);
                          },
                          child: const Text('B1T1 Meat (400g) — ₱210 penalty'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            setDialogState(() => selectedItem = 'Mayo Pack');
                            Navigator.pop(popupCtx);
                          },
                          child: const Text('Mayo Pack — ₱10 penalty'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            setDialogState(() => selectedItem = 'Toyo Pack');
                            Navigator.pop(popupCtx);
                          },
                          child: const Text('Toyo Pack — ₱5 penalty'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            setDialogState(() => selectedItem = 'Styro Box');
                            Navigator.pop(popupCtx);
                          },
                          child: const Text('Styro Box — ₱5 penalty'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(popupCtx),
                        child: const Text('Cancel'),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemGrey4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedItem, style: const TextStyle(fontSize: 13, color: CupertinoColors.black)),
                      const Icon(CupertinoIcons.chevron_down, size: 14, color: CupertinoColors.activeBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                maxLength: 2,
                placeholder: 'Quantity (1 - 10)...',
                style: const TextStyle(fontSize: 13),
                onChanged: (_) {
                  if (errorMsg != null) setDialogState(() => errorMsg = null);
                },
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: reasonController,
                placeholder: 'Reason for spoilage (min. 10, max 300 chars)...',
                maxLines: 3,
                maxLength: 300,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(300),
                ],
                style: const TextStyle(fontSize: 13),
                onChanged: (val) {
                  setDialogState(() {
                    final trimmed = val.trim();
                    if (trimmed.isEmpty) {
                      errorMsg = null;
                    } else {
                      final res = InputValidators.validateMessage(
                        trimmed,
                        fieldName: 'Reason for spoilage',
                        required: true,
                        minLength: 10,
                        maxLength: 300,
                      );
                      errorMsg = res.isValid ? null : res.errorMessage;
                    }
                  });
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${reasonController.text.length}/300 characters',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: reasonController.text.length >= 300
                          ? CupertinoColors.destructiveRed
                          : CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 4),
                Text(errorMsg!, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 11.5)),
              ],
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                final rawReason = reasonController.text;

                if (qty < 1 || qty > 10) {
                  setDialogState(() => errorMsg = 'Ang quantity ng spoilage ay dapat mula 1 hanggang 10 lamang.');
                  return;
                }

                final reasonResult = InputValidators.validateMessage(
                  rawReason,
                  fieldName: 'Reason for spoilage',
                  required: true,
                  minLength: 10,
                  maxLength: 300,
                );

                if (!reasonResult.isValid) {
                  setDialogState(() => errorMsg = reasonResult.errorMessage);
                  return;
                }

                Navigator.of(ctx).pop();
                _processWastageReport(selectedItem, qty, reasonResult.sanitizedText);
              },
              child: const Text('Report Spoilage'),
            ),
          ],
        ),
      ),
    );
  }


  void _processWastageReport(String item, int qty, String reason) async {
    final currentStock = _effectiveStock;

    int regDec = 0, medDec = 0, b1t1Dec = 0, mayoDec = 0, toyoDec = 0, styroDec = 0;
    double penalty = 0.0;

    if (item.contains('Regular')) {
      regDec = qty;
      penalty = 130.0 * qty;
    } else if (item.contains('Medium')) {
      medDec = qty;
      penalty = 160.0 * qty;
    } else if (item.contains('B1T1')) {
      b1t1Dec = qty;
      penalty = 210.0 * qty;
    } else if (item.contains('Mayo')) {
      mayoDec = qty;
      penalty = 10.0 * qty;
    } else if (item.contains('Toyo')) {
      toyoDec = qty;
      penalty = 5.0 * qty;
    } else if (item.contains('Styro')) {
      styroDec = qty;
      penalty = 5.0 * qty;
    }

    final updatedStock = currentStock.copyWith(
      regular250gRemaining: (currentStock.regular250gRemaining - regDec).clamp(0, 999),
      medium300gRemaining: (currentStock.medium300gRemaining - medDec).clamp(0, 999),
      b1t1_400gRemaining: (currentStock.b1t1_400gRemaining - b1t1Dec).clamp(0, 999),
      mayoRemaining: (currentStock.mayoRemaining - mayoDec).clamp(0, 999),
      toyoRemaining: (currentStock.toyoRemaining - toyoDec).clamp(0, 999),
      styroRemaining: (currentStock.styroRemaining - styroDec).clamp(0, 999),
      spoilagePenalty: currentStock.spoilagePenalty + penalty,
    );

    setState(() {
      _branchMeatStock = updatedStock;
      _syncControllersWithStock(updatedStock);
    });

    await FirestoreService.saveBranchMeatStock(updatedStock);
    if (mounted) {
      setState(() => _spoilageReportsThisShift++);
    }

    NotificationService.sendNotification(
      title: '⚠️ Spoilage / Wastage Report — $_currentBranchName',
      message: '${AuthService.currentUsername} reported $qty x $item spoiled/wasted.\nReason: "$reason" (Wage penalty: ₱${penalty.toStringAsFixed(0)})',
      type: NotificationType.salesReport,
      targetRole: 'owner',
      route: 'sales',
      targetBranch: _currentBranchName,
    ).catchError((_) => false);

    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Spoilage Reported'),
        content: Text('Successfully recorded $qty x $item as spoilage.\nWage deduction applied: ₱${penalty.toStringAsFixed(0)}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showOutOfStockDialog(String itemName) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Out of Stock'),
        content: Text('Cannot punch order: $itemName is out of stock in your branch inventory!'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  int? _parseOrNull(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  DailySalesComputation get _computation {
    return DailySalesComputation(
      allocatedRegular: _allocatedRegular,
      allocatedMedium: _allocatedMedium,
      allocatedB1t1: _allocatedB1t1,
      allocatedMayo: _allocatedMayo,
      allocatedToyo: _allocatedToyo,
      allocatedStyro: _allocatedStyro,
      remainingRegular: _parseOrNull(_karneController),
      remainingMedium: _parseOrNull(_mediumController),
      remainingB1t1: _parseOrNull(_b1t1Controller),
      remainingMayo: _parseOrNull(_mayoController),
      remainingToyo: _parseOrNull(_toyoController),
      remainingStyro: _parseOrNull(_styroController),
      spoilagePenalty: _branchMeatStock?.spoilagePenalty ?? 0.0,
    );
  }

  bool get _isInventoryVerified {
    if (_todayInventory != null) {
      return _todayInventory!.status != InventoryVerificationStatus.pending;
    }
    if (_branchMeatStock != null) {
      final isNotDefault = _branchMeatStock!.regular250gTotal != 20 ||
          _branchMeatStock!.medium300gTotal != 10 ||
          _branchMeatStock!.b1t1_400gTotal != 10 ||
          _branchMeatStock!.mayoTotal != 40 ||
          _branchMeatStock!.styroTotal != 40 ||
          _branchMeatStock!.toyoTotal != 10;
      if (isNotDefault) return true;
    }
    return false;
  }

  Future<void> _confirmSubmit() async {
    if (!_isInventoryVerified) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Inventory Verification Required'),
          content: const Text(
            'Please complete "Verify: Count What You Actually Received" on the Home tab before submitting sales.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_karneController.text.trim().isEmpty ||
        _mediumController.text.trim().isEmpty ||
        _b1t1Controller.text.trim().isEmpty ||
        _mayoController.text.trim().isEmpty ||
        _toyoController.text.trim().isEmpty ||
        _styroController.text.trim().isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Missing Input'),
          content: const Text(
            'Please fill in or verify all remaining stock fields before submitting.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final computation = _computation;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Submit Closing Sales?'),
        content: Text(
          'Total Orders Punched: ${computation.totalOrders} · '
          'Gross Revenue: \u20b1${computation.totalRevenue} · '
          'Wage & Commission: \u20b1${computation.salary} · '
          'Cash Remittance: \u20b1${computation.cashRemit}. This '
          "cannot be edited once submitted.",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit Sales'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    _submit();
  }

  Future<void> _submit({String? discrepancyNote}) async {
    final computation = _computation;

    setState(() => _submitted = true);

    final record = SalesRecord(
      id: '',
      branchId: _currentBranchId,
      branchName: _currentBranchName,
      employeeId: AuthService.currentUsername,
      employeeName: AuthService.currentUser?.fullName ?? AuthService.currentUsername,
      date: DateTime.now(),
      portionsSold: computation.totalKarneUsed,
      totalOrders: computation.totalOrders,
      commissionRatePerPortion: 5.0,
      totalSalesAmount: computation.totalRevenue.toDouble(),
      wage: computation.salary.toDouble(),
      regularSold: computation.regularSold,
      mediumSold: computation.mediumSold,
      b1t1OrdersSold: computation.b1t1OrdersSold,
      discrepancyNote: discrepancyNote,
      remainingStock: ActualReceivedCounts(
        mayo: int.tryParse(_mayoController.text) ?? 0,
        toyo: int.tryParse(_toyoController.text) ?? 0,
        styro: int.tryParse(_styroController.text) ?? 0,
        regular: int.tryParse(_karneController.text) ?? 0,
        medium: int.tryParse(_mediumController.text) ?? 0,
        b1t1: int.tryParse(_b1t1Controller.text) ?? 0,
      ),
    );
    final success = await FirestoreService.submitDailySales(record);

    if (!mounted) return;
    if (!success) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error Submitting Sales'),
          content: const Text(
            'Failed to save sales report to Firestore. Please check your internet connection.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sales Submitted'),
        content: Text(
          'Sales report submitted successfully!\n'
          'Earned Salary & Commission: ₱${computation.salary}\n'
          'Expected Cash Remittance: ₱${computation.cashRemit}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPosButton({
    required String label,
    required String priceTag,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitted ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        priceTag,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final computation = _computation;
    final currentStock = _effectiveStock;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Cook Quick POS',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Section
            Row(
              children: [
                const Expanded(
                  child: StaffSectionHeader(
                    label: "Shift Quick Tally",
                    icon: CupertinoIcons.cart_badge_plus,
                    subtitle: 'Tap as customer orders arrive',
                    large: true,
                  ),
                ),
                if (!_submitted) ...[
                  if (_tallyHistory.isNotEmpty)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      onPressed: _undoLastOrder,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.arrow_uturn_left, size: 13, color: AppColors.error),
                          SizedBox(width: 3),
                          Text('Undo', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(width: 6),
                  CupertinoButton(
                    key: _spoilageButtonKey,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _showWastageDialog,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 13, color: AppColors.warning),
                        SizedBox(width: 3),
                        Text('Spoilage', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // 6 Quick POS Buttons Grid
            LayoutBuilder(
              builder: (ctx, constraints) {
                final btnW = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      key: _posButtonKey,
                      width: btnW,
                      child: _buildPosButton(
                        label: '+1 REGULAR SISIG',
                        priceTag: '₱130 · 250g',
                        icon: CupertinoIcons.add,
                        color: AppColors.accent,
                        onTap: () => _punchOrder(
                          name: 'Regular Sisig',
                          price: 130,
                          category: 'reg_sisig',
                          regDeduct: 1, medDeduct: 0, b1t1Deduct: 0,
                          mayoDeduct: 1, toyoDeduct: 0, styroDeduct: 1,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: _buildPosButton(
                        label: '+1 REGULAR BAGNET',
                        priceTag: '₱130 · 250g',
                        icon: CupertinoIcons.add,
                        color: const Color(0xFFD97706),
                        onTap: () => _punchOrder(
                          name: 'Regular Bagnet',
                          price: 130,
                          category: 'reg_bagnet',
                          regDeduct: 1, medDeduct: 0, b1t1Deduct: 0,
                          mayoDeduct: 0, toyoDeduct: 1, styroDeduct: 1,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: _buildPosButton(
                        label: '+1 MEDIUM SISIG',
                        priceTag: '₱160 · 300g',
                        icon: CupertinoIcons.add,
                        color: AppColors.accent,
                        onTap: () => _punchOrder(
                          name: 'Medium Sisig',
                          price: 160,
                          category: 'med_sisig',
                          regDeduct: 0, medDeduct: 1, b1t1Deduct: 0,
                          mayoDeduct: 1, toyoDeduct: 0, styroDeduct: 1,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: _buildPosButton(
                        label: '+1 MEDIUM BAGNET',
                        priceTag: '₱160 · 300g',
                        icon: CupertinoIcons.add,
                        color: const Color(0xFFD97706),
                        onTap: () => _punchOrder(
                          name: 'Medium Bagnet',
                          price: 160,
                          category: 'med_bagnet',
                          regDeduct: 0, medDeduct: 1, b1t1Deduct: 0,
                          mayoDeduct: 0, toyoDeduct: 1, styroDeduct: 1,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: _buildPosButton(
                        label: '+1 B1T1 (SISIG & BAGNET)',
                        priceTag: '₱210 · 400g (2 Pcs)',
                        icon: CupertinoIcons.add,
                        color: const Color(0xFF059669),
                        onTap: () => _punchOrder(
                          name: 'B1T1 (Sisig & Bagnet)',
                          price: 210,
                          category: 'b1t1_sisig_bagnet',
                          regDeduct: 0, medDeduct: 0, b1t1Deduct: 1,
                          mayoDeduct: 1, toyoDeduct: 1, styroDeduct: 2,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: _buildPosButton(
                        label: '+1 B1T1 (BAGNET & BAGNET)',
                        priceTag: '₱210 · 400g (2 Pcs)',
                        icon: CupertinoIcons.add,
                        color: const Color(0xFF059669),
                        onTap: () => _punchOrder(
                          name: 'B1T1 (Bagnet & Bagnet)',
                          price: 210,
                          category: 'b1t1_bagnet_bagnet',
                          regDeduct: 0, medDeduct: 0, b1t1Deduct: 1,
                          mayoDeduct: 0, toyoDeduct: 2, styroDeduct: 2,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            // Live Remaining Stock Meters
            const StaffSectionHeader(
              label: 'Live Inventory Remaining',
              icon: CupertinoIcons.cube_box_fill,
              subtitle: 'Auto-updated in real-time as you punch orders',
            ),
            const SizedBox(height: 10),
            StaffCard(
              key: _inventoryMetersKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _stockMeter(
                          label: 'Regular Meat (250g)',
                          remaining: currentStock.regular250gRemaining,
                          total: currentStock.regular250gTotal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _stockMeter(
                          label: 'Medium Meat (300g)',
                          remaining: currentStock.medium300gRemaining,
                          total: currentStock.medium300gTotal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _stockMeter(
                          label: 'B1T1 Meat (400g)',
                          remaining: currentStock.b1t1_400gRemaining,
                          total: currentStock.b1t1_400gTotal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _stockMeter(
                          label: 'Mayo Packs',
                          remaining: currentStock.mayoRemaining,
                          total: currentStock.mayoTotal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _stockMeter(
                          label: 'Toyo Sauce Packs',
                          remaining: currentStock.toyoRemaining,
                          total: currentStock.toyoTotal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _stockMeter(
                          label: 'Styro Boxes',
                          remaining: currentStock.styroRemaining,
                          total: currentStock.styroTotal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // End of Day Closing & Audit Section
            const StaffSectionHeader(
              label: 'Closing & End-of-Day Audit',
              icon: CupertinoIcons.money_dollar_circle_fill,
              subtitle: 'System tallies orders & computes wage automatically',
            ),
            const SizedBox(height: 10),
            StaffCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _computedRow(
                    'Total Orders Punched',
                    '${computation.totalOrders}',
                    isHeader: true,
                  ),
                  const _CupertinoDivider(),
                  _computedRow(
                    'Regular Sisig / Bagnet',
                    '₱${computation.regularRevenue.toStringAsFixed(0)}',
                    subtitle: '₱130 × ${computation.regularSold}',
                  ),
                  _computedRow(
                    'Medium Sisig / Bagnet',
                    '₱${computation.mediumRevenue.toStringAsFixed(0)}',
                    subtitle: '₱160 × ${computation.mediumSold}',
                  ),
                  _computedRow(
                    'B1T1 Combos',
                    '₱${computation.b1t1Revenue.toStringAsFixed(0)}',
                    subtitle: '₱210 × ${computation.b1t1OrdersSold}',
                  ),
                  const _CupertinoDivider(),
                  _computedRow(
                    'GROSS REVENUE',
                    '₱${computation.totalRevenue.toStringAsFixed(0)}',
                    isSubtotal: true,
                  ),
                  const SizedBox(height: 12),
                  _computedRow(
                    'Less Staff Wage & Commission',
                    '- ₱${computation.salary.toStringAsFixed(0)}',
                    subtitle: '₱${computation.salary} wage for ${computation.totalKarneUsed} meat portions',
                    isNegative: true,
                  ),
                  const _CupertinoDivider(),
                  _computedRow(
                    'TOTAL CASH REMITTANCE',
                    '₱${computation.cashRemit.toStringAsFixed(0)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            if (_submitted)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill, color: AppColors.success, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Closing Sales Submitted',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_todaySalesRecord != null)
                      Text(
                        'Orders: ${_todaySalesRecord!.displayTotalOrders} · Portions: ${_todaySalesRecord!.displayPortions} · Remittance: ₱${_todaySalesRecord!.expectedCashRemittance.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                        ),
                      ),
                  ],
                ),
              )
            else
              StaffButton(
                key: _closingSalesKey,
                label: 'Submit Final Closing Sales',
                icon: CupertinoIcons.cloud_upload_fill,
                onPressed: _confirmSubmit,
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _stockMeter({
    required String label,
    required int remaining,
    required int total,
  }) {
    final ratio = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    Color color = AppColors.success;
    if (ratio < 0.25) {
      color = AppColors.error;
    } else if (ratio < 0.50) {
      color = AppColors.warning;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ),
            Text(
              '$remaining/$total',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: AppColors.border,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _computedRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isSubtotal = false,
    bool isHeader = false,
    bool isNegative = false,
    String? subtitle,
  }) {
    final valueColor = isNegative
        ? AppColors.error
        : (isTotal ? AppColors.accent : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isTotal ? 15 : (isHeader || isSubtotal ? 14.5 : 13.5),
                    color: (isTotal || isHeader || isSubtotal) ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: (isTotal || isHeader || isSubtotal) ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isTotal ? 20 : (isSubtotal ? 16 : (isHeader ? 15 : 14)),
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CupertinoDivider extends StatelessWidget {
  const _CupertinoDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: AppColors.border,
    );
  }
}
