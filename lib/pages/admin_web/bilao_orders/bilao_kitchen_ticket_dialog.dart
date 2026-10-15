import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/bilao_order.dart';
import '../admin_web_colors.dart';

/// Clean, high-contrast packaging ticket & kitchen slip modal for Bilao Orders.
/// Designed for thermal receipt printers (58mm/80mm) or paper slip attachment to bilao boxes.
class BilaoKitchenTicketDialog extends StatelessWidget {
  const BilaoKitchenTicketDialog({
    super.key,
    required this.order,
  });

  final BilaoOrder order;

  static void show(BuildContext context, BilaoOrder order) {
    showDialog<void>(
      context: context,
      builder: (_) => BilaoKitchenTicketDialog(order: order),
    );
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('EEE, MMM d, yyyy • h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final schedStr = _formatDateTime(order.scheduledDateTime);
    final isDirectToOwner = order.orderChannel == BilaoOrderChannel.directToOwner;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AdminWebColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kitchen Packaging Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Bilao Box Order Ticket', style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ticket Box
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Center(
                      child: Text(
                        'BRAHMS FOOD VENTURES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Pancit Bilao • Kitchen & Packaging Ticket',
                        style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '------------------------------------------------------------',
                      maxLines: 1,
                      style: TextStyle(color: Color(0xFFCCCCCC), letterSpacing: 2),
                    ),
                    const SizedBox(height: 8),

                    // Order ID & Channel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ORDER: #${order.id.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDirectToOwner ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDirectToOwner ? Colors.green.shade400 : Colors.blue.shade400,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isDirectToOwner ? 'DIRECT TO OWNER' : 'BRANCH ORDER',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isDirectToOwner ? Colors.green.shade800 : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Customer details
                    _ticketRow('CUSTOMER:', order.customerName, isBold: true),
                    _ticketRow('CONTACT:', order.contactNumber),
                    _ticketRow(
                      'FULFILLMENT:',
                      order.isBranchPickup ? 'PICKUP: ${order.destinationDisplay}' : 'DELIVERY: ${order.destinationDisplay}',
                    ),
                    _ticketRow('SCHEDULE:', schedStr, highlight: true),
                    const SizedBox(height: 8),

                    const Text(
                      '------------------------------------------------------------',
                      maxLines: 1,
                      style: TextStyle(color: Color(0xFFCCCCCC), letterSpacing: 2),
                    ),
                    const SizedBox(height: 8),

                    // Package item
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.quantity}x ',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E1E1E)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BILAO ${order.size.label.toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E1E1E)),
                              ),
                              Text(
                                '${order.size.pax} Pax  •  ${order.size.weightLabel}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ],
                    ),

                    // Notes / Special instructions
                    if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SPECIAL INSTRUCTIONS / BILIN:',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFF57F17)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.notes!,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    const Text(
                      '------------------------------------------------------------',
                      maxLines: 1,
                      style: TextStyle(color: Color(0xFFCCCCCC), letterSpacing: 2),
                    ),
                    const SizedBox(height: 8),

                    // Payment summary
                    _ticketRow('TOTAL AMOUNT:', '₱${order.totalAmount.toStringAsFixed(2)}', isBold: true),
                    if (order.paymentMethod == PaymentMethod.gcash) ...[
                      _ticketRow('PAYMENT METHOD:', 'GCash (${order.gcashVerified ? "VERIFIED" : "PENDING"})'),
                      if (order.gcashRefNumber != null) _ticketRow('REF NUMBER:', order.gcashRefNumber!),
                      if (order.depositAmount > 0)
                        _ticketRow('DOWNPAYMENT:', '₱${order.depositAmount.toStringAsFixed(2)}'),
                      _ticketRow(
                        'BALANCE TO COLLECT:',
                        order.remainingBalance <= 0 ? 'PAID IN FULL (₱0.00)' : '₱${order.remainingBalance.toStringAsFixed(2)}',
                        isBold: true,
                        highlight: order.remainingBalance > 0,
                      ),
                    ] else ...[
                      _ticketRow('PAYMENT METHOD:', 'Cash upon Pickup/Delivery'),
                      _ticketRow(
                        'BALANCE TO COLLECT:',
                        '₱${order.remainingBalance.toStringAsFixed(2)}',
                        isBold: true,
                        highlight: true,
                      ),
                    ],

                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '*** Idikit ang ticket na ito sa ibabaw ng bilao box ***',
                        style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            // Copy plain ticket text to clipboard as handy fallback for thermal POS printer apps
            final ticketSummary = '''
=========================================
          BRAHMS FOOD VENTURES
        BILAO SPECIAL ORDER SLIP
=========================================
Order ID:    #${order.id.toUpperCase()}
Source:      ${isDirectToOwner ? 'DIRECT TO OWNER' : 'BRANCH ORDER'}
Customer:    ${order.customerName} (${order.contactNumber})
Schedule:    $schedStr
Item:        ${order.quantity}x Bilao ${order.size.label} (${order.size.pax} Pax)
Destination: ${order.destinationDisplay}
Notes:       ${order.notes ?? 'None'}
-----------------------------------------
Total:       P${order.totalAmount.toStringAsFixed(2)}
Payment:     ${order.paymentMethod.label} (${order.remainingBalance <= 0 ? 'PAID IN FULL' : 'Balance: P${order.remainingBalance.toStringAsFixed(2)}'})
=========================================
''';
            Clipboard.setData(ClipboardData(text: ticketSummary));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📋 Na-copy ang Ticket Text! Handa nang i-print sa POS o idikit sa resibo.'),
                duration: Duration(seconds: 3),
              ),
            );
          },
          icon: const Icon(Icons.copy_all_rounded, size: 16),
          label: const Text('Copy Slip Text'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminWebColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _ticketRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold || highlight ? FontWeight.w800 : FontWeight.w500,
                color: highlight ? const Color(0xFFD32F2F) : const Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
