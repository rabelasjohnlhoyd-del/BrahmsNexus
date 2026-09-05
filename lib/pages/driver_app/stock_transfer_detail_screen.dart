import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/transfer_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_button.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';

/// Take a picture -> Retake/Submit -> "Are you sure?" confirmation ->
/// back to the list with an updated status. Same logic used for Bilao
/// Deliveries (see bilao_deliveries_screen.dart).
class StockTransferDetailScreen extends StatefulWidget {
  const StockTransferDetailScreen({super.key, required this.request});

  final TransferRequest request;

  @override
  State<StockTransferDetailScreen> createState() =>
      _StockTransferDetailScreenState();
}

class _StockTransferDetailScreenState
    extends State<StockTransferDetailScreen> {
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
        content: const Text('Submit this transfer photo?'),
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

    Navigator.of(context).pop(TransferRequestStatus.submitted);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: DriverNavBar(
        title: '${request.type.label} — ${request.branchName}',
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
                    Text(
                      'Item: ${request.type.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${request.suggestedSourceBranchName}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To: ${request.branchName}',
                      style: const TextStyle(color: AppColors.textSecondary),
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
                              'Take a clear photo as proof.',
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
}
