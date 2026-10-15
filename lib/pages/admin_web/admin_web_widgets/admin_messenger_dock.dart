import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/bilao_order.dart';
import '../../../services/gemini_service.dart';
import '../admin_web_colors.dart';
import '../bilao_orders/add_bilao_order_screen.dart';

/// Floating Messenger & Omnichannel Intake Dock for Admin Web.
/// Allows the Owner to quickly access Meta Business Suite / Messenger,
/// paste customer chat messages, or jot down live phone call details,
/// and convert them into structured Bilao orders using Gemini AI.
class AdminMessengerDock extends StatefulWidget {
  final Function(GeminiChatOrderResult parsed)? onOrderParsed;
  final VoidCallback? onNavigateToBilaoOrders;

  const AdminMessengerDock({
    super.key,
    this.onOrderParsed,
    this.onNavigateToBilaoOrders,
  });

  @override
  State<AdminMessengerDock> createState() => _AdminMessengerDockState();
}

class _AdminMessengerDockState extends State<AdminMessengerDock> {
  bool _isOpen = false;
  int _activeTab = 0; // 0 = Messenger Chat, 1 = Phone Call Scratchpad

  final _chatController = TextEditingController();
  final _phoneNotesController = TextEditingController();

  bool _isParsing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _chatController.dispose();
    _phoneNotesController.dispose();
    super.dispose();
  }

  static const String brahmsPageId = '1305072772697631';
  static const String brahmsProfileId = '61595555061317';
  static const String brahmsPageUrl = 'https://www.facebook.com/profile.php?id=$brahmsProfileId';
  static const String brahmsInboxUrl = 'https://business.facebook.com/latest/inbox/all?asset_id=$brahmsPageId';
  static const String brahmsMessengerUrl = 'https://m.me/$brahmsPageId';

  Future<void> _openMetaBusinessSuite() async {
    final uri = Uri.parse(brahmsInboxUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final fallback = Uri.parse(brahmsMessengerUrl);
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to open Meta Business Suite: $e');
    }
  }

  Future<void> _openBrahmsPage() async {
    final uri = Uri.parse(brahmsPageUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open Brahms Facebook Page: $e');
    }
  }

  void _insertQuickChip(String text) {
    final current = _phoneNotesController.text;
    if (current.isEmpty) {
      _phoneNotesController.text = text;
    } else {
      _phoneNotesController.text = '$current\n• $text';
    }
  }

  Future<void> _handleParseAndCreateOrder({required bool isPhoneCall}) async {
    final rawText = isPhoneCall
        ? _phoneNotesController.text.trim()
        : _chatController.text.trim();

    if (rawText.isEmpty) {
      setState(() {
        _errorMessage = isPhoneCall
            ? 'Paki-type muna ang notes ng tawag ng customer.'
            : 'Paki-paste muna ang chat mula sa Messenger.';
      });
      return;
    }

    setState(() {
      _isParsing = true;
      _errorMessage = null;
    });

    try {
      final result = await GeminiService.parseChatOrder(rawText);

      if (!mounted) return;

      setState(() {
        _isParsing = false;
        _isOpen = false;
        if (isPhoneCall) {
          _phoneNotesController.clear();
        } else {
          _chatController.clear();
        }
      });

      // If caller passed callback, use it; otherwise push AddBilaoOrderScreen
      if (widget.onOrderParsed != null) {
        widget.onOrderParsed!(result);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => AddBilaoOrderScreen(
              initialParsedResult: result,
              initialChannel: isPhoneCall
                  ? BilaoOrderChannel.directToOwner
                  : BilaoOrderChannel.directToOwner,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _errorMessage = 'Error sa pagsuri ng order: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Popover Window
            if (_isOpen) ...[
              _buildDockWindow(),
              const SizedBox(height: 12),
            ],

            // Floating Messenger / Omnichannel Action Button
            _buildFloatingTrigger(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingTrigger() {
    return Tooltip(
      message: _isOpen
          ? 'I-close ang Messenger Dock'
          : 'Messenger & Phone Orders Dock (Omnichannel Intake)',
      child: InkWell(
        onTap: () {
          setState(() {
            _isOpen = !_isOpen;
            _errorMessage = null;
          });
        },
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF00B2FE), // Messenger Light Blue
                Color(0xFF006AFF), // Messenger Primary Blue
                Color(0xFF9B51E0), // Messenger Purple Accent
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF006AFF).withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: _isOpen ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: Icon(
                _isOpen ? Icons.close_rounded : Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockWindow() {
    return Container(
      width: 400,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminWebColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Dock Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF006AFF),
                    Color(0xFF7B2CBF),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct-to-Owner Intake',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Messenger & Phone Calls (AI Powered)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Button to open Brahms Facebook Page
                  Tooltip(
                    message: 'Buksan ang Brahms Facebook Page',
                    child: InkWell(
                      onTap: _openBrahmsPage,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Page',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Button to open Meta Business Suite Inbox in browser
                  Tooltip(
                    message: 'Buksan ang Meta Business Suite Inbox ng Brahms',
                    child: InkWell(
                      onTap: _openMetaBusinessSuite,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mark_chat_unread_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'FB Inbox',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    onPressed: () => setState(() => _isOpen = false),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: AdminWebColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _tabButton(
                      label: '💬 Messenger Chat',
                      isSelected: _activeTab == 0,
                      onTap: () => setState(() {
                        _activeTab = 0;
                        _errorMessage = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tabButton(
                      label: '📞 Phone Call Scratchpad',
                      isSelected: _activeTab == 1,
                      onTap: () => setState(() {
                        _activeTab = 1;
                        _errorMessage = null;
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_activeTab == 0) ...[
                    // Messenger Mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'I-paste ang Mensahe mula sa FB:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            _chatController.text =
                                'Hi po! Pa-order po ng 1 Large bilao para bukas ng 3:30pm pick up sa Imus branch. Customer: Maria Santos 09171234567. Paki-hiwalay po ang sili at paborito namin medyo crispy. Mag-GCash po ako.';
                          },
                          child: const Text(
                            'Subukan ang Sample',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AdminWebColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _chatController,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText:
                            'I-copy paste dito ang usapan sa Messenger...',
                        hintStyle: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: AdminWebColors.border),
                        ),
                        filled: true,
                        fillColor: AdminWebColors.background,
                      ),
                    ),
                  ] else ...[
                    // Phone Call Mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mabilisang Tala habang Kausap sa Phone:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            _phoneNotesController.text =
                                'Tawag mula kay Tito Roger 09189876543\nOrder: 2 Medium Bilao\nPickup: Labuin branch bukas 5pm\nPayment: Ise-send daw GCash screenshot sa Messenger mamaya';
                          },
                          child: const Text(
                            'Sample Phone Call',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AdminWebColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneNotesController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText:
                            'Hal: "Tawag si Anna 0917..., 1 Small bilao pickup bukas 2pm sa Gatid..."',
                        hintStyle: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: AdminWebColors.border),
                        ),
                        filled: true,
                        fillColor: AdminWebColors.background,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick tag chips for phone call notes
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip(
                            '🔒 GCash to follow via Messenger',
                            onTap: () => _insertQuickChip(
                                'Payment: GCash isesend mamaya sa Messenger (Pending Payment / Kitchen Locked)'),
                          ),
                          const SizedBox(width: 6),
                          _chip(
                            '🌶️ Hiwalay Sili',
                            onTap: () => _insertQuickChip('Paki-hiwalay ang sili'),
                          ),
                          const SizedBox(width: 6),
                          _chip(
                            '💵 Cash sa Branch',
                            onTap: () =>
                                _insertQuickChip('Payment: Cash upon branch pickup'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminWebColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AdminWebColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 14, color: AdminWebColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminWebColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Submit AI Extraction Button
                  ElevatedButton(
                    onPressed: _isParsing
                        ? null
                        : () => _handleParseAndCreateOrder(
                              isPhoneCall: _activeTab == 1,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminWebColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isParsing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Sinusuri ng Gemini AI...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                _activeTab == 0
                                    ? 'I-parse sa AI at Gumawa ng Order'
                                    : 'Convert Phone Notes to Order',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AdminWebColors.textPrimary
                  : AdminWebColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AdminWebColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AdminWebColors.accent.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AdminWebColors.accent,
          ),
        ),
      ),
    );
  }
}
