import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CutterPortioningScreen extends StatefulWidget {
  const CutterPortioningScreen({super.key});

  @override
  State<CutterPortioningScreen> createState() => _CutterPortioningScreenState();
}

class _CutterPortioningScreenState extends State<CutterPortioningScreen> {
  final Map<String, int> _targets = {
    '250g': 150,
    '300g': 100,
    '400g': 100,
  };

  final Map<String, TextEditingController> _controllers = {
    '250g': TextEditingController(),
    '300g': TextEditingController(),
    '400g': TextEditingController(),
  };

  final _meatLeftController = TextEditingController();
  bool _showSubmitButton = false;

  bool _isRefreshing = false;
  int _tempC = 28;

  @override
  void initState() {
    super.initState();
    _meatLeftController.addListener(_validateInputs);
    for (var controller in _controllers.values) {
      controller.addListener(_validateInputs);
    }
  }

  void _validateInputs() {
    bool allFilled = true;
    for (var controller in _controllers.values) {
      if (controller.text.trim().isEmpty) {
        allFilled = false;
        break;
      }
    }
    if (_meatLeftController.text.trim().isEmpty) {
      allFilled = false;
    }

    if (_showSubmitButton != allFilled) {
      setState(() => _showSubmitButton = allFilled);
    }
  }

  void _onFieldChanged(String value) {
    setState(() {}); // Rebuild UI immediately to update card colors
    _validateInputs();
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
    for (var controller in _controllers.values) {
      controller.removeListener(_validateInputs);
      controller.dispose();
    }
    _meatLeftController.removeListener(_validateInputs);
    _meatLeftController.dispose();
    super.dispose();
  }

  void _submitPortions() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Submit Report'),
        content: const Text('Sigurado ka bang tama ang lahat ng portion counts at inventory report?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted to Owner!')),
              );
              setState(() {
                for (var controller in _controllers.values) {
                  controller.clear();
                }
                _meatLeftController.clear();
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
                  Text(
                    AuthService.currentUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
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
            const StaffSectionHeader(
              label: 'Meat Portioning',
              icon: CupertinoIcons.scissors_alt,
              large: true,
              subtitle: 'Enter final counts per size',
            ),
            const SizedBox(height: 14),
            _buildPortionInputCard('250g'),
            const SizedBox(height: 12),
            _buildPortionInputCard('300g'),
            const SizedBox(height: 12),
            _buildPortionInputCard('400g'),
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Half-Cooked Meat',
              icon: CupertinoIcons.cube_box_fill,
              large: true,
              subtitle: 'Weight after portioning',
            ),
            const SizedBox(height: 14),
            StaffCard(
              padding: const EdgeInsets.all(20),
              highlighted: _meatLeftController.text.trim().isNotEmpty,
              borderColor: _meatLeftController.text.trim().isNotEmpty ? AppColors.accent : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REMAINING WEIGHT (KG)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _meatLeftController,
                    placeholder: '0.0',
                    onChanged: _onFieldChanged,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!_showSubmitButton)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Note: Pakilagay ang input sa lahat ng fields (Portioning at Remaining Weight) para lumabas ang submit button.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (_showSubmitButton)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: StaffButton(
                  label: 'SUBMIT REPORT',
                  onPressed: _submitPortions,
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
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF4285F4), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('Central Kitchen Area',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
              GestureDetector(
                onTap: _refreshWeather,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Text('Update',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent)),
                      const SizedBox(width: 4),
                      _isRefreshing
                          ? const CupertinoActivityIndicator(radius: 5)
                          : const Icon(CupertinoIcons.refresh,
                              size: 10, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(CupertinoIcons.cloud_sun_fill,
                  size: 40, color: AppColors.pastelBrown),
              const SizedBox(width: 12),
              Text('$_tempC°C',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                      letterSpacing: -1)),
              const Spacer(),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Partly Cloudy',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('Central Kitchen Area',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortionInputCard(String size) {
    final target = _targets[size] ?? 0;
    final controller = _controllers[size]!;
    int current = int.tryParse(controller.text) ?? 0;
    bool isDone = current >= target;

    return StaffCard(
      padding: const EdgeInsets.all(18),
      highlighted: isDone,
      borderColor: isDone ? AppColors.accent : null, // Green number, brown/accent border
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  size,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target: $target pcs',
                  style: TextStyle(
                    color: isDone ? AppColors.success : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              placeholder: '0',
              onChanged: _onFieldChanged,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: isDone ? AppColors.success : AppColors.accent,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDone
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

