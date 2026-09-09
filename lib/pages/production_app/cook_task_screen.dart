import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  final _kiloController = TextEditingController();
  final List<bool> _checkSteps = [false, false, false];
  bool _showSubmitButton = false;
  
  // Ingredient status: 0 = Good, 1 = Low, 2 = Out
  final Map<String, int> _ingredients = {
    'Toyo (1 Gallon)': 0,
    'Asin (1 Sack)': 0,
    'Paminta (1 Kilo)': 0,
    'Vetsin (1 Kilo)': 0,
    'Laurel (1 Kilo)': 0,
    'Gasul (LPG Tank)': 0,
  };

  bool _isRefreshing = false;
  int _tempC = 28;

  @override
  void initState() {
    super.initState();
    _kiloController.addListener(_onKiloChanged);
  }

  void _onKiloChanged() {
    final hasInput = _kiloController.text.trim().isNotEmpty;
    if (hasInput != _showSubmitButton) {
      setState(() => _showSubmitButton = hasInput);
    }
  }

  void _refreshWeather() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _tempC = 27 + (DateTime.now().second % 3); 
      });
    }
  }

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 18) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  void dispose() {
    _kiloController.removeListener(_onKiloChanged);
    _kiloController.dispose();
    super.dispose();
  }

  void _submitReport() {
    final val = _kiloController.text.trim();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Submit Report'),
        content: Text('Sigurado ka bang tapos na ang lahat at $val kg ang kabuuang naluto?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Daily production report submitted!')),
              );
              setState(() {
                _checkSteps.fillRange(0, 3, false);
                _kiloController.clear();
              });
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
            // GREETING
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greetingPrefix(),
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Menes',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
            ),
            // 0. WEATHER WIDGET
            _weatherWidget(),
            const SizedBox(height: 22),

            // 1. COOKING CHECKLIST
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
                  _buildCheckItem('Cooking Process (140-150kg)', 1),
                  _buildCheckItem('Cleaning & Proper Storage', 2),
                ],
              ),
            ),
            
            const SizedBox(height: 26),

            // 2. INGREDIENT INVENTORY
            const StaffSectionHeader(
              label: 'Ingredient Inventory',
              icon: CupertinoIcons.archivebox_fill,
              large: true,
              subtitle: 'Monitor and report stocks',
            ),
            const SizedBox(height: 14),
            ..._ingredients.keys.map((name) => _buildIngredientRow(name)),
            
            const SizedBox(height: 26),

            // 3. RECORD OUTPUT
            const StaffSectionHeader(
              label: 'Record Output',
              icon: CupertinoIcons.chart_bar_square_fill,
              large: true,
              subtitle: 'Report total kilos produced',
            ),
            const SizedBox(height: 14),
            StaffCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'TOTAL KILOS COOKED',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _kiloController,
                    placeholder: '0.0',
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Standard range: 140 - 150 kg', 
                    textAlign: TextAlign.center, 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  
                  // DYNAMIC SUBMIT BUTTON - Only rendered when there is input
                  if (_showSubmitButton)
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: StaffButton(
                        label: 'SUBMIT REPORT',
                        onPressed: _submitReport,
                      ),
                    ),
                ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('Central Kitchen Area', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
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
              const Icon(CupertinoIcons.cloud_sun_fill, size: 40, color: AppColors.pastelBrown),
              const SizedBox(width: 12),
              Text('$_tempC°C', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: AppColors.textPrimary, letterSpacing: -1)),
              const Spacer(),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Partly Cloudy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('Central Kitchen Area', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

  Widget _buildIngredientRow(String name) {
    final status = _ingredients[name] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StaffCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.archivebox, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
            ),
            StaffButton(
              label: 'Request',
              onPressed: () {}, 
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker(String name) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Status ng $name'),
        actions: [
          CupertinoActionSheetAction(onPressed: () { setState(() => _ingredients[name] = 0); Navigator.pop(context); }, child: const Text('Good Stock')),
          CupertinoActionSheetAction(onPressed: () { setState(() => _ingredients[name] = 1); Navigator.pop(context); }, child: const Text('Low Stock')),
          CupertinoActionSheetAction(onPressed: () { setState(() => _ingredients[name] = 2); Navigator.pop(context); }, isDestructiveAction: true, child: const Text('Out of Stock')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  String _getStatusText(int status) {
    if (status == 0) return 'GOOD';
    if (status == 1) return 'LOW';
    return 'OUT';
  }

  Color _getStatusColor(int status) {
    if (status == 0) return AppColors.success;
    if (status == 1) return AppColors.warning;
    return AppColors.error;
  }
}
