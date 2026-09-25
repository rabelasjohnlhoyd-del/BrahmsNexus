import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_notification.dart';
import '../../../models/inventory_batch.dart';
import '../../../services/firestore_service.dart';
import '../../../services/notification_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class KarneBatchDetailScreen extends StatefulWidget {
  const KarneBatchDetailScreen({super.key, required this.batch, this.onBatchChanged});
  final KarneBatch batch;

  /// Called every time this batch's sessions change (add/edit/delete),
  /// so the InventoryScreen list (and anything derived from it, like
  /// Monthly Financials) can be kept in sync without waiting for a
  /// pop() return value.
  final ValueChanged<KarneBatch>? onBatchChanged;

  @override
  State<KarneBatchDetailScreen> createState() => _KarneBatchDetailScreenState();
}

class _KarneBatchDetailScreenState extends State<KarneBatchDetailScreen> {
  late KarneBatch _batch;
  StreamSubscription<KarneBatch?>? _batchSub;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
    _updateHeader();
    // Subscribe to real-time updates for this specific batch document
    // so that any change (from Admin Web or Owner App) is reflected live.
    _batchSub = FirestoreService.watchSingleBatch(_batch.id).listen((updated) {
      if (updated != null && mounted) {
        setState(() => _batch = updated);
        widget.onBatchChanged?.call(updated);
      }
    });
  }

  @override
  void dispose() {
    _batchSub?.cancel();
    super.dispose();
  }

  void _updateHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shell = context.findAncestorStateOfType<AdminWebShellState>();
      shell?.setTitle('BATCH: ${_batch.name.toUpperCase()}');
    });
  }

  void _addSession() {
    final brandCtrl = TextEditingController();
    final resekoCtrl = TextEditingController(text: '28');
    final minutesCtrl = TextEditingController();
    final kilosCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.soup_kitchen_rounded, color: AdminWebColors.accent),
              SizedBox(width: 10),
              Text('New Cooking Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Brand ng Karne:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminWebColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: brandCtrl,
                    decoration: const InputDecoration(
                      labelText: 'BRAND NAME',
                      hintText: 'e.g. Danish Crown, Pilgrims',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.recommend_rounded, size: 16, color: AdminWebColors.accent),
                        label: const Text('Danish Crown (25 mins)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDlgState(() {
                            brandCtrl.text = 'Danish Crown';
                            minutesCtrl.text = '25';
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.recommend_rounded, size: 16, color: AdminWebColors.accent),
                        label: const Text('Pilgrims (35 mins)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDlgState(() {
                            brandCtrl.text = 'Pilgrims';
                            minutesCtrl.text = '35';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: minutesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'MINUTES LAGA',
                      hintText: 'e.g. 25 o 35 mins',
                      border: OutlineInputBorder(),
                      suffixText: 'MINS',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: kilosCtrl,
                    decoration: const InputDecoration(
                      labelText: 'KILOS TO COOK (HILAW)',
                      hintText: 'e.g. 151.00',
                      border: OutlineInputBorder(),
                      suffixText: 'KG',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: resekoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'RESEKO TARGET LIMIT',
                      hintText: 'Standard: 28',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.accent, foregroundColor: Colors.white),
              onPressed: () {
                final double r = double.tryParse(resekoCtrl.text.trim()) ?? 28.0;
                final int? m = int.tryParse(minutesCtrl.text.trim());
                final double? k = double.tryParse(kilosCtrl.text.trim());
                if (m == null || k == null || brandCtrl.text.trim().isEmpty) return;

                final brandName = brandCtrl.text.trim();
                final session = KarneSession(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  date: DateTime.now(),
                  brand: brandName,
                  resekoApplied: r,
                  boilingMinutes: m,
                  kilosCooked: k,
                  status: 'pending',
                );

                setState(() {
                  final newSessions = List<KarneSession>.from(_batch.sessions)..add(session);
                  _batch = _batch.copyWith(
                    sessions: newSessions,
                    brand: brandName,
                    boilingMinutes: m,
                    resekoApplied: r,
                    cookingStatus: 'pending',
                  );
                });

                widget.onBatchChanged?.call(_batch);
                FirestoreService.saveProductionBatch(_batch);

                // Notify production cook
                NotificationService.sendNotification(
                  title: 'Bagong Iluluto: ${_batch.name}',
                  message: 'Brand: $brandName ($m mins boiling) - ${k.toStringAsFixed(2)} KG ang target na lutuin.',
                  type: NotificationType.inventoryAlert,
                  targetRole: 'production',
                );

                Navigator.pop(ctx);
              },
              child: const Text('ADD SESSION'),
            ),
          ],
        ),
      ),
    );
  }

  void _setTargetsForSession(KarneSession session, int index) {
    final t400Ctrl = TextEditingController(text: session.target400g != null ? '${session.target400g}' : '');
    final t300Ctrl = TextEditingController(text: session.target300g != null ? '${session.target300g}' : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlgState) {
          final t400 = int.tryParse(t400Ctrl.text.trim()) ?? 0;
          final t300 = int.tryParse(t300Ctrl.text.trim()) ?? 0;
          final ideal250 = (session.kota - t400 - t300).clamp(0, 9999);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.content_cut_rounded, color: AdminWebColors.accent),
                SizedBox(width: 10),
                Text('Set Targets para kay Meat Cutter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hilaw na Karne: ${session.kilosCooked.toStringAsFixed(2)} KG • Ideal Yield: ${session.idealYield.toInt()} pcs • Kota: ${session.kota} pcs',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdminWebColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('I-assign ang target sa 400G at 300G. Ang natitira sa Kota ay magiging ideal target para sa 250G.',
                              style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: t400Ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '400G B1T1 Target (pcs)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale_rounded, size: 18),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: t300Ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '300G Medium Target (pcs)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale_rounded, size: 18),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AdminWebColors.surfaceTint,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminWebColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AdminWebColors.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Target: $t400 pcs (400G) + $t300 pcs (300G) = ${t400 + t300} pcs\nIdeal 250G Target: ${session.kota} kota − ${t400 + t300} = $ideal250 pcs\n(250G: okay kahit sobra o kulang)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.textPrimary),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.accent, foregroundColor: Colors.white),
                onPressed: () async {
                  final t400Val = int.tryParse(t400Ctrl.text.trim()) ?? 0;
                  final t300Val = int.tryParse(t300Ctrl.text.trim()) ?? 0;
                  final t250Val = (session.kota - t400Val - t300Val).clamp(0, 9999);

                  setState(() {
                    final updated = session.copyWith(
                      target400g: t400Val,
                      target300g: t300Val,
                      target250g: t250Val,
                      status: 'cutting',
                    );
                    final newSessions = List<KarneSession>.from(_batch.sessions);
                    newSessions[index] = updated;
                    _batch = _batch.copyWith(
                      sessions: newSessions,
                      target400g: t400Val,
                      target300g: t300Val,
                      target250g: t250Val,
                      cookingStatus: 'cutting',
                    );
                  });

                  widget.onBatchChanged?.call(_batch);
                  await FirestoreService.setBatchPortioningTargets(
                    batchId: _batch.id,
                    batchName: _batch.name,
                    target250g: t250Val,
                    target300g: t300Val,
                    target400g: t400Val,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('SAVE & NOTIFY CUTTER'),
              ),
            ],
          );
        },
      ),
    );
  }


  void _deleteSession(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this cooking session? This will return the kilos to the batch stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.error),
            onPressed: () {
              setState(() {
                final newSessions = List<KarneSession>.from(_batch.sessions);
                newSessions.removeAt(index);
                _batch = _batch.copyWith(sessions: newSessions);
              });
              widget.onBatchChanged?.call(_batch);
              FirestoreService.saveProductionBatch(_batch);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cooking session deleted.')),
              );
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _exportAsPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PDF Report for this batch...'),
        duration: Duration(seconds: 2),
      ),
    );
    // In a real app, we'd use the 'pdf' package here.
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: Column(
        children: [
          // Sub-navigation bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                  label: const Text('BACK TO INVENTORY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
                  style: TextButton.styleFrom(foregroundColor: AdminWebColors.accent),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBatchDashboard(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COOKING HISTORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminWebColors.textPrimary, letterSpacing: 0.5)),
                          Text('Track daily production and efficiency', style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary)),
                        ],
                      ),
                      if (_batch.remainingKilos > 0) ...[
                        Builder(builder: (context) {
                          final hasActiveSession = _batch.sessions.any(
                            (s) => s.status != 'completed',
                          );
                          return Tooltip(
                            message: hasActiveSession
                                ? 'Hindi maaaring mag-add ng bagong session habang may kasalukuyang session na hindi pa tapos.'
                                : '',
                            child: ElevatedButton.icon(
                              onPressed: hasActiveSession ? null : _addSession,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('NEW COOKING SESSION'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminWebColors.accent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AdminWebColors.border,
                                disabledForegroundColor: AdminWebColors.textSecondary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_batch.sessions.isEmpty)
                    _buildEmptySessions()
                  else
                    ...List.generate(_batch.sessions.length, (index) {
                      final s = _batch.sessions.reversed.toList()[index];
                      final originalIndex = _batch.sessions.length - 1 - index;
                      return _buildSessionCard(s, originalIndex);
                    }),
                  if (_batch.remainingKilos <= 0 && _batch.sessions.isNotEmpty) _buildGrandTotal(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchDashboard() {
    return Row(
      children: [
        Expanded(child: _kpiTile('Total Stock', '${_batch.totalKilos}', 'KILOGRAMS', Icons.inventory_2_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _kpiTile('Remaining', _batch.remainingKilos.toStringAsFixed(1), 'KG LEFT', Icons.hourglass_bottom_rounded, highlight: true)),
        const SizedBox(width: 16),
        Expanded(child: _kpiTile('Sessions', '${_batch.sessions.length}', 'TOTAL LUTO', Icons.restaurant_rounded)),
      ],
    );
  }

  Widget _kpiTile(String label, String val, String sub, IconData icon, {bool highlight = false}) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: highlight ? AdminWebColors.accent : AdminWebColors.textSecondary),
          const SizedBox(height: 12),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: highlight ? AdminWebColors.accent : AdminWebColors.textPrimary)),
              const SizedBox(width: 4),
              Text(sub, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminWebColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySessions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: AdminWebColors.border.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            const Text('No sessions recorded yet.', style: TextStyle(color: AdminWebColors.textSecondary, fontWeight: FontWeight.w600)),
            const Text('Click "New Cooking Session" to start tracking.', style: TextStyle(color: AdminWebColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(KarneSession s, int index) {
    final bool hasActual = s.hasActualOutput;
    final bool hasBreakdown = (s.actual400g != null && s.actual400g! > 0) ||
        (s.actual300g != null && s.actual300g! > 0) ||
        (s.actual250g != null && s.actual250g! > 0);

    Color statusColor = AdminWebColors.warning;
    IconData statusIcon = Icons.hourglass_top_rounded;
    String statusLabel = 'ILULUTO PA NI COOK';

    if (s.status == 'completed' || s.hasActualOutput) {
      statusColor = AdminWebColors.success;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'COMPLETED';
    } else if (s.status == 'cutting') {
      statusColor = Colors.purple;
      statusIcon = Icons.content_cut_rounded;
      statusLabel = 'PINUPUTOL NI CUTTER';
    } else if (s.status == 'cooked' || s.cookedKilos != null) {
      statusColor = Colors.blue;
      statusIcon = Icons.soup_kitchen_rounded;
      statusLabel = 'NALUTO NA — I-SET ANG TARGETS';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.event_available_rounded, size: 16, color: AdminWebColors.accent),
                    Text(DateFormat('MMM dd, yyyy').format(s.date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    _badge('RESEKO ${s.resekoApplied.toStringAsFixed(0)}%', AdminWebColors.accent),
                    _badge(statusLabel, statusColor, icon: statusIcon),
                  ],
                ),
                 Row(
                  children: [
                    if (s.status == 'cooked' || (s.cookedKilos != null && s.status != 'completed'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _setTargetsForSession(s, index),
                          icon: const Icon(Icons.content_cut_rounded, size: 14),
                          label: const Text('SET TARGETS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple,
                            side: const BorderSide(color: Colors.purple),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    // Delete only allowed when session hasn't been cooked yet
                    if (s.status == 'pending')
                      IconButton(
                        onPressed: () => _deleteSession(index),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AdminWebColors.error),
                        tooltip: 'Delete Session',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                Text(
                  'BRAND: ${s.brand.toUpperCase()} • ${s.boilingMinutes} MINS BOILING',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.textSecondary, letterSpacing: 0.3),
                ),
                if (s.cookedBy != null && s.cookedBy!.isNotEmpty)
                  Text(
                    'COOK: ${s.cookedBy}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue, letterSpacing: 0.3),
                  ),
                if (s.cutterName != null && s.cutterName!.isNotEmpty)
                  Text(
                    'CUTTER: ${s.cutterName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple, letterSpacing: 0.3),
                  ),
              ],
            ),
            if (s.cutterNotes != null && s.cutterNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note_alt_outlined, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ulat ni Cutter (${s.cutterName ?? "Cutter"})${s.cutterRemainingGrams != null && s.cutterRemainingGrams! > 0 ? " sa Natirang Karne (${s.cutterRemainingGrams}g)" : ""}: "${s.cutterNotes}"',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (hasBreakdown) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.15)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('400G = ${s.actual400g ?? 0} pcs (${((s.actual400g ?? 0) * 400 / 1000).toStringAsFixed(2)} KG)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                    Text('300G = ${s.actual300g ?? 0} pcs (${((s.actual300g ?? 0) * 300 / 1000).toStringAsFixed(2)} KG)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                    Text('250G = ${s.actual250g ?? 0} pcs (${((s.actual250g ?? 0) * 250 / 1000).toStringAsFixed(2)} KG)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                    Text('Kabuuang Naluto: ${s.nalutoKg?.toStringAsFixed(2) ?? "0.00"} KG',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AdminWebColors.accent)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sessionDetail('HILAW (KG)', s.kilosCooked.toStringAsFixed(1), isMain: true),
                _sessionDetail(
                  'NALUTO (KG)',
                  s.nalutoKg != null
                      ? s.nalutoKg!.toStringAsFixed(2)
                      : (s.status == 'cooked' || s.status == 'cutting' ? 'Hintayin si Cutter' : '--'),
                  isMain: true,
                ),
                _sessionDetail('IDEAL YIELD', '${s.idealYield.toInt()}', isMain: true),
                _sessionDetail('KOTA (${s.resekoApplied.toStringAsFixed(0)}%)', '${s.kota}', color: AdminWebColors.accent, isMain: true),
                _sessionDetail(
                  'NAGAWA',
                  hasActual ? '${s.nagawa} pcs' : '--',
                  subtext: hasBreakdown
                      ? '400G = ${s.actual400g ?? 0} pcs\n300G = ${s.actual300g ?? 0} pcs\n250G = ${s.actual250g ?? 0} pcs'
                      : null,
                  color: hasActual ? AdminWebColors.success : null,
                  isMain: true,
                ),
                _sessionDetail(
                  'RESULT',
                  hasActual
                      ? (s.resultDifference > 0
                          ? '+${s.resultDifference} (SOBRA)'
                          : (s.resultDifference < 0
                              ? '${s.resultDifference} (KULANG)'
                              : '0 (EXACT)'))
                      : '--',
                  color: hasActual
                      ? (s.resultDifference >= 0 ? AdminWebColors.success : AdminWebColors.error)
                      : null,
                ),
                _sessionDetail(
                  'ACTUAL RESEKO',
                  hasActual && s.actualReseko != null ? '${s.actualReseko!.toStringAsFixed(1)}%' : '--',
                  color: hasActual && s.actualReseko != null
                      ? (s.actualReseko! <= s.resekoApplied ? AdminWebColors.success : AdminWebColors.error)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _sessionDetail(String label, String val, {Color? color, bool isMain = false, String? subtext}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AdminWebColors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMain ? 18 : 15, color: color ?? AdminWebColors.textPrimary)),
        if (subtext != null && subtext.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtext, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdminWebColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _buildGrandTotal() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AdminWebColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_rounded, color: AdminWebColors.accent),
              const SizedBox(width: 12),
              const Text('GRAND TOTAL BATCH REPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AdminWebColors.accent, letterSpacing: 1)),
            ],
          ),
          const Divider(height: 48),
          _grandItem('Total Kilos Cooked', '${_batch.totalKilos} KG'),
          _grandItem('Total Pieces Produced', '${_batch.totalPcsNagawa} PCS'),
          _grandItem('Overall Shortage', '${_batch.totalShort}', color: AdminWebColors.error),
          _grandItem('Overall Surplus', '${_batch.totalSobra}', color: Colors.blue),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportAsPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('EXPORT BATCH REPORT AS PDF', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grandItem(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color ?? AdminWebColors.textPrimary)),
        ],
      ),
    );
  }
}
