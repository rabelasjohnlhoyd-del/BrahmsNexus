import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';

class ReportExportScreen extends StatefulWidget {
  const ReportExportScreen({super.key});

  @override
  State<ReportExportScreen> createState() => _ReportExportScreenState();
}

class _ReportExportScreenState extends State<ReportExportScreen> {
  String _selectedType = 'Sales';
  DateTimeRange? _dateRange;

  void _export() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exporting Report'),
        content: Text('Generating $_selectedType report for the selected period...'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report exported as CSV successfully.')));
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Export')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Configure and generate data exports.', style: TextStyle(color: AdminWebColors.textSecondary)),
              const SizedBox(height: 24),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report Type', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      items: ['Sales', 'Inventory', 'Payroll', 'Audit Log'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedType = v!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (picked != null) setState(() => _dateRange = picked);
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(_dateRange == null ? 'Select Date Range' : '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download_rounded),
                label: const Text('GENERATE REPORT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
