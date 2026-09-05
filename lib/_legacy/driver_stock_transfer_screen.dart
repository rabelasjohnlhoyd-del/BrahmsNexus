import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Requests sent by the Owner telling the Driver which branch needs
/// meat, or whether a stop for gas (LPG) is needed. Driver marks each
/// as done once completed — maps conceptually to [StockTransferLog]
/// once wired to the backend.
class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

enum _TransferKind { meat, gas }

class _TransferTask {
  _TransferTask({
    required this.branch,
    required this.kind,
    required this.detail,
    this.isDone = false,
  });
  final String branch;
  final _TransferKind kind;
  final String detail;
  bool isDone;
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final List<_TransferTask> _tasks = [
    _TransferTask(
      branch: 'Pila',
      kind: _TransferKind.meat,
      detail: 'Kailangan ng dagdag na 5kg meat mula sa Sta. Cruz',
    ),
    _TransferTask(
      branch: 'Labuin',
      kind: _TransferKind.gas,
      detail: 'Ubos na ang gasul — magpalit ng tangke',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Transfer')),
      body: SafeArea(
        child: _tasks.isEmpty
            ? const Center(
                child: Text(
                  'Walang stock transfer task sa ngayon.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final icon = task.kind == _TransferKind.meat
                      ? Icons.set_meal_rounded
                      : Icons.local_fire_department_rounded;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.pastelBrown.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: AppColors.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.branch,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  task.detail,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: task.isDone,
                            activeColor: AppColors.success,
                            onChanged: (value) {
                              setState(() => task.isDone = value ?? false);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
