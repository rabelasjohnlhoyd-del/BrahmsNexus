import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
import '../admin_web_colors.dart';

class BilaoPricingScreen extends StatefulWidget {
  const BilaoPricingScreen({super.key});

  @override
  State<BilaoPricingScreen> createState() => _BilaoPricingScreenState();
}

class _BilaoPricingScreenState extends State<BilaoPricingScreen> {
  // In-memory mock prices based on enum defaults
  final Map<BilaoSize, double> _prices = {
    BilaoSize.small: 750.0,
    BilaoSize.medium: 950.0,
    BilaoSize.large: 1300.0,
  };

  void _editPrice(BilaoSize size) {
    final controller = TextEditingController(text: _prices[size]?.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price: ${size.label}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Price (₱)', prefixText: '₱ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null) {
                setState(() => _prices[size] = newPrice);
              }
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bilao Pricing Management')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Configure base prices for bilao packages.',
                style: TextStyle(color: AdminWebColors.textSecondary),
              ),
              const SizedBox(height: 24),
              for (final size in BilaoSize.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AdminWebColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: AdminWebColors.accent),
                      ),
                      title: Text('${size.label} Bilao', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Base price for a single unit'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₱${_prices[size]?.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminWebColors.accent)),
                          const SizedBox(width: 12),
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editPrice(size)),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pricing defaults updated for current session.')),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Global Defaults'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
