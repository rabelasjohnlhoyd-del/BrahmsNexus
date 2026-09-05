import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/bilao_order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_button.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';

/// Full delivery details + take-a-picture flow (same logic as
/// StockTransferDetailScreen) to confirm the delivery was successful.
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

  void _retake() {
    setState(() => _photo = null);
  }

  Future<void> _confirmSubmit() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Confirm this delivery was successful?'),
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
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.of(context).pop(true);
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
                      CupertinoIcons.location_solid,
                      order.deliveryAddress.isEmpty
                          ? 'No address on file'
                          : order.deliveryAddress,
                    ),
                    _infoRow(
                      CupertinoIcons.bag_fill,
                      '${order.size.label} × ${order.quantity} — '
                      '₱${order.totalAmount.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                              'Take a photo as proof of successful '
                              'delivery.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_photo!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              if (_photo == null)
                DriverButton(
                  label: 'Take a Picture',
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
                        label: _isSubmitting ? 'Submitting...' : 'Submit',
                        color: AppColors.success,
                        onPressed: _isSubmitting ? null : _confirmSubmit,
                      ),
                    ),
                  ],
                ),
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
            child: Text(text, style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
