import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/supply_request.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_pagination_bar.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CutterInventoryScreen extends StatefulWidget {
  const CutterInventoryScreen({super.key});

  @override
  State<CutterInventoryScreen> createState() => _CutterInventoryScreenState();
}

class _CutterInventoryScreenState extends State<CutterInventoryScreen> {
  int _currentPage = 0;
  static const int _pageSize = 5;

  final List<String> _packagingItems = [
    'Plastic Labo (1kg)',
    'Plastic Sando Bag (10kg)',
  ];

  StreamSubscription<List<SupplyRequest>>? _requestsSub;
  List<SupplyRequest> _requests = [];
  final Set<String> _pendingSubmissions = {};

  @override
  void initState() {
    super.initState();
    _requestsSub = FirestoreService.watchSupplyRequests().listen((requests) {
      if (mounted) {
        setState(() {
          _requests = requests;
        });
      }
    });
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    super.dispose();
  }

  SupplyRequest? _getLatestRequest(String name) {
    try {
      return _requests.firstWhere((r) => r.itemName.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  void _requestStock(String name) {
    // Anti-spam check
    if (_pendingSubmissions.contains(name)) return;

    final latest = _getLatestRequest(name);
    if (latest != null && latest.isPending) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Kasalukuyang May Pending Request'),
          content: Text('Mayroon nang nakabinbing request para sa $name na naghihintay ng tugon ni Owner. Iwasang mag-spam upang hindi magkadoble ang tala.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Request Supply'),
        content: Text('Sigurado ka bang kailangan na ng bagong stock ng $name? Magpapadala ito ng alert kay Owner.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _pendingSubmissions.add(name));

              final user = AuthService.currentUser;
              final empName = user?.fullName.isNotEmpty == true ? user!.fullName : AuthService.currentUsername;

              final ok = await FirestoreService.createSupplyRequest(
                itemName: name,
                requestedBy: empName,
                requestedById: AuthService.currentUserId,
              );

              if (mounted) {
                setState(() => _pendingSubmissions.remove(name));
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Naipadala na ang request para sa $name kay Owner!' : 'May error. Subukan ulit.'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _packagingItems.length;
    final totalPages = (total / _pageSize).ceil();
    final effectivePage = totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
    final pagedPackaging = _packagingItems.skip(effectivePage * _pageSize).take(_pageSize).toList();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Inventory',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StaffSectionHeader(
              label: 'Packaging Stocks',
              icon: CupertinoIcons.bag_fill,
              large: true,
              subtitle: 'Plastic supplies monitor',
            ),
            const SizedBox(height: 16),
            ...pagedPackaging.map((name) => _buildPackagingRow(name)),
            AppPaginationBar(
              currentPage: effectivePage,
              totalItems: total,
              pageSize: _pageSize,
              onPageChanged: (page) => setState(() => _currentPage = page),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagingRow(String name) {
    final latest = _getLatestRequest(name);
    final isPending = (latest != null && latest.isPending) || _pendingSubmissions.contains(name);
    final hasReply = latest != null && latest.ownerReply != null && latest.ownerReply!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StaffCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.bag,
                      size: 18, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(height: 3),
                        const Row(
                          children: [
                            CupertinoActivityIndicator(radius: 5),
                            SizedBox(width: 6),
                            Text(
                              'Naghihintay ng tugon mula kay Owner...',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StaffButton(
                  label: isPending ? 'Pending' : 'Request',
                  onPressed: isPending ? () => _requestStock(name) : () => _requestStock(name),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ],
            ),
            if (hasReply) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(CupertinoIcons.reply, size: 12, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text(
                          'TUGON NI OWNER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest.ownerReply!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


