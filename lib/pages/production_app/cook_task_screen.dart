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

class CookTaskScreen extends StatefulWidget {
  const CookTaskScreen({super.key});

  @override
  State<CookTaskScreen> createState() => _CookTaskScreenState();
}

class _CookTaskScreenState extends State<CookTaskScreen> {
  final List<bool> _checkSteps = [false, false, false];

  KarneBatch? _activeBatch;
  StreamSubscription<List<KarneBatch>>? _batchesSub;

  bool _isRefreshing = false;
  int _tempC = 28;
  String _condition = 'Partly Cloudy';
  IconData _weatherIcon = CupertinoIcons.cloud_sun_fill;
  String _liveLocation = '';
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    _startWeatherTimer();

    _batchesSub = FirestoreService.watchProductionBatches().listen((batches) {
      if (mounted) {
        setState(() {
          final sorted = List<KarneBatch>.from(batches)
            ..sort((a, b) => b.date.compareTo(a.date));

          _activeBatch = sorted.firstWhere(
            (b) => b.cookingStatus == 'pending' || b.cookingStatus == 'cooked',
            orElse: () => sorted.isNotEmpty ? sorted.first : KarneBatch(
              id: 'default',
              name: 'KARNE BATCH',
              totalKilos: 150.0,
            ),
          );
        });
      }
    });
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
    super.dispose();
  }

  void _confirmCookingFinished(double targetCookKilos) {
    final batch = _activeBatch;
    final messenger = ScaffoldMessenger.of(context);

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Kumpirmahin ang Pagluto'),
        content: Text('Sigurado ka bang tapos na ang pagluluto ng ${targetCookKilos.toStringAsFixed(1)} kg ng karne para sa ${batch?.name ?? "batch"}? Aabisuhan si Owner upang makapag-set ng targets para kay Meat Cutter.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final user = AuthService.currentUser;
              final empName = user?.fullName.isNotEmpty == true ? user!.fullName : AuthService.currentUsername;

              bool ok = false;
              if (batch != null && batch.id != 'default') {
                ok = await FirestoreService.submitCookBatchReport(
                  batchId: batch.id,
                  batchName: batch.name,
                  cookedKilos: targetCookKilos,
                  cookName: empName,
                );
              } else {
                ok = true;
              }

              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Nakumpirma na ang pagluto! Aabisuhan si Owner para mag-set ng portion targets.'
                        : 'May error sa pag-submit. Subukan ulit.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
                if (ok) {
                  setState(() {
                    _checkSteps.fillRange(0, 3, true);
                  });
                }
              }
            },
            child: const Text('Kumpirmahin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = (_activeBatch != null && _activeBatch!.sessions.isNotEmpty)
        ? _activeBatch!.sessions.last
        : null;
    final double targetCookKilos = activeSession != null
        ? activeSession.hilawKilos
        : (_activeBatch?.totalKilos ?? 150.0);
    final String displayBrand = activeSession?.brand ??
        ((_activeBatch?.brand != null && _activeBatch!.brand!.isNotEmpty)
            ? _activeBatch!.brand!
            : 'Standard Karne');
    final int displayBoilingMins = activeSession?.boilingMinutes ?? _activeBatch?.boilingMinutes ?? 25;

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

            // ASSIGNED BATCH CARD (MULA KAY OWNER)
            if (_activeBatch != null) ...[
              StaffCard(
                padding: const EdgeInsets.all(18),
                highlighted: _activeBatch!.cookingStatus == 'cooked',
                borderColor: _activeBatch!.cookingStatus == 'cooked' ? AppColors.success : AppColors.accent,
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
                          child: const Icon(CupertinoIcons.flame_fill, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeSession != null
                                    ? 'SESSION #${activeSession.sessionNumber}: ILULUTO NI COOK'
                                    : 'ASSIGNED BATCH MULA KAY OWNER',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.8),
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
                            color: (_activeBatch!.cookingStatus == 'cooked' ? AppColors.success : AppColors.accent).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _activeBatch!.cookingStatus == 'cooked' ? 'NALUTO NA' : 'ILULUTO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _activeBatch!.cookingStatus == 'cooked' ? AppColors.success : AppColors.accent,
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
                                  const Text('BRAND NG KARNE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayBrand,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('ORAS NG LAGA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$displayBoilingMins Mins Boiling',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PETSA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(DateFormat('MMM dd, yyyy').format(activeSession?.date ?? _activeBatch!.date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('TARGET NA KILOS (HILAW)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${targetCookKilos.toStringAsFixed(2)} KG',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.accent),
                                  ),
                                ],
                              ),
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

            // 1. COOKING STATUS
            const StaffSectionHeader(
              label: 'Cooking Status',
              icon: CupertinoIcons.checkmark_circle_fill,
              large: true,
              subtitle: 'Daily production checklist',
            ),
            const SizedBox(height: 14),
            StaffCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Production Steps', 
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  _buildCheckItem('Preparation of Raw Meat', 0),
                  _buildCheckItem('Cooking Process (${targetCookKilos.toStringAsFixed(1)}kg • $displayBoilingMins mins boiling)', 1),
                  _buildCheckItem('Cleaning & Proper Storage', 2),
                ],
              ),
            ),
            
            const SizedBox(height: 26),

            // 2. COOKING CONFIRMATION
            const StaffSectionHeader(
              label: 'Cooking Confirmation',
              icon: CupertinoIcons.checkmark_seal_fill,
              large: true,
              subtitle: 'Kumpirmahin kapag naluto na ang karne',
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final bool isCooked = activeSession?.status == 'cooked' ||
                    activeSession?.status == 'cutting' ||
                    activeSession?.status == 'completed' ||
                    _activeBatch?.cookingStatus == 'cooked' ||
                    _activeBatch?.cookingStatus == 'cutting' ||
                    _activeBatch?.cookingStatus == 'completed';

                return StaffCard(
                  padding: const EdgeInsets.all(22),
                  highlighted: isCooked,
                  borderColor: isCooked ? AppColors.success : AppColors.accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isCooked) ...[
                        Row(
                          children: [
                            const Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'NAKUMPIRMA NA: NALUTO NA ANG KARNE',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Naluto na ang ${targetCookKilos.toStringAsFixed(1)} KG ($displayBrand). Hinihintay na ang portioning targets mula kay Owner.',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'KUMPIRMASYON SA PAGLUTO',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Kapag tapos na ang pagpapakulo ng ${targetCookKilos.toStringAsFixed(1)} KG sa loob ng $displayBoilingMins minuto, pindutin ang button sa ibaba upang makumpirma.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 18),
                        StaffButton(
                          label: 'KUMPIRMAHIN NA NALUTO NA',
                          onPressed: () => _confirmCookingFinished(targetCookKilos),
                        ),
                      ],
                    ],
                  ),
                );
              },
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
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _liveLocation.isNotEmpty ? _liveLocation : 'Central Kitchen Area',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _refreshWeather,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Text('Update', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                      const SizedBox(width: 4),
                      _isRefreshing ? const CupertinoActivityIndicator(radius: 5) : const Icon(CupertinoIcons.refresh, size: 10, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_weatherIcon, size: 40, color: AppColors.pastelBrown),
              const SizedBox(width: 12),
              Text('$_tempC°C', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: AppColors.textPrimary, letterSpacing: -1)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_condition, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(
                    _liveLocation.isNotEmpty ? _liveLocation : 'Central Kitchen Area',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, int index) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => setState(() => _checkSteps[index] = !_checkSteps[index]),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              _checkSteps[index] ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
              color: _checkSteps[index] ? AppColors.success : AppColors.textSecondary,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _checkSteps[index] ? AppColors.textPrimary : AppColors.textSecondary,
                  decoration: _checkSteps[index] ? TextDecoration.lineThrough : null,
                  fontSize: 16,
                  fontWeight: _checkSteps[index] ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

