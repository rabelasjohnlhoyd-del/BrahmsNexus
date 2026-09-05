import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Mock RFID attendance UI — walang ESP32 hardware pa hanggang sa
/// workshop (Sept 19). "Simulate Tap" lang ang ginagawa dito para ma-
/// preview ang buong flow. Kapag dumating na ang ESP32 kit, papalitan
/// ito ng aktwal na RFID read (Bluetooth/serial mula sa ESP32) na
/// mag-tatawag ng parehong _markAttendance logic.
class AttendanceScanScreen extends StatefulWidget {
  const AttendanceScanScreen({super.key});

  @override
  State<AttendanceScanScreen> createState() => _AttendanceScanScreenState();
}

class _StaffPickup {
  _StaffPickup({required this.name, required this.branch});
  final String name;
  final String branch;
  DateTime? scannedAt;
}

class _AttendanceScanScreenState extends State<AttendanceScanScreen> {
  final List<_StaffPickup> _pickups = [
    _StaffPickup(name: 'Juan Dela Cruz', branch: 'Sta. Cruz'),
    _StaffPickup(name: 'Maria Reyes', branch: 'Pila'),
    _StaffPickup(name: 'Pedro Santos', branch: 'Labuin'),
  ];

  void _markAttendance(_StaffPickup pickup) {
    setState(() => pickup.scannedAt = DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${pickup.name} — attendance recorded')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.pastelBrown.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.textSecondary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mock RFID tap muna — ESP32 kit pa hanggang Sept 19.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _pickups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final pickup = _pickups[index];
                  final isScanned = pickup.scannedAt != null;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isScanned
                            ? AppColors.success
                            : AppColors.pastelBrown,
                        child: Icon(
                          isScanned
                              ? Icons.check_rounded
                              : Icons.person_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(pickup.name),
                      subtitle: Text(pickup.branch),
                      trailing: isScanned
                          ? Text(
                              '${pickup.scannedAt!.hour.toString().padLeft(2, '0')}:'
                              '${pickup.scannedAt!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _markAttendance(pickup),
                              icon: const Icon(Icons.contactless_rounded,
                                  size: 18),
                              label: const Text('Simulate Tap'),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
