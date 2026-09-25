import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_batch.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CutterPortioningScreen extends StatefulWidget {
  const CutterPortioningScreen({super.key});

  @override
  State<CutterPortioningScreen> createState() => _CutterPortioningScreenState();
}

class _CutterPortioningScreenState extends State<CutterPortioningScreen> {
  final Map<String, int> _targets = {
    '250g': 150,
    '300g': 100,
    '400g': 100,
  };

  StreamSubscription<Map<String, int>>? _targetsSub;
  KarneBatch? _activeBatch;
  StreamSubscription<List<KarneBatch>>? _batchesSub;

  final Map<String, TextEditingController> _controllers = {
    '250g': TextEditingController(),
    '300g': TextEditingController(),
    '400g': TextEditingController(),
  };

  final _meatLeftController = TextEditingController();
  final _remainingNotesController = TextEditingController();
  bool _showSubmitButton = false;

  bool _isRefreshing = false;
  int _tempC = 28;
  String _condition = 'Partly Cloudy';
  IconData _weatherIcon = CupertinoIcons.cloud_sun_fill;
  String _liveLocation = '';
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    _meatLeftController.addListener(_validateInputs);
    _remainingNotesController.addListener(_validateInputs);
    for (var controller in _controllers.values) {
      controller.addListener(_validateInputs);
    }
    _targetsSub = FirestoreService.watchPortioningTargets().listen((targets) {
      if (mounted) {
        setState(() {
          _targets
            ..clear()
            ..addAll(targets);
        });
      }
    });

    _batchesSub = FirestoreService.watchProductionBatches().listen((batches) {
      if (mounted) {
        setState(() {
          final sorted = List<KarneBatch>.from(batches)
            ..sort((a, b) => b.date.compareTo(a.date));

          _activeBatch = sorted.firstWhere(
            (b) => b.cookingStatus == 'cutting' || b.cookingStatus == 'cooked' || b.target400g != null,
            orElse: () => sorted.isNotEmpty ? sorted.first : KarneBatch(
              id: 'default',
              name: 'KARNE BATCH',
              totalKilos: 150.0,
            ),
          );

          if (_activeBatch != null) {
            final activeSession = _activeBatch!.sessions.isNotEmpty
                ? (_activeBatch!.sessions.lastIndexWhere((s) => s.status == 'cutting' || s.status == 'cooked') != -1
                    ? _activeBatch!.sessions.lastWhere((s) => s.status == 'cutting' || s.status == 'cooked')
                    : _activeBatch!.sessions.last)
                : null;
            if (activeSession != null) {
              if (activeSession.target400g != null) _targets['400g'] = activeSession.target400g!;
              if (activeSession.target300g != null) _targets['300g'] = activeSession.target300g!;
              _targets['250g'] = activeSession.target250g ?? 0;
            } else {
              if (_activeBatch!.target250g != null) _targets['250g'] = _activeBatch!.target250g!;
              if (_activeBatch!.target300g != null) _targets['300g'] = _activeBatch!.target300g!;
              if (_activeBatch!.target400g != null) _targets['400g'] = _activeBatch!.target400g!;
            }
          }
        });
      }
    });

    _startWeatherTimer();
  }

  void _startWeatherTimer() {
    _fetchLiveWeather();
    _weatherTimer?.cancel();
    _weatherTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchLiveWeather();
    });
  }

  Future<void> _fetchLiveWeather({bool force = false}) async {
    final live = await WeatherService.fetchWeather(force: force);
    if (!mounted) return;
    setState(() {
      _tempC = live.tempC.round();
      _condition = live.condition;
      _weatherIcon = live.icon;
      _liveLocation = live.location;
      _isRefreshing = false;
    });
  }

  void _validateInputs() {
    final remainingG = int.tryParse(_meatLeftController.text.trim()) ?? 0;
    final hasNotes = _remainingNotesController.text.trim().isNotEmpty;

    // All portioning fields must be filled
    bool allFilled = true;
    for (var controller in _controllers.values) {
      if (controller.text.trim().isEmpty) {
        allFilled = false;
        break;
      }
    }
    if (_meatLeftController.text.trim().isEmpty) {
      allFilled = false;
    }

    // 400G and 300G must match target exactly
    final c400 = int.tryParse(_controllers['400g']!.text.trim());
    final c300 = int.tryParse(_controllers['300g']!.text.trim());
    final t400 = _targets['400g'] ?? 0;
    final t300 = _targets['300g'] ?? 0;
    final exact400 = c400 != null && c400 == t400;
    final exact300 = c300 != null && c300 == t300;

    // If remaining > 0, notes must be filled
    final notesOk = remainingG <= 0 || hasNotes;

    final canSubmit = allFilled && exact400 && exact300 && notesOk;

    if (_showSubmitButton != canSubmit) {
      setState(() => _showSubmitButton = canSubmit);
    }
  }

  void _onFieldChanged(String value) {
    setState(() {}); // Rebuild UI immediately to update card colors
    _validateInputs();
  }

  void _refreshWeather() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchLiveWeather(force: true);
  }

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void dispose() {
    _batchesSub?.cancel();
    _weatherTimer?.cancel();
    _targetsSub?.cancel();
    for (var controller in _controllers.values) {
      controller.removeListener(_validateInputs);
      controller.dispose();
    }
    _meatLeftController.removeListener(_validateInputs);
    _meatLeftController.dispose();
    _remainingNotesController.removeListener(_validateInputs);
    _remainingNotesController.dispose();
    super.dispose();
  }

  void _submitPortions() {
    final messenger = ScaffoldMessenger.of(context);
    final batch = _activeBatch;
    final notes = _remainingNotesController.text.trim();

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Submit Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sigurado ka bang tama ang lahat ng portion counts at remaining weight para sa ${batch?.name ?? "batch"}? Aabisuhan si Owner.'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ulat mo: "$notes"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final c250 = int.tryParse(_controllers['250g']!.text.trim()) ?? 0;
              final c300 = int.tryParse(_controllers['300g']!.text.trim()) ?? 0;
              final c400 = int.tryParse(_controllers['400g']!.text.trim()) ?? 0;
              final remainingG = int.tryParse(_meatLeftController.text.trim()) ?? 0;
              final cutterNotes = notes.isEmpty ? null : notes;

              final user = AuthService.currentUser;
              final empName = user?.fullName.isNotEmpty == true ? user!.fullName : AuthService.currentUsername;

              bool ok = false;
              if (batch != null && batch.id != 'default') {
                ok = await FirestoreService.submitBatchCutterReport(
                  batchId: batch.id,
                  batchName: batch.name,
                  employeeId: AuthService.currentUserId,
                  cutterName: empName,
                  count250g: c250,
                  count300g: c300,
                  count400g: c400,
                  target250g: _targets['250g'] ?? 150,
                  target300g: _targets['300g'] ?? 100,
                  target400g: _targets['400g'] ?? 100,
                  remainingGrams: remainingG,
                  cutterNotes: cutterNotes,
                );
              } else {
                ok = await FirestoreService.submitPortioningReport(
                  employeeId: AuthService.currentUserId,
                  employeeName: empName,
                  count250g: c250,
                  count300g: c300,
                  count400g: c400,
                  target250g: _targets['250g'] ?? 150,
                  target300g: _targets['300g'] ?? 100,
                  target400g: _targets['400g'] ?? 100,
                  remainingGrams: remainingG,
                  cutterNotes: cutterNotes,
                );
              }

              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Naisumite na ang portioning report kay Owner!' : 'May error sa pag-submit. Subukan ulit.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
                if (ok) {
                  setState(() {
                    for (var controller in _controllers.values) {
                      controller.clear();
                    }
                    _meatLeftController.clear();
                    _remainingNotesController.clear();
                  });
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Home',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 0. WEATHER WIDGET
            _weatherWidget(),
            const SizedBox(height: 18),

            // ASSIGNED BATCH CARD (MULA SA NILUTO NI COOK)
            if (_activeBatch != null) ...[
              StaffCard(
                padding: const EdgeInsets.all(18),
                highlighted: _activeBatch!.cookingStatus == 'completed',
                borderColor: _activeBatch!.cookingStatus == 'completed' ? AppColors.success : AppColors.accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(CupertinoIcons.scissors, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ACTIVE BATCH PARA SA PORTIONING',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.8),
                              ),
                              Text(
                                _activeBatch!.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_activeBatch!.cookingStatus == 'completed' ? AppColors.success : AppColors.accent).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _activeBatch!.cookingStatus == 'completed' ? 'TAPOS NA' : 'TARGETS READY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _activeBatch!.cookingStatus == 'completed' ? AppColors.success : AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PETSA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(DateFormat('MMM dd, yyyy').format(() {
                                    if (_activeBatch!.sessions.isNotEmpty) {
                                      final idx = _activeBatch!.sessions.lastIndexWhere(
                                          (s) => s.status == 'cutting' || s.status == 'cooked');
                                      if (idx != -1) return _activeBatch!.sessions[idx].date;
                                      return _activeBatch!.sessions.last.date;
                                    }
                                    return _activeBatch!.date;
                                  }()), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('NILUTO NI COOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_activeBatch!.cookedKilos?.toStringAsFixed(2) ?? _activeBatch!.totalKilos.toStringAsFixed(2)} KG',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _targetChip('400G (B1T1)', '${_targets['400g']} pcs'),
                              _targetChip('300G (Med)', '${_targets['300g']} pcs'),
                              _targetChip('250G (Reg)', (_targets['250g'] != null && _targets['250g']! > 0) ? '${_targets['250g']} pcs' : 'Lahat ng Tira'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            const StaffSectionHeader(
              label: 'Meat Portioning',
              icon: CupertinoIcons.scissors_alt,
              large: true,
              subtitle: 'Unahing buuin ang 400G at 300G; lahat ng tira ay para sa 250G',
            ),
            const SizedBox(height: 14),
            _buildPortionInputCard('400g'),
            const SizedBox(height: 12),
            _buildPortionInputCard('300g'),
            const SizedBox(height: 12),
            _buildPortionInputCard('250g'),
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Half-Cooked Meat',
              icon: CupertinoIcons.cube_box_fill,
              large: true,
              subtitle: 'Weight after portioning',
            ),
            const SizedBox(height: 14),
            StaffCard(
              padding: const EdgeInsets.all(20),
              highlighted: _meatLeftController.text.trim().isNotEmpty,
              borderColor: _meatLeftController.text.trim().isNotEmpty ? AppColors.accent : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REMAINING WEIGHT (GRAMS)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _meatLeftController,
                    placeholder: '0 g',
                    keyboardType: TextInputType.number,
                    onChanged: _onFieldChanged,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                ],
              ),
            ),
            // Notes field — only shown when there is remaining weight to explain
            if ((int.tryParse(_meatLeftController.text.trim()) ?? 0) > 0) ...[
              const SizedBox(height: 12),
              StaffCard(
                padding: const EdgeInsets.all(20),
                highlighted: _remainingNotesController.text.trim().isNotEmpty,
                borderColor: _remainingNotesController.text.trim().isNotEmpty
                    ? AppColors.success
                    : AppColors.error.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_bubble_fill,
                            size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'ULAT PARA SA NATIRANG KARNE (REQUIRED)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ipaliwanag kung bakit may natitira pang karne at kung ano ang dahilan.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _remainingNotesController,
                      placeholder: 'Halimbawa: Sobra sa hilaw na niluto, sira ang makina, etc.',
                      keyboardType: TextInputType.multiline,
                      maxLines: 4,
                      minLines: 3,
                      onChanged: _onFieldChanged,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _remainingNotesController.text.trim().isNotEmpty
                              ? AppColors.success.withValues(alpha: 0.5)
                              : AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!_showSubmitButton)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Builder(builder: (context) {
                  final c400 = int.tryParse(_controllers['400g']!.text.trim());
                  final c300 = int.tryParse(_controllers['300g']!.text.trim());
                  final t400 = _targets['400g'] ?? 0;
                  final t300 = _targets['300g'] ?? 0;
                  final remainingG = int.tryParse(_meatLeftController.text.trim()) ?? 0;
                  final hasNotes = _remainingNotesController.text.trim().isNotEmpty;

                  final issues = <String>[];
                  if (_controllers['400g']!.text.trim().isEmpty ||
                      _controllers['300g']!.text.trim().isEmpty ||
                      _controllers['250g']!.text.trim().isEmpty) {
                    issues.add('Punan ang lahat ng portioning fields.');
                  }
                  if (c400 != null && c400 != t400) {
                    issues.add('400G: dapat exactly $t400 pcs.');
                  }
                  if (c300 != null && c300 != t300) {
                    issues.add('300G: dapat exactly $t300 pcs.');
                  }
                  if (_meatLeftController.text.trim().isEmpty) {
                    issues.add('Punan ang remaining weight.');
                  }
                  if (remainingG > 0 && !hasNotes) {
                    issues.add('Mag-ulat kung bakit may natirang karne.');
                  }

                  return Text(
                    issues.isNotEmpty ? issues.join(' ') : 'Kumpletuhin ang lahat ng fields.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }),
              ),
            if (_showSubmitButton)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: StaffButton(
                  label: 'SUBMIT REPORT',
                  onPressed: _submitPortions,
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _weatherWidget() {
    return StaffCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ─────────────────────────────────────────
          Text(
            '${_greetingPrefix()}, ${AuthService.currentUsername}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          // ── Location row ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4285F4), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _liveLocation.isNotEmpty
                            ? _liveLocation
                            : 'Central Kitchen Area',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _refreshWeather,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Text('Update',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent)),
                      const SizedBox(width: 4),
                      _isRefreshing
                          ? const CupertinoActivityIndicator(radius: 5)
                          : const Icon(CupertinoIcons.refresh,
                              size: 10, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_weatherIcon,
                  size: 40, color: AppColors.pastelBrown),
              const SizedBox(width: 12),
              Text('$_tempC°C',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                      letterSpacing: -1)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_condition,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(
                    _liveLocation.isNotEmpty
                        ? _liveLocation
                        : 'Central Kitchen Area',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortionInputCard(String size) {
    final target = _targets[size] ?? 0;
    final controller = _controllers[size]!;
    final current = int.tryParse(controller.text.trim());
    final hasInput = controller.text.trim().isNotEmpty;

    final bool isStrict = size == '400g' || size == '300g';
    final bool isExact = hasInput && current == target;
    final bool isError = isStrict && hasInput && current != target;
    final bool isDone = isStrict ? isExact : (hasInput && (current ?? 0) > 0);

    // For 250G: ideal reference = kota - t400 - t300
    final t400Actual = _targets['400g'] ?? 0;
    final t300Actual = _targets['300g'] ?? 0;
    final ideal250 = size == '250g' && _activeBatch != null
        ? ((_activeBatch!.sessions.isNotEmpty
              ? _activeBatch!.sessions
                  .lastWhere((s) => s.status == 'cutting' || s.status == 'cooked',
                      orElse: () => _activeBatch!.sessions.last)
                  .kota
              : 0) -
            t400Actual -
            t300Actual)
            .clamp(0, 9999)
        : target;

    Color borderColor;
    Color textColor;
    if (isError) {
      borderColor = AppColors.error;
      textColor = AppColors.error;
    } else if (isDone) {
      borderColor = AppColors.success.withValues(alpha: 0.4);
      textColor = AppColors.success;
    } else {
      borderColor = AppColors.border;
      textColor = AppColors.accent;
    }

    final String subtitle;
    if (isStrict) {
      subtitle = isError
          ? 'Dapat exactly $target pcs — hindi pwedeng kulang o sobra'
          : 'Target: $target pcs (dapat exact)';
    } else {
      // 250G — show ideal reference
      subtitle = target > 0
          ? 'Ideal: $ideal250 pcs (maaaring iba ang aktwal)'
          : 'Ideal: $ideal250 pcs — lahat ng tira';
    }

    return StaffCard(
      padding: const EdgeInsets.all(18),
      highlighted: isDone && !isError,
      borderColor: isError ? AppColors.error : (isDone ? AppColors.accent : null),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  size.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isError ? AppColors.error : (isDone ? AppColors.success : AppColors.textSecondary),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              placeholder: '0',
              onChanged: _onFieldChanged,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: textColor,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.accent)),
        ],
      ),
    );
  }
}

