import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    '250g': TextEditingController(text: '0'),
    '300g': TextEditingController(text: '0'),
    '400g': TextEditingController(text: '0'),
  };

  final _meatLeftController = TextEditingController();
  
  final List<String> _packagingItems = [
    'Plastic Labo (1kg)',
    'Plastic Sando Bag (10kg)',
  ];

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
        Icon(icon, size: 14, color: AppColors.accent.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _meatLeftController.dispose();
    super.dispose();
  }

  void _submitPortions() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Submit Portions'),
        content: const Text('Sigurado ka bang tama ang lahat ng portion counts na nilagay mo?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Portioning report submitted to Owner!')),
              );
              setState(() {
                for (var controller in _controllers.values) {
                  controller.text = '0';
                }
              });
            },
            child: const Text('Submit'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Home',
        mode: StaffHeaderMode.greeting,
        greetingName: 'Abby',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Packaging Stocks',
              icon: CupertinoIcons.bag_fill,
              large: true,
              subtitle: 'Plastic supplies monitor',
            ),
            const SizedBox(height: 14),
            ..._packagingItems.map((name) => _buildPackagingRow(name)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: StaffButton(
                label: 'SUBMIT',
                onPressed: _submitPortions,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
      borderColor: isDone ? AppColors.success : null,
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
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: isDone ? AppColors.success : AppColors.accent,
              ),
              onChanged: (val) => setState(() {}),
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

  Widget _buildPackagingRow(String name) {
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
              child: const Icon(CupertinoIcons.bag,
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
