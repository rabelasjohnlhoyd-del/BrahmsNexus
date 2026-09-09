import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

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
        title: Text('Edit Price: ${size.label.toUpperCase()}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PRICE (₱)',
            prefixText: '₱ ',
            labelStyle: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null) {
                setState(() => _prices[size] = newPrice);
              }
              Navigator.pop(context);
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(BilaoPricingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([
      ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pricing defaults updated for current session.')),
          );
        },
        icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
        label: const Text('SAVE GLOBAL DEFAULTS'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          elevation: 0,
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                for (final size in BilaoSize.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          onTap: () => _editPrice(size),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AdminWebColors.accent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, color: AdminWebColors.accent),
                          ),
                          title: Text(
                            '${size.label.toUpperCase()} BILAO',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              color: AdminWebColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Base price for a single unit',
                            style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₱${_prices[size]?.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AdminWebColors.accent,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Icon(Icons.edit_outlined, color: AdminWebColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

