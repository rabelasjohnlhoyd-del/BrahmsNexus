import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/bilao_order.dart';
import '../../../services/gemini_service.dart';
import '../admin_web_colors.dart';
import '../bilao_orders/add_bilao_order_screen.dart';

/// Floating Messenger & Omnichannel Intake Dock for Admin Web.
/// Allows the Owner to quickly access Meta Business Suite / Messenger,
/// paste customer chat messages or order templates, or jot down phone call details,
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
  final _chatController = TextEditingController();

  bool _isParsing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  static const String brahmsPageId = '1305072772697631';
  static const String brahmsProfileId = '61595555061317';
  static const String brahmsPageUrl = 'https://www.facebook.com/profile.php?id=$brahmsProfileId';
  static const String brahmsInboxUrl = 'https://business.facebook.com/latest/inbox/all?asset_id=$brahmsPageId';
  static const String brahmsMessengerUrl = 'https://m.me/$brahmsPageId';

  static const String brahmsOrderTemplate =
      '- Full Name: \n'
      '- Contact Number: \n'
      '- Bilao Size (Small PHP 650 / Medium PHP 900 / Large PHP 1,300): \n'
      '- Quantity: \n'
      '- Pickup Date & Time: \n'
      '- Preferred Branch (Gatid / Labuin / Sta. Clara / Nanhaya / San Francisco / Dayap): \n'
      '- Pickup or Delivery (provide address): ';

  static const String brahmsSampleOrder =
      '- Full Name: Maria Santos\n'
      '- Contact Number: 09171234567\n'
      '- Bilao Size (Small PHP 650 / Medium PHP 900 / Large PHP 1,300): Large PHP 1,300\n'
      '- Quantity: 1\n'
      '- Pickup Date & Time: Bukas ng 3:30 PM\n'
      '- Preferred Branch (Gatid / Labuin / Sta. Clara / Nanhaya / San Francisco / Dayap): Labuin\n'
      '- Pickup or Delivery (provide address): Pickup (Paki-hiwalay ang sili)';

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

  void _copyTemplateToClipboard() {
    Clipboard.setData(const ClipboardData(text: brahmsOrderTemplate));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nai-kopya ang Order Template sa clipboard! Handa nang i-paste sa Messenger.'),
        duration: Duration(seconds: 2),
        backgroundColor: AdminWebColors.accent,
      ),
    );
  }

  void _insertQuickChip(String text) {
    final current = _chatController.text.trim();
    if (current.isEmpty) {
      _chatController.text = text;
    } else {
      _chatController.text = '$current\n• $text';
    }
  }

  Future<void> _handleParseAndCreateOrder() async {
    final rawText = _chatController.text.trim();

    if (rawText.isEmpty) {
      setState(() {
        _errorMessage = 'Paki-paste ang sinagutang template o usapan mula sa Messenger/tawag.';
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
        _chatController.clear();
      });

      // If caller passed callback, use it; otherwise push AddBilaoOrderScreen
      if (widget.onOrderParsed != null) {
        widget.onOrderParsed!(result);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => AddBilaoOrderScreen(
              initialParsedResult: result,
              initialChannel: BilaoOrderChannel.directToOwner,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expandable Intake Card
          if (_isOpen) ...[
            _buildDockCard(),
            const SizedBox(height: 12),
          ],

          // Circular Action Button
          _buildFloatingButton(),
        ],
      ),
    );
  }

  Widget _buildFloatingButton() {
    return Tooltip(
      message: _isOpen
          ? 'Isara ang Intake Dock'
          : 'Buksan ang Messenger & Phone Intake Dock',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isOpen = !_isOpen),
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AdminWebColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AdminWebColors.accent.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isOpen ? Icons.close_rounded : Icons.mark_chat_unread_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockCard() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 410,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: AdminWebColors.accent.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: AdminWebColors.accent,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
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
                          'Messenger, FB Page & Phone (AI Powered)',
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
                  const SizedBox(width: 8),
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

            // Content Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dedicated Template Copy Banner
                  InkWell(
                    onTap: _copyTemplateToClipboard,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F3EE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEBE2D8)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy_rounded, size: 13, color: AdminWebColors.accent),
                          SizedBox(width: 6),
                          Text(
                            'Kopyahin ang Order Template para sa Customer',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AdminWebColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section Title & Sample Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'I-paste ang Template o Usapan:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminWebColors.textPrimary,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _chatController.text = brahmsSampleOrder;
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 12, color: AdminWebColors.accent),
                            SizedBox(width: 4),
                            Text(
                              'Subukan ang Sample',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AdminWebColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Text Area Input
                  TextField(
                    controller: _chatController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText:
                          'I-paste dito ang sinagutang template mula sa Messenger, o i-type ang usapan / tala mula sa tawag...',
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

                  // Quick tag chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(
                          'Hiwalay Sili',
                          onTap: () => _insertQuickChip('Paki-hiwalay ang sili'),
                        ),
                        const SizedBox(width: 6),
                        _chip(
                          'Cash sa Branch',
                          onTap: () => _insertQuickChip('Payment: Cash upon branch pickup'),
                        ),
                        const SizedBox(width: 6),
                        _chip(
                          'GCash to follow via Messenger',
                          onTap: () => _insertQuickChip(
                              'Payment: GCash isesend mamaya sa Messenger (Pending Payment / Kitchen Locked)'),
                        ),
                      ],
                    ),
                  ),

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
                    onPressed: _isParsing ? null : _handleParseAndCreateOrder,
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
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'I-parse sa AI at Gumawa ng Order',
                                style: TextStyle(
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
