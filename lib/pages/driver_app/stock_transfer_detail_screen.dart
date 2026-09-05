import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/transfer_request.dart';
import '../../theme/app_theme.dart';

/// Take a picture -> Retake/Submit -> "Are you sure?" confirmation ->
/// bumalik sa listahan na may updated status. Parehong logic din ito
/// para sa Bilao Deliveries (see bilao_deliveries_screen.dart).
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
          title: const Text('Hindi ma-access ang camera'),
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
        content: const Text('Isusumite mo na ba itong transfer photo?'),
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
      navigationBar: CupertinoNavigationBar(
        middle: Text('${request.type.label} — ${request.branchName}'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kukunin: ${request.type.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mula sa: ${request.suggestedSourceBranchName}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Papunta sa: ${request.branchName}',
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
                              'Kumuha ng malinaw na litrato bilang patunay.',
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
                CupertinoButton(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _takePicture,
                  child: const Text('Take a Picture'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: AppColors.pastelBrown,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _isSubmitting ? null : _retake,
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _isSubmitting ? null : _confirmSubmit,
                        child: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit',
                        ),
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
