import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/inventory_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CookingSession {
  final String id;
  final String brand;
  final double resekoPercent;
  final int minutesLaga;
  final double kilosToCook;
  final DateTime date;
  double? actualNagawa;

  CookingSession({
    required this.id,
    required this.brand,
    required this.resekoPercent,
    required this.minutesLaga,
    required this.kilosToCook,
    required this.date,
    this.actualNagawa,
  });

  double get outcome {
    final double portionBase = minutesLaga * 10.0;
    if (portionBase <= 0) return 0;
    return (kilosToCook * 1000) / portionBase;
  }

  double get kota {
    return outcome * (1 - (resekoPercent / 100));
  }

  double? get difference => actualNagawa != null ? actualNagawa! - kota : null;
}

class KarneBatch {
  final String id;
  final String name;
  final double totalKilos;
  final List<CookingSession> sessions;

  KarneBatch({
    required this.id,
    required this.name,
    required this.totalKilos,
    this.sessions = const [],
  });

  double get remainingKilos {
    double used = 0;
    for (var s in sessions) {
      used += s.kilosToCook;
    }
    return totalKilos - used;
  }
}

class OwnerInventoryScreen extends StatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> {
  int _section = 0; // 0 = Warehouse, 1 = Branches, 2 = Logs

  final List<KarneBatch> _batches = [
    KarneBatch(
      id: 'kb1',
      name: 'Batch Danish Crown - July',
      totalKilos: 1000,
    ),
  ];

  final List<BranchStock> _branchStocks = [
    BranchStock(
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      allocatedKg: 25,
      remainingKg: 3,
    ),
    BranchStock(
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 1,
    ),
    BranchStock(
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      allocatedKg: 18,
      remainingKg: 18,
    ),
  ];

  final List<StockTransferLog> _transferLogs = [];

  void _showAddBatchDialog() {
    final nameController = TextEditingController();
    final kilosController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Start New Batch'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: nameController, placeholder: 'Batch Name'),
            const SizedBox(height: 8),
            CupertinoTextField(controller: kilosController, placeholder: 'Total Kilos', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              final k = double.tryParse(kilosController.text);
              if (nameController.text.isNotEmpty && k != null) {
                setState(() {
                  _batches.insert(0, KarneBatch(
                    id: 'kb${_batches.length + 1}',
                    name: nameController.text,
                    totalKilos: k,
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showNewSessionDialog(KarneBatch batch) {
    final brandCtrl = TextEditingController();
    final resekoCtrl = TextEditingController(text: '28');
    final minutesCtrl = TextEditingController(text: '25');
    final kilosCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('New Cooking Session'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: brandCtrl, placeholder: 'Brand Name'),
            const SizedBox(height: 8),
            CupertinoTextField(controller: resekoCtrl, placeholder: 'Reseko %', keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            CupertinoTextField(controller: minutesCtrl, placeholder: 'Minutes Laga', keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            CupertinoTextField(controller: kilosCtrl, placeholder: 'Kilos to Cook', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              final r = double.tryParse(resekoCtrl.text);
              final m = int.tryParse(minutesCtrl.text);
              final k = double.tryParse(kilosCtrl.text);
              if (brandCtrl.text.isNotEmpty && r != null && m != null && k != null) {
                setState(() {
                  final idx = _batches.indexWhere((b) => b.id == batch.id);
                  final newSessions = List<CookingSession>.from(_batches[idx].sessions)
                    ..add(CookingSession(
                      id: 'cs${batch.sessions.length + 1}',
                      brand: brandCtrl.text,
                      resekoPercent: r,
                      minutesLaga: m,
                      kilosToCook: k,
                      date: DateTime.now(),
                    ));
                  _batches[idx] = KarneBatch(
                    id: batch.id,
                    name: batch.name,
                    totalKilos: batch.totalKilos,
                    sessions: newSessions,
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _enterActualNagawa(KarneBatch batch, CookingSession session) {
    final actualCtrl = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Enter Nagawa'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            Text('Kota: ${session.kota.toStringAsFixed(1)} pcs'),
            const SizedBox(height: 12),
            CupertinoTextField(controller: actualCtrl, placeholder: 'Actual Pcs', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              final val = double.tryParse(actualCtrl.text);
              if (val != null) {
                setState(() {
                  final bIdx = _batches.indexWhere((b) => b.id == batch.id);
                  final sIdx = _batches[bIdx].sessions.indexWhere((s) => s.id == session.id);
                  _batches[bIdx].sessions[sIdx].actualNagawa = val;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDispatchDialog() {
    final qtyCtrl = TextEditingController();
    int destIdx = 0;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Record Dispatch'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              const Text('Source: Main Warehouse', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              CupertinoButton(
                child: Text('To: ${kSampleBranches[destIdx].name}'),
                onPressed: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (_) => Container(
                      height: 250,
                      color: Colors.white,
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (i) => setDialogState(() => destIdx = i),
                        children: kSampleBranches.map((b) => Center(child: Text(b.name))).toList(),
                      ),
                    ),
                  );
                },
              ),
              CupertinoTextField(controller: qtyCtrl, placeholder: 'Qty (KG)', keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            CupertinoDialogAction(
              onPressed: () {
                final q = double.tryParse(qtyCtrl.text);
                if (q != null) {
                  setState(() {
                    _transferLogs.insert(0, StockTransferLog(
                      id: 'tl${_transferLogs.length + 1}',
                      sourceBranchId: 'warehouse',
                      sourceBranchName: 'Main Warehouse',
                      destinationBranchId: kSampleBranches[destIdx].id,
                      destinationBranchName: kSampleBranches[destIdx].fullName,
                      quantityKg: q,
                      dateTime: DateTime.now(),
                    ));
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(title: 'Inventory', trailing: StaffTopActions()),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _section,
                children: const { 0: Text('Warehouse'), 1: Text('Branches'), 2: Text('Dispatch') },
                onValueChanged: (v) => setState(() => _section = v!),
              ),
            ),
            Expanded(
              child: _section == 0 ? _buildWarehouseTab() : (_section == 1 ? _buildBranchesTab() : _buildDispatchLogsTab()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StaffButton(label: 'Start New Batch', icon: CupertinoIcons.add, onPressed: _showAddBatchDialog),
        const SizedBox(height: 20),
        for (final batch in _batches) ...[
          _buildBatchCard(batch),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildBatchCard(KarneBatch batch) {
    return StaffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${batch.remainingKilos.toStringAsFixed(1)} KG LEFT', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          for (final s in batch.sessions) ...[
            _buildSessionRow(batch, s),
            const SizedBox(height: 8),
          ],
          if (batch.remainingKilos > 0)
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('+ New Luto'),
              onPressed: () => _showNewSessionDialog(batch),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionRow(KarneBatch batch, CookingSession s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.date.month}/${s.date.day} - ${s.kilosToCook}kg', style: const TextStyle(fontSize: 12)),
            Text('Kota: ${s.kota.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
        if (s.actualNagawa == null)
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Text('Enter Actual', style: TextStyle(fontSize: 12)),
            onPressed: () => _enterActualNagawa(batch, s),
          )
        else
          Text('Nagawa: ${s.actualNagawa!.toStringAsFixed(0)} (${s.difference! >= 0 ? '+' : ''}${s.difference!.toStringAsFixed(0)})',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: s.difference! >= 0 ? AppColors.success : AppColors.error)),
      ],
    );
  }

  Widget _buildBranchesTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _branchStocks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final s = _branchStocks[i];
        return StaffCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.branchName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${s.remainingKg} / ${s.allocatedKg} KG', style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDispatchLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: StaffButton(label: 'Record Dispatch', icon: CupertinoIcons.bus, onPressed: _showAddDispatchDialog),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _transferLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final log = _transferLogs[i];
              return StaffCard(
                child: Text('Warehouse -> ${log.destinationBranchName}: ${log.quantityKg}kg'),
              );
            },
          ),
        ),
      ],
    );
  }
}
