import 'package:flutter/material.dart';
import '../../../models/inventory_batch.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class KarneBatchDetailScreen extends StatefulWidget {
  const KarneBatchDetailScreen({super.key, required this.batch});
  final KarneBatch batch;

  @override
  State<KarneBatchDetailScreen> createState() => _KarneBatchDetailScreenState();
}

class _KarneBatchDetailScreenState extends State<KarneBatchDetailScreen> {
  late KarneBatch _batch;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
    _updateHeader();
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
    final minutesCtrl = TextEditingController(text: '25');
    final kilosCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Cooking Session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'BRAND NAME')),
              TextField(controller: resekoCtrl, decoration: const InputDecoration(labelText: 'RESEKO %', suffixText: '%'), keyboardType: TextInputType.number),
              TextField(controller: minutesCtrl, decoration: const InputDecoration(labelText: 'MINUTES LAGA'), keyboardType: TextInputType.number),
              TextField(controller: kilosCtrl, decoration: const InputDecoration(labelText: 'KILOS TO COOK', suffixText: 'KG'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final double? r = double.tryParse(resekoCtrl.text);
              final int? m = int.tryParse(minutesCtrl.text);
              final double? k = double.tryParse(kilosCtrl.text);
              if (r == null || m == null || k == null || brandCtrl.text.isEmpty) return;

              final session = KarneSession(
                date: DateTime.now(),
                brand: brandCtrl.text,
                resekoApplied: r,
                boilingMinutes: m,
                kilosCooked: k,
              );
              setState(() {
                final newSessions = List<KarneSession>.from(_batch.sessions)..add(session);
                _batch = _batch.copyWith(sessions: newSessions);
              });
              Navigator.pop(context);
            },
            child: const Text('ADD SESSION'),
          ),
        ],
      ),
    );
  }

  void _enterActualPcs(int index) {
    final session = _batch.sessions[index];
    final actualCtrl = TextEditingController(text: session.actualPcs == 0 ? '' : session.actualPcs.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Actual Nagawa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kota (Estimated): ${session.kota} pcs', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: actualCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Ilang pcs ang nagawa?'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final updatedSession = KarneSession(
                  date: session.date,
                  brand: session.brand,
                  resekoApplied: session.resekoApplied,
                  boilingMinutes: session.boilingMinutes,
                  kilosCooked: session.kilosCooked,
                  actualPcs: int.tryParse(actualCtrl.text) ?? 0,
                );
                final newSessions = List<KarneSession>.from(_batch.sessions);
                newSessions[index] = updatedSession;
                _batch = _batch.copyWith(sessions: newSessions);
              });
              Navigator.pop(context);
            },
            child: const Text('SAVE ACTUAL'),
          ),
        ],
      ),
    );
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
                      if (_batch.remainingKilos > 0)
                        ElevatedButton.icon(
                          onPressed: _addSession,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('NEW COOKING SESSION'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminWebColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
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
    final bool hasActual = s.actualPcs > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded, size: 16, color: AdminWebColors.accent),
                    const SizedBox(width: 8),
                    Text('${s.date.month}/${s.date.day}/${s.date.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(width: 12),
                    _badge('RESEKO ${s.resekoApplied}%', AdminWebColors.success),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _enterActualPcs(index),
                  icon: Icon(hasActual ? Icons.edit_rounded : Icons.add_circle_outline_rounded, size: 16),
                  label: Text(hasActual ? 'EDIT NAGAW' : 'ENTER ACTUAL', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: hasActual ? AdminWebColors.textSecondary : AdminWebColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('BRAND: ${s.brand.toUpperCase()} • ${s.boilingMinutes} MINS BOILING', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.textSecondary, letterSpacing: 0.3)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sessionDetail('KILOS', '${s.kilosCooked}', isMain: true),
                _sessionDetail('KOTA', '${s.kota}', color: AdminWebColors.accent, isMain: true),
                _sessionDetail('NAGAWA', hasActual ? '${s.actualPcs}' : '--', color: hasActual ? AdminWebColors.success : null, isMain: true),
                _sessionDetail('SOBRA', hasActual ? '${s.sobra}' : '0', color: Colors.blue),
                _sessionDetail('SHORT', hasActual ? '${s.short}' : '0', color: AdminWebColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
    );
  }

  Widget _sessionDetail(String label, String val, {Color? color, bool isMain = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AdminWebColors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMain ? 18 : 15, color: color ?? AdminWebColors.textPrimary)),
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
