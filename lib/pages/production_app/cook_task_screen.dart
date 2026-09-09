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

  bool _isRefreshing = false;
  int _tempC = 28;

  @override
  void initState() {
    super.initState();
    _kiloController.addListener(_onKiloChanged);
  }

  void _onKiloChanged() {
    final text = _kiloController.text.trim();
    final hasInput = text.isNotEmpty;
    
    // Update local UI state (colors) immediately
    setState(() {});

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
                  _buildCheckItem('Cooking Process (140-150kg)', 1),
                  _buildCheckItem('Cleaning & Proper Storage', 2),
                ],
              ),
            ),
            
            const SizedBox(height: 26),

            // 2. RECORD OUTPUT
            const StaffSectionHeader(
              label: 'Record Output',
              icon: CupertinoIcons.chart_bar_square_fill,
              large: true,
              subtitle: 'Report total kilos produced',
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final double? val = double.tryParse(_kiloController.text.trim());
                final bool isInRange = val != null && val >= 140 && val <= 150;
                
                return StaffCard(
                  padding: const EdgeInsets.all(24),
                  highlighted: isInRange,
                  borderColor: isInRange ? AppColors.accent : null,
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
                        style: TextStyle(
                          fontSize: 42, 
                          fontWeight: FontWeight.w900, 
                          color: isInRange ? AppColors.success : AppColors.accent,
                        ),
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
                      
                      const SizedBox(height: 12),
                      if (!_showSubmitButton)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Note: Pakilagay ang kabuuang kilos na naluto para lumabas ang submit button.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

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
                );
              }
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
}

