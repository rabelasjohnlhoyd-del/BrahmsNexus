import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/bilao_order.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_button.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';

/// Full delivery details + take-a-picture flow to confirm the delivery was
/// successful. Uploads the proof photo to Supabase Storage (bilao-proofs bucket)
/// and pops the public URL so the parent can save it to Firestore.
///
/// For Cash COD orders (remaining balance > 0) the driver must confirm
/// collection before submitting.
class BilaoDeliveryDetailScreen extends StatefulWidget {
  const BilaoDeliveryDetailScreen({super.key, required this.order});

  final BilaoOrder order;

  @override
  State<BilaoDeliveryDetailScreen> createState() =>
      _BilaoDeliveryDetailScreenState();
}

class _BilaoDeliveryDetailScreenState
    extends State<BilaoDeliveryDetailScreen> {
  XFile? _photo;
  bool _isSubmitting = false;
  bool _codCollected = false; // Only required when there is a COD balance

  bool get _hasCodBalance =>
      widget.order.remainingBalance > 0 &&
      widget.order.paymentMethod == PaymentMethod.cash;

  bool get _canSubmit =>
      _photo != null && (!_hasCodBalance || _codCollected);

  Future<void> _takePicture() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() => _photo = photo);
      }
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("Can't access the camera"),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _retake() => setState(() => _photo = null);

  Future<void> _confirmSubmit() async {
    if (!_canSubmit) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Are you sure?'),
        content: Text(
          _hasCodBalance
              ? 'Confirm: Na-collect na ang COD na ₱${widget.order.remainingBalance.toStringAsFixed(0)} at matagumpay na naihatid ang order?'
              : 'Confirm this delivery was successful?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    // Upload proof photo to Supabase Storage
    String? proofUrl;
    try {
      final bytes = await _photo!.readAsBytes();
      proofUrl = await SupabaseService.uploadBilaoProofPhoto(
        orderId: widget.order.id,
        proofType: 'delivery',
        bytes: bytes,
      );
    } catch (e) {
      // Non-fatal: if upload fails we still complete the delivery
      debugPrint('Delivery proof upload failed: $e');
    }

    if (!mounted) return;
    // Pop with the URL (or null if upload failed — caller handles gracefully)
    Navigator.of(context).pop(proofUrl);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: DriverNavBar(
        title: order.customerName,
        showBackButton: true,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DriverCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(CupertinoIcons.person_fill, order.customerName),
                    _infoRow(CupertinoIcons.phone_fill, order.contactNumber),
                    _infoRow(
                      order.isBranchPickup
                          ? CupertinoIcons.location_solid
                          : CupertinoIcons.map_fill,
                      order.destinationDisplay,
                    ),
                    if (order.notes != null && order.notes!.isNotEmpty)
                      _infoRow(CupertinoIcons.doc_text_fill,
                          'Note: ${order.notes!}'),
                    _infoRow(
                      CupertinoIcons.bag_fill,
                      '${order.size.label} (${order.size.pax}pax) × ${order.quantity} — '
                      '₱${order.totalAmount.toStringAsFixed(0)}',
                    ),
                    // Payment info row
                    _infoRow(
                      order.paymentMethod == PaymentMethod.gcash
                          ? CupertinoIcons.device_phone_portrait
                          : CupertinoIcons.money_dollar_circle,
                      order.paymentMethod == PaymentMethod.gcash
                          ? 'GCash${order.gcashVerified ? " (Verified)" : ""}'
                              '${order.remainingBalance > 0 ? " — COD: ₱${order.remainingBalance.toStringAsFixed(0)}" : " — Fully Paid"}'
                          : 'Cash${order.remainingBalance > 0 ? " — COD: ₱${order.remainingBalance.toStringAsFixed(0)}" : " — Fully Paid"}',
                    ),
                  ],
                ),
              ),

              // COD Collection confirmation (only for cash orders with remaining balance)
              if (_hasCodBalance) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => _codCollected = !_codCollected),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _codCollected
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _codCollected
                            ? AppColors.success
                            : AppColors.warning,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _codCollected
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          color: _codCollected
                              ? AppColors.success
                              : AppColors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Na-collect ko na ang COD na ₱${order.remainingBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _codCollected
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              Expanded(
                child: _photo == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.camera_fill,
                                size: 56, color: AppColors.pastelBrown),
                            const SizedBox(height: 12),
                            const Text(
                              'Kumuha ng litrato bilang katibayan\nng matagumpay na paghahatid.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            if (_hasCodBalance && !_codCollected) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'I-check muna ang COD collection bago mag-submit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.warning, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_photo!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              if (_photo == null)
                DriverButton(
                  label: 'Kumuha ng Litrato',
                  icon: CupertinoIcons.camera_fill,
                  onPressed: _takePicture,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: DriverButton(
                        label: 'Retake',
                        color: AppColors.pastelBrown,
                        onPressed: _isSubmitting ? null : _retake,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DriverButton(
                        label: _isSubmitting
                            ? 'Uploading...'
                            : (!_canSubmit ? 'I-check ang COD' : 'Submit'),
                        color: _canSubmit
                            ? AppColors.success
                            : AppColors.textSecondary,
                        onPressed: (_isSubmitting || !_canSubmit)
                            ? null
                            : _confirmSubmit,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
