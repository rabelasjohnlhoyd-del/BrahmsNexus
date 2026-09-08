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
  final List<bool> _checkSteps = [false, false, false];
  final _outputController = TextEditingController();

  final Map<String, int> _ingredients = {
    'Toyo (1 Gallon)': 0,
    'Asin (1 Sack)': 0,
    'Paminta (1 Kilo)': 0,
    'Vetsin (1 Kilo)': 0,
    'Laurel (1 Kilo)': 0,
    'Gasul (LPG Tank)': 0,
  };

  bool _isRefreshing = false;
  bool _isCelsius = true;

  int _tempC = 28;
  int _humidity = 81;
  double _windSpeed = 12.5;
  int _feelsLikeC = 30;

  void _refreshWeather() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _tempC = 27 + (DateTime.now().second % 3); 
        _humidity = 80 + (DateTime.now().second % 5);
        _windSpeed = 10.0 + (DateTime.now().second % 10);
        _feelsLikeC = _tempC + 2;
      });
    }
  }

  void _toggleUnit() {
    setState(() => _isCelsius = !_isCelsius);
  }

  int _convertTemp(int celsius) {
    return _isCelsius ? celsius : ((celsius * 9 / 5) + 32).round();
  }

  String _formattedTime() {
    final now = DateTime.now();
    final day = _weekdays[now.weekday % 7];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$day $hour:$minute $period';
  }

  static const List<String> _weekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  Widget _weatherWidget() {
    final displayTemp = _convertTemp(_tempC);
    final feelsLike = _convertTemp(_feelsLikeC);
    final unitLabel = _isCelsius ? '°C' : '°F';
    final windUnit = _isCelsius ? 'km/h' : 'mph';
    final displayWind =
        _isCelsius ? _windSpeed : (_windSpeed * 0.621371).roundToDouble();

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
                      color: Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'San Francisco, Victoria',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _refreshWeather,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(CupertinoIcons.cloud_fill,
                  size: 48, color: AppColors.pastelBrown),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _toggleUnit,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$displayTemp',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                          letterSpacing: -2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 2),
                        child: Text(
                          unitLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Cloudy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _formattedTime(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _weatherInfoItem(
                  CupertinoIcons.thermometer, 'Feels like', '$feelsLike$unitLabel'),
              _weatherInfoItem(CupertinoIcons.drop, 'Humidity', '$_humidity%'),
              _weatherInfoItem(CupertinoIcons.wind, 'Wind',
                  '${displayWind.toStringAsFixed(1)} $windUnit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  void _requestStock(String name) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Request Supply'),
        content: Text('Sigurado ka bang kailangan na ng bagong stock ng $name?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Request for $name sent to Owner!')),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _submitOutput() {
    final val = _outputController.text.trim();
    if (val.isEmpty) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Submit Output'),
        content: Text('Sigurado ka bang $val kg ang kabuuang naluto ngayong araw?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Production output recorded!')),
              );
              setState(() => _outputController.clear());
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
        mode: StaffHeaderMode.greeting,
        greetingName: 'Menes',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _weatherWidget(),
            const SizedBox(height: 22),
            const StaffSectionHeader(
              label: "Today's Checklist",
              icon: CupertinoIcons.checkmark_circle_fill,
              subtitle: 'Steps for central kitchen production',
              large: true,
            ),
            const SizedBox(height: 14),
            StaffCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                children: [
                  _buildCheckItem('Preparation of Raw Meat', 0),
                  _buildCheckItem('Cooking Process (140-150kg)', 1),
                  _buildCheckItem('Cleaning & Proper Storage', 2),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Ingredient Status',
              icon: CupertinoIcons.archivebox_fill,
              subtitle: 'Monitor and request supplies',
              large: true,
            ),
            const SizedBox(height: 14),
            ..._ingredients.keys.map((name) => _buildIngredientRow(name)),
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Record Output',
              icon: CupertinoIcons.chart_bar_square_fill,
              subtitle: 'Report total kilos produced',
              large: true,
            ),
            const SizedBox(height: 14),
            StaffCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'TOTAL KILOS COOKED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _outputController,
                    onChanged: (val) => setState(() {}),
                    placeholder: '0.0',
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                      letterSpacing: -1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Standard range: 140 - 150 kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: StaffButton(
                      label: 'SUBMIT',
                      onPressed: _outputController.text.trim().isEmpty 
                        ? null 
                        : _submitOutput,
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

  Widget _buildCheckItem(String label, int index) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => setState(() => _checkSteps[index] = !_checkSteps[index]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _checkSteps[index]
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _checkSteps[index] ? AppColors.success : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: _checkSteps[index]
                  ? const Icon(CupertinoIcons.checkmark_alt,
                      size: 16, color: AppColors.success)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _checkSteps[index]
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  decoration:
                      _checkSteps[index] ? TextDecoration.lineThrough : null,
                  fontSize: 15,
                  fontWeight:
                      _checkSteps[index] ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientRow(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StaffCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.cube_box,
                  size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: () => _requestStock(name),
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              minSize: 0,
              child: const Text(
                'Request',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
