import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/bilao_order.dart';
import '../../../models/branch.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../services/firestore_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/rate_limiter.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';

class AddBilaoOrderScreen extends StatefulWidget {
  final GeminiChatOrderResult? initialParsedResult;
  final BilaoOrderChannel? initialChannel;
  final bool initialAwaitingGcashProof;

  const AddBilaoOrderScreen({
    super.key,
    this.initialParsedResult,
    this.initialChannel,
    this.initialAwaitingGcashProof = false,
  });

  @override
  State<AddBilaoOrderScreen> createState() => _AddBilaoOrderScreenState();
}

class _AddBilaoOrderScreenState extends State<AddBilaoOrderScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _formKey               = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _contactController     = TextEditingController();
  final _notesController       = TextEditingController();
  final _quantityController    = TextEditingController(text: '1');
  final _depositController     = TextEditingController();
  final _gcashRefController    = TextEditingController();
  final _gcashAmountController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  final BilaoFulfillmentType _fulfillmentType = BilaoFulfillmentType.branchPickup;
  BilaoOrderChannel    _orderChannel   = BilaoOrderChannel.directToOwner;
  PaymentMethod        _paymentMethod  = PaymentMethod.cash;
  PaymentType          _paymentType    = PaymentType.fullPayment;
  String               _selectedBranchId =
      kSampleBranches.isNotEmpty ? kSampleBranches.first.id : 'br1';
  BilaoSize            _selectedSize   = BilaoSize.medium;
  DateTime             _scheduledDateTime =
      DateTime.now().add(const Duration(hours: 2));
  bool                 _isSaving       = false;
  bool                 _awaitingGcashProof = false;

  StreamSubscription<List<BranchMeatStock>>? _stocksSub;
  List<BranchMeatStock> _allStocks = [];
  final List<Branch> _branches = List.from(kSampleBranches);

  bool get _isSelectedBranchClosed =>
      _allStocks.any((s) => s.branchId == _selectedBranchId && s.isClosed);

  // ── GCash Proof & Forensics ────────────────────────────────────────────────
  Uint8List? _gcashBytes;
  String?    _gcashFileName;
  bool       _isOcrLoading           = false;
  String     _ocrError               = '';
  bool       _isOcrAuthentic         = true;
  String     _ocrAuthenticityWarning = '';
  String?    _ocrTransactionDate;

  // ── Computed ───────────────────────────────────────────────────────────────
  int get _qty => int.tryParse(_quantityController.text.trim()) ?? 1;
  double get _totalPrice => _selectedSize.price * (_qty > 0 ? _qty : 1);
  double get _minDeposit => _totalPrice * 0.65;

  String _peso(double v) => '\u20b1${v.toStringAsFixed(0)}';

  Branch get _selectedBranch => kSampleBranches.firstWhere(
        (b) => b.id == _selectedBranchId,
        orElse: () => kSampleBranches.first,
      );

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _depositController.text = _totalPrice.toStringAsFixed(0);
    if (widget.initialChannel != null) {
      _orderChannel = widget.initialChannel!;
    }
    if (widget.initialAwaitingGcashProof) {
      _paymentMethod = PaymentMethod.gcash;
      _awaitingGcashProof = true;
    }
    if (widget.initialParsedResult != null) {
      _applyParsedResult(widget.initialParsedResult!);
    }
    _stocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) {
        setState(() {
          _allStocks = stocks;
          final currentStock = _allStocks.firstWhere(
            (s) => s.branchId == _selectedBranchId,
            orElse: () => BranchMeatStock.defaultForBranch(_selectedBranch),
          );
          if (currentStock.isClosed) {
            final firstOpen = _branches.firstWhere(
              (b) => !(_allStocks.firstWhere(
                (st) => st.branchId == b.id,
                orElse: () => BranchMeatStock.defaultForBranch(b),
              ).isClosed),
              orElse: () => _branches.first,
            );
            _selectedBranchId = firstOpen.id;
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateShellActions());
  }

  void _applyParsedResult(GeminiChatOrderResult result) {
    if (result.customerName.isNotEmpty) {
      _nameController.text = result.customerName;
    } else if (_nameController.text.isEmpty) {
      _nameController.text = 'FB Customer';
    }

    if (result.contactNumber.isNotEmpty) {
      _contactController.text = result.contactNumber;
    } else if (_contactController.text.isEmpty) {
      _contactController.text = '09000000000';
    }

    if (result.quantity > 0) {
      _quantityController.text = result.quantity.toString();
    }
    final lowerSize = result.bilaoSize.toLowerCase();
    if (lowerSize.contains('small')) {
      _selectedSize = BilaoSize.small;
    } else if (lowerSize.contains('large')) {
      _selectedSize = BilaoSize.large;
    } else {
      _selectedSize = BilaoSize.medium;
    }
    _refreshDeposit();

    if (result.pickupBranchId.isNotEmpty) {
      _selectedBranchId = result.pickupBranchId;
    }
    try {
      if (result.pickupDate != null && result.pickupDate!.isNotEmpty) {
        final parts = result.pickupDate!.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          int hour = 14;
          int minute = 0;
          if (result.pickupTime != null && result.pickupTime!.contains(':')) {
            final timeParts = result.pickupTime!.split(':');
            hour = int.parse(timeParts[0]);
            minute = int.parse(timeParts[1]);
          }
          _scheduledDateTime = DateTime(year, month, day, hour, minute);
        }
      }
    } catch (_) {}

    // Default to GCash To-Follow sa Messenger for omnichannel direct-to-owner chat intakes
    _paymentMethod = PaymentMethod.gcash;
    _awaitingGcashProof = true;

    if (result.specialInstructions.isNotEmpty) {
      _notesController.text = result.specialInstructions;
    }
    _orderChannel = BilaoOrderChannel.directToOwner;
  }

  @override
  void dispose() {
    _stocksSub?.cancel();
    _nameController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    _depositController.dispose();
    _gcashRefController.dispose();
    _gcashAmountController.dispose();
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle(null);
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('RECORD NEW BILAO ORDER');
    shell?.setActions([]);
  }

  // ── Payment helpers ────────────────────────────────────────────────────────
  void _onSelectPaymentType(PaymentType type) {
    setState(() {
      _paymentType = type;
      _depositController.text = type == PaymentType.fullPayment
          ? _totalPrice.toStringAsFixed(0)
          : _minDeposit.toStringAsFixed(0);
    });
  }

  void _refreshDeposit() {
    if (_paymentType == PaymentType.fullPayment) {
      _depositController.text = _totalPrice.toStringAsFixed(0);
    } else {
      _depositController.text = _minDeposit.toStringAsFixed(0);
    }
  }

  // ── GCash Screenshot & OCR ─────────────────────────────────────────────────
  Future<void> _pickGcashScreenshot() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _gcashBytes = bytes;
        _gcashFileName = picked.name;
        _isOcrLoading = true;
        _ocrError = '';
        _ocrAuthenticityWarning = '';
      });

      final result = await GeminiService.extractGcashReceipt(imageBytes: bytes);

      if (!mounted) return;
      setState(() {
        _isOcrLoading = false;
        if (result.success) {
          if (result.refNumber.isNotEmpty) {
            _gcashRefController.text = result.refNumber;
          }
          if (result.amount > 0) {
            _gcashAmountController.text = result.amount.toStringAsFixed(2);
          }
          _isOcrAuthentic = result.isAuthentic;
          _ocrAuthenticityWarning = result.authenticityWarning;
          _ocrTransactionDate = result.transactionDateTime;
        } else {
          _ocrError = result.errorMessage.isNotEmpty
              ? result.errorMessage
              : 'Unable to scan GCash screenshot.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOcrLoading = false;
          _ocrError = 'Failed to load image: $e';
        });
      }
    }
  }

  void _clearGcashScreenshot() {
    setState(() {
      _gcashBytes = null;
      _gcashFileName = null;
      _isOcrLoading = false;
      _ocrError = '';
      _isOcrAuthentic = true;
      _ocrAuthenticityWarning = '';
      _ocrTransactionDate = null;
    });
  }

  // ── Smart Chat Intake Dialog (AI) ──────────────────────────────────────────
  void _showSmartChatPasteDialog() {
    final chatInputController = TextEditingController();
    bool isParsing = false;
    String? parseError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AdminWebColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Chat Intake (AI)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('Paste customer Messenger message', style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy the message from Facebook Messenger or SMS and paste it below. Gemini AI will automatically extract customer details, size, and schedule.',
                  style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: chatInputController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'e.g. "Hi po, order ako bilao medium para bukas 3pm pick up sa Imus branch. Maria Clara 09171234567, paki-hiwalay sili."',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: AdminWebColors.background,
                  ),
                ),
                if (isParsing) ...[
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AdminWebColors.accent)),
                      SizedBox(width: 10),
                      Text('Gemini AI is analyzing customer chat...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.accent)),
                    ],
                  ),
                ],
                if (parseError != null) ...[
                  const SizedBox(height: 10),
                  Text(parseError!, style: const TextStyle(fontSize: 12, color: AdminWebColors.error, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isParsing ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isParsing
                  ? null
                  : () async {
                      final text = chatInputController.text.trim();
                      if (text.isEmpty) {
                        setModalState(() => parseError = 'Please paste a customer message first.');
                        return;
                      }
                      setModalState(() {
                        isParsing = true;
                        parseError = null;
                      });

                      final result = await GeminiService.parseChatOrder(text);
                      if (!dialogCtx.mounted) return;

                      if (result.success) {
                        Navigator.pop(dialogCtx);
                        setState(() {
                          if (result.customerName.isNotEmpty) {
                            _nameController.text = result.customerName;
                          }
                          if (result.contactNumber.isNotEmpty) {
                            _contactController.text = result.contactNumber;
                          }
                          if (result.quantity > 0) {
                            _quantityController.text = result.quantity.toString();
                          }
                          final lowerSize = result.bilaoSize.toLowerCase();
                          if (lowerSize.contains('small')) {
                            _selectedSize = BilaoSize.small;
                          } else if (lowerSize.contains('large')) {
                            _selectedSize = BilaoSize.large;
                          } else {
                            _selectedSize = BilaoSize.medium;
                          }
                          _refreshDeposit();

                          if (result.pickupBranchId.isNotEmpty) {
                            _selectedBranchId = result.pickupBranchId;
                          }
                          try {
                            if (result.pickupDate != null && result.pickupDate!.isNotEmpty) {
                              final parts = result.pickupDate!.split('-');
                              if (parts.length == 3) {
                                final year = int.parse(parts[0]);
                                final month = int.parse(parts[1]);
                                final day = int.parse(parts[2]);
                                int hour = 14;
                                int minute = 0;
                                if (result.pickupTime != null && result.pickupTime!.contains(':')) {
                                  final timeParts = result.pickupTime!.split(':');
                                  hour = int.parse(timeParts[0]);
                                  minute = int.parse(timeParts[1]);
                                }
                                _scheduledDateTime = DateTime(year, month, day, hour, minute);
                              }
                            }
                          } catch (_) {}
                          if (result.specialInstructions.isNotEmpty) {
                            _notesController.text = result.specialInstructions;
                          }
                          _orderChannel = BilaoOrderChannel.directToOwner;
                        });
                        _showSnack('Success! Order details populated from chat.');
                      } else {
                        setModalState(() {
                          isParsing = false;
                          parseError = result.errorMessage;
                        });
                      }
                    },
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Analyze & Auto-Fill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SnackBar Feedback ──────────────────────────────────────────────────────
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminWebColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Submission Handler ─────────────────────────────────────────────────────
  void _submitDirectOrder() {
    if (_isSelectedBranchClosed) {
      _showSnack('Hindi maaaring mag-order: Sarado ang napiling branch sa Branch Allocation. Pumili ng bukas na branch.');
      return;
    }

    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();

    if (name.isEmpty) {
      _showSnack('Customer name is required.');
      return;
    }
    if (name.length < 2) {
      _showSnack('Customer name must be at least 2 characters.');
      return;
    }
    if (name.length > 60) {
      _showSnack('Customer name must not exceed 60 characters.');
      return;
    }
    if (!RegExp(r"^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-'.]+$").hasMatch(name)) {
      _showSnack('Customer name must only contain letters.');
      return;
    }

    if (contact.isEmpty) {
      _showSnack('Customer contact number is required.');
      return;
    }
    final digits = contact.replaceAll(RegExp(r'\D'), '');
    final isPhMobile = RegExp(r'^(09\d{9}|639\d{9})$').hasMatch(digits);
    if (!isPhMobile) {
      _showSnack('Enter a valid Philippine mobile number (e.g. 09171234567).');
      return;
    }

    if (_qty <= 0) {
      _showSnack('Quantity must be at least 1.');
      return;
    }
    if (_qty > 10) {
      _showSnack('Quantity cannot exceed 10 bilaos per order.');
      return;
    }

    final entered = double.tryParse(_depositController.text.trim()) ?? 0.0;
    if (entered <= 0) {
      _showSnack('Please enter a valid deposit or payment amount.');
      return;
    }
    if (_paymentType == PaymentType.downPayment) {
      if (entered < _minDeposit - 0.01) {
        _showSnack('Minimum downpayment is 65% of total (${_peso(_minDeposit)}).');
        return;
      }
      if (entered > _totalPrice) {
        _showSnack('Downpayment cannot exceed total amount (${_peso(_totalPrice)}).');
        return;
      }
    } else {
      if (entered < _totalPrice - 0.01) {
        _showSnack('Full payment must equal total amount (${_peso(_totalPrice)}).');
        return;
      }
    }

    if (_paymentMethod == PaymentMethod.gcash) {
      if (!_awaitingGcashProof) {
        final ref = _gcashRefController.text.trim();
        if (ref.isEmpty) {
          _showSnack('Please provide the GCash Reference Number or select "To-Follow sa Messenger".');
          return;
        }
        final refDigits = ref.replaceAll(RegExp(r'\D'), '');
        if (refDigits.length < 10 || refDigits.length > 20) {
          _showSnack('Enter a valid GCash Reference Number (10 to 20 digits).');
          return;
        }

        final amountText = _gcashAmountController.text.trim();
        final amount = double.tryParse(amountText);
        if (amountText.isEmpty || amount == null || amount <= 0) {
          _showSnack('Please enter the GCash amount sent.');
          return;
        }
      }
    }

    _handleSave();
  }

  Future<void> _handleSave() async {
    if (!RateLimiter.tryAction(
      key: 'admin_add_bilao_order',
      cooldown: const Duration(seconds: 15),
    )) {
      final secs = RateLimiter.remainingCooldownSeconds('admin_add_bilao_order');
      _showSnack('Please wait $secs second(s) before submitting another order.');
      return;
    }

    if (_paymentMethod == PaymentMethod.gcash && !_awaitingGcashProof) {
      final ref = _gcashRefController.text.trim();
      try {
        final checks = await Future.wait([
          SupabaseService.isGcashRefNumberExists(ref).timeout(
            const Duration(seconds: 4),
            onTimeout: () => false,
          ),
          FirestoreService.isGcashRefNumberExists(ref).timeout(
            const Duration(seconds: 4),
            onTimeout: () => false,
          ),
        ]);
        if (checks[0] || checks[1]) {
          _showSnack('BLOCKED: GCash Reference Number ($ref) already used in another order.');
          return;
        }
      } catch (e) {
        debugPrint('GCash ref duplicate check note: $e');
      }
    }

    setState(() => _isSaving = true);
    BilaoOrder? newOrder;
    try {
      final orderId = 'ord${DateTime.now().millisecondsSinceEpoch}';

      String? gcashProofUrl;
      if (_paymentMethod == PaymentMethod.gcash && _gcashBytes != null) {
        try {
          gcashProofUrl = await SupabaseService.uploadBilaoProofPhoto(
            orderId: orderId,
            proofType: 'gcash',
            bytes: _gcashBytes!,
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          );
        } catch (e) {
          debugPrint('uploadBilaoProofPhoto note: $e');
        }
      }

      final isDirectToOwner = _orderChannel == BilaoOrderChannel.directToOwner;
      final isGcash = _paymentMethod == PaymentMethod.gcash;
      final isGcashVerified = isGcash && !_awaitingGcashProof && isDirectToOwner;

      String? orderNotes = _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null;
      if (isGcash && _awaitingGcashProof) {
        const prefix = '[AWAITING GCASH PROOF - KITCHEN LOCKED]';
        if (orderNotes == null || !orderNotes.contains(prefix)) {
          orderNotes = orderNotes != null ? '$prefix $orderNotes' : prefix;
        }
      }

      newOrder = BilaoOrder(
        id: orderId,
        customerName:      _nameController.text.trim(),
        contactNumber:     _contactController.text.trim(),
        size:              _selectedSize,
        quantity:          _qty,
        scheduledDateTime: _scheduledDateTime,
        fulfillmentType:   _fulfillmentType,
        orderChannel:      _orderChannel,
        pickupBranchId:    _selectedBranch.id,
        pickupBranchName:  _selectedBranch.fullName,
        deliveryAddress:   '',
        notes:             orderNotes,
        depositAmount:     double.tryParse(_depositController.text.trim()) ?? 0.0,
        paymentMethod:     _paymentMethod,
        paymentType:       _paymentType,
        preparationStatus: PreparationStatus.pending,
        gcashRefNumber:    isGcash && _gcashRefController.text.trim().isNotEmpty
                               ? _gcashRefController.text.trim()
                               : null,
        gcashAmount:       isGcash && _gcashAmountController.text.trim().isNotEmpty
                               ? double.tryParse(_gcashAmountController.text.trim())
                               : null,
        gcashProofUrl:     gcashProofUrl,
        gcashVerified:     isGcashVerified,
        gcashVerifiedAt:   isGcashVerified ? DateTime.now() : null,
        gcashVerifiedBy:   isGcashVerified ? 'Owner / Admin' : null,
        createdAt:         DateTime.now(),
      );

      // Save to Supabase & Firestore concurrently with an 8-second safety timeout
      bool savedOk = true;
      try {
        await Future.wait([
          SupabaseService.saveBilaoOrder(newOrder).catchError((e) {
            debugPrint('Supabase save error: $e');
            savedOk = false;
            return false;
          }),
          FirestoreService.createBilaoOrder(newOrder).catchError((e) {
            debugPrint('Firestore save error: $e');
            return null;
          }),
        ]).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('DB save timed out — proceeding with local order object.');
            return [false, null];
          },
        );
      } catch (saveErr) {
        debugPrint('DB save exception: $saveErr');
        savedOk = false;
      }

      if (!mounted) return;

      if (!savedOk) {
        // Still pop with the order so the list shows it immediately.
        // Show a non-blocking warning about partial save.
        _showSnack('Order naitala locally. I-refresh para makita sa database.');
      }

      // Always navigate back with the new order — never leave user on blank screen.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(newOrder);
      }
    } catch (e) {
      if (mounted) _showSnack('Hindi naitala ang order: $e');
      // Still pop so user doesn't get stuck — pass null (or newOrder if built).
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(newOrder);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Choice Card Component ──────────────────────────────────────────────────

  Widget _choiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AdminWebColors.accent.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AdminWebColors.accent : AdminWebColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AdminWebColors.accent
                    : AdminWebColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AdminWebColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AdminWebColors.accent
                          : AdminWebColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminWebColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? AdminWebColors.accent : AdminWebColors.border,
            ),
          ],
        ),
      ),
    );
  }

  // ── Card Header with Number Badge ──────────────────────────────────────────
  Widget _cardHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AdminWebColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AdminWebColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminWebColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ── Step 1: Order Channel ──────────────────────────────────────────────────
  Widget _buildStep1() {
    return _sectionCard(
      children: [
        _cardHeader('1', 'ORDER CHANNEL & PREPARATION'),
        const SizedBox(height: 14),
        _choiceCard(
          title: 'Direct to Owner (Messenger / Phone)',
          subtitle: 'Customer placed order directly with the Owner via social media or phone. Cooked at Commissary.',
          icon: Icons.verified_user_rounded,
          selected: true,
          onTap: () {},
        ),
      ],
    );
  }

  // ── Step 2: Customer & Pickup Outlet ───────────────────────────────────────
  Widget _buildStep2() {
    return _sectionCard(
      children: [
        _cardHeader('2', 'CUSTOMER & PICKUP OUTLET'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth >= 480;
            final nameField = _webField(
              controller: _nameController,
              label: 'Customer Name',
              hint: 'e.g. Maria Clara',
              icon: Icons.person_outline_rounded,
              capitalization: TextCapitalization.words,
              maxLength: 60,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-'.]")),
              ],
            );
            final contactField = _webField(
              controller: _contactController,
              label: 'Contact Number',
              hint: 'e.g. 09171234567',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              maxLength: 13,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\+\-\s]')),
              ],
            );

            return wide
                ? Row(
                    children: [
                      Expanded(child: nameField),
                      const SizedBox(width: 12),
                      Expanded(child: contactField),
                    ],
                  )
                : Column(
                    children: [
                      nameField,
                      const SizedBox(height: 12),
                      contactField,
                    ],
                  );
          },
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.storefront_rounded, size: 16, color: AdminWebColors.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '100% Branch Pickup: All orders are picked up by the customer at their designated branch outlet.',
                  style: TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedBranchId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Target Pickup Branch Outlet',
            isDense: true,
            prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: _branches.map((b) {
            final bStock = _allStocks.firstWhere(
              (st) => st.branchId == b.id,
              orElse: () => BranchMeatStock.defaultForBranch(b),
            );
            final isClosed = bStock.isClosed;
            return DropdownMenuItem<String>(
              value: b.id,
              enabled: !isClosed,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isClosed ? const Color(0xFF94A3B8) : null,
                        fontWeight: isClosed ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                          : const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isClosed
                            ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                            : const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isClosed ? 'CLOSED' : 'OPEN',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: isClosed ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              final bStock = _allStocks.firstWhere(
                (st) => st.branchId == v,
                orElse: () => BranchMeatStock.defaultForBranch(
                  _branches.firstWhere((b) => b.id == v, orElse: () => _branches.first),
                ),
              );
              if (bStock.isClosed) return;
              setState(() => _selectedBranchId = v);
            }
          },
        ),
        if (_isSelectedBranchClosed) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SARADO ANG BRANCH NA ITO NGAYON. Hindi maaaring mag-order dito. Pumili ng bukas na branch outlet para sa pickup.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _webField(
          controller: _notesController,
          label: 'Special Notes / Customer Remarks (Optional)',
          hint: 'e.g. Extra calamansi, separate chili sauce, etc.',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
          maxLength: 200,
        ),
      ],
    );
  }

  // ── Step 3: Bilao Size, Quantity & Schedule ────────────────────────────────
  Widget _buildStep3() {
    return _sectionCard(
      children: [
        _cardHeader('3', 'BILAO SIZE, QUANTITY & SCHEDULE'),
        const SizedBox(height: 14),
        // Size selector
        Row(
          children: BilaoSize.values.map((s) {
            final sel = _selectedSize == s;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedSize = s;
                  _refreshDeposit();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: EdgeInsets.only(
                      right: s != BilaoSize.large ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? AdminWebColors.accent
                        : AdminWebColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? AdminWebColors.accent
                          : AdminWebColors.border,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? Colors.white
                              : AdminWebColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '\u20b1${s.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white70
                              : AdminWebColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Quantity counter & total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AdminWebColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminWebColors.border),
          ),
          child: Row(
            children: [
              const Text(
                'Quantity to Prepare',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const Spacer(),
              _webQtyBtn(Icons.remove_rounded, _qty > 1, () {
                setState(() {
                  _quantityController.text = '${_qty - 1}';
                  _refreshDeposit();
                });
              }),
              Container(
                width: 44,
                alignment: Alignment.center,
                child: Text(
                  '$_qty',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
              ),
              _webQtyBtn(Icons.add_rounded, true, () {
                setState(() {
                  _quantityController.text = '${_qty + 1}';
                  _refreshDeposit();
                });
              }),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _peso(_totalPrice),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AdminWebColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Scheduled Date & Time
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AdminWebColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminWebColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_available_rounded,
                  color: AdminWebColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Pickup Schedule',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AdminWebColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_scheduledDateTime.month}/${_scheduledDateTime.day}/${_scheduledDateTime.year}  at  '
                      '${_scheduledDateTime.hour.toString().padLeft(2, '0')}:${_scheduledDateTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDateTime,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (date == null || !mounted || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay.fromDateTime(_scheduledDateTime),
                  );
                  if (time == null) return;
                  setState(() {
                    _scheduledDateTime = DateTime(
                      date.year, date.month, date.day,
                      time.hour, time.minute,
                    );
                  });
                },
                icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                label: const Text('Change Schedule', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminWebColors.accent,
                  side: BorderSide(color: AdminWebColors.accent.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _webQtyBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AdminWebColors.accent : AdminWebColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AdminWebColors.border),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : AdminWebColors.textSecondary,
        ),
      ),
    );
  }

  // ── Step 4: Payment & Forensics ────────────────────────────────────────────
  Widget _buildStep4() {
    final isFull = _paymentType == PaymentType.fullPayment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          children: [
            _cardHeader('4', 'PAYMENT & SETTLEMENT'),
            const SizedBox(height: 14),

            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AdminWebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth >= 460;
              final cash = _choiceCard(
                title: 'Cash Payment',
                subtitle: 'Pay cash upon pickup at counter',
                icon: Icons.payments_outlined,
                selected: _paymentMethod == PaymentMethod.cash,
                onTap: () => setState(() => _paymentMethod = PaymentMethod.cash),
              );
              final gcash = _choiceCard(
                title: 'GCash Transfer',
                subtitle: 'Online payment with reference #',
                icon: Icons.account_balance_wallet_outlined,
                selected: _paymentMethod == PaymentMethod.gcash,
                onTap: () => setState(() => _paymentMethod = PaymentMethod.gcash),
              );
              return wide
                  ? Row(children: [
                      Expanded(child: cash),
                      const SizedBox(width: 10),
                      Expanded(child: gcash),
                    ])
                  : Column(children: [
                      cash,
                      const SizedBox(height: 8),
                      gcash,
                    ]);
            }),
            const SizedBox(height: 16),

            const Text(
              'Payment Terms',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AdminWebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth >= 460;
              final full = _choiceCard(
                title: 'Full Payment',
                subtitle: '100% upfront — ${_peso(_totalPrice)}',
                icon: Icons.check_circle_outline_rounded,
                selected: _paymentType == PaymentType.fullPayment,
                onTap: () => _onSelectPaymentType(PaymentType.fullPayment),
              );
              final down = _choiceCard(
                title: 'Downpayment',
                subtitle: 'Min. 65% — ${_peso(_minDeposit)} deposit',
                icon: Icons.receipt_long_rounded,
                selected: _paymentType == PaymentType.downPayment,
                onTap: () => _onSelectPaymentType(PaymentType.downPayment),
              );
              return wide
                  ? Row(children: [
                      Expanded(child: full),
                      const SizedBox(width: 10),
                      Expanded(child: down),
                    ])
                  : Column(children: [
                      full,
                      const SizedBox(height: 8),
                      down,
                    ]);
            }),
            const SizedBox(height: 16),

            // Order total banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AdminWebColors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AdminWebColors.accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedSize.label} × $_qty',
                    style: const TextStyle(
                        fontSize: 13, color: AdminWebColors.textSecondary),
                  ),
                  Text(
                    'Total: ${_peso(_totalPrice)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AdminWebColors.accent,
                    ),
                  ),
                ],
              ),
            ),

            if (isFull) ...[
              TextFormField(
                controller: _depositController,
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Full Payment Amount — Fixed',
                  isDense: true,
                  prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                  prefixText: '\u20b1 ',
                  filled: true,
                  fillColor: AdminWebColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AdminWebColors.border),
                  ),
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _depositController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Down Payment Amount (min. 65%)',
                  isDense: true,
                  prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                  prefixText: '\u20b1 ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AdminWebColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Minimum deposit: ${_peso(_minDeposit)} (65% of ${_peso(_totalPrice)})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AdminWebColors.warning,
                ),
              ),
            ],
          ],
        ),

        // GCash Proof & Forensics
        if (_paymentMethod == PaymentMethod.gcash) ...[
          const SizedBox(height: 18),
          _sectionCard(
            children: [
              _cardHeader('G', 'GCASH PROOF & SETTLEMENT CONTROL'),
              const SizedBox(height: 14),

              // Settlement Mode Switcher (Immediate Proof vs Phone Call To-Follow)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AdminWebColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminWebColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _awaitingGcashProof = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_awaitingGcashProof ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_awaitingGcashProof
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 14,
                                    color: !_awaitingGcashProof ? AdminWebColors.accent : AdminWebColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Resibo Hawak Na (Verify Now)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: !_awaitingGcashProof ? FontWeight.w700 : FontWeight.w500,
                                    color: !_awaitingGcashProof ? AdminWebColors.textPrimary : AdminWebColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _awaitingGcashProof = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _awaitingGcashProof ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _awaitingGcashProof
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_clock_rounded,
                                    size: 14,
                                    color: _awaitingGcashProof ? AdminWebColors.warning : AdminWebColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'To-Follow sa Messenger (Kitchen Lock)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _awaitingGcashProof ? FontWeight.w700 : FontWeight.w500,
                                    color: _awaitingGcashProof ? AdminWebColors.warning : AdminWebColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_awaitingGcashProof) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminWebColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminWebColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: AdminWebColors.warning, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FOOLPROOF KITCHEN LOCK ACTIVE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AdminWebColors.warning,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ang order na ito ay ise-save bilang "Pending Payment". HINDI ito sisimulang lutuin ng branch kitchen hangga\'t hindi nabe-verify ang GCash screenshot kapag sinend na ni customer sa Messenger.',
                              style: TextStyle(fontSize: 11, color: AdminWebColors.textPrimary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (_gcashBytes == null)
                  InkWell(
                    onTap: _pickGcashScreenshot,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AdminWebColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AdminWebColors.accent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_upload_outlined,
                              size: 36, color: AdminWebColors.accent),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload GCash Receipt Screenshot',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AdminWebColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PNG or JPG file. Gemini AI scans typography and reference #.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _pickGcashScreenshot,
                            icon: const Icon(Icons.attach_file_rounded, size: 16),
                            label: const Text('Select Screenshot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminWebColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminWebColors.border),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _gcashBytes!,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_outlined,
                                size: 14, color: AdminWebColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              _gcashFileName ?? 'GCash Receipt',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AdminWebColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: _clearGcashScreenshot,
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text('Change Screenshot', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: AdminWebColors.accent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                if (_isOcrLoading) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Analyzing receipt authenticity and details with Gemini AI...',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_ocrError.isNotEmpty && !_isOcrLoading) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminWebColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminWebColors.error.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 15, color: AdminWebColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_ocrError, style: const TextStyle(fontSize: 11, color: AdminWebColors.error)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_gcashBytes != null && !_isOcrLoading && _ocrError.isEmpty && _gcashRefController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  if (!_isOcrAuthentic || _ocrAuthenticityWarning.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminWebColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminWebColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: AdminWebColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Authenticity Warning: $_ocrAuthenticityWarning',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminWebColors.error),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminWebColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminWebColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: AdminWebColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI Verified Authentic GCash Receipt${_ocrTransactionDate != null && _ocrTransactionDate!.isNotEmpty ? ' • $_ocrTransactionDate' : ''}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminWebColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 14),
                LayoutBuilder(builder: (ctx, c) {
                  final wide = c.maxWidth >= 520;
                  final refField = _webField(
                    controller: _gcashRefController,
                    label: 'Reference Number',
                    hint: 'e.g. 1002345678901',
                    icon: Icons.tag_rounded,
                    keyboard: TextInputType.number,
                    maxLength: 20,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  );
                  final amtField = _webField(
                    controller: _gcashAmountController,
                    label: 'GCash Amount (₱)',
                    hint: 'e.g. 900.00',
                    icon: Icons.account_balance_wallet_outlined,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    prefixText: '\u20b1 ',
                    maxLength: 12,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  );
                  return wide
                      ? Row(children: [
                          Expanded(flex: 2, child: refField),
                          const SizedBox(width: 12),
                          Expanded(child: amtField),
                        ])
                      : Column(children: [
                          refField,
                          const SizedBox(height: 10),
                          amtField,
                        ]);
                }),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // ── Submit Card ────────────────────────────────────────────────────────────
  Widget _buildSubmitCard() {
    return _sectionCard(
      children: [
        _cardHeader('5', 'ORDER SUMMARY & SUBMISSION'),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Payable:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminWebColors.textSecondary),
            ),
            Text(
              _peso(_totalPrice),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminWebColors.accent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _paymentType == PaymentType.fullPayment ? 'Full Payment Due:' : 'Min. Downpayment (65%):',
              style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
            Text(
              _paymentType == PaymentType.fullPayment ? _peso(_totalPrice) : _peso(_minDeposit),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || _isSelectedBranchClosed) ? null : _submitDirectOrder,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(
              _isSaving
                  ? 'Saving Order...'
                  : (_isSelectedBranchClosed
                      ? 'Selected Branch is Closed'
                      : 'Confirm & Create Order'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSelectedBranchClosed ? const Color(0xFF94A3B8) : AdminWebColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminWebColors.textSecondary,
              side: const BorderSide(color: AdminWebColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Widget _webField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    int maxLines = 1,
    String? prefixText,
    void Function(String)? onChanged,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      maxLines: maxLines,
      onChanged: onChanged,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      buildCounter: maxLength != null
          ? (_, {required currentLength, maxLength, required isFocused}) => null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        prefixText: prefixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminWebColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  // ── Unified 2-Column Desktop Layout ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminWebColors.background,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AdminWebColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AdminWebColors.textPrimary),
                    tooltip: 'Back to Bilao Orders',
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record New Bilao Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AdminWebColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Direct to Owner Online Intake & In-Store Order Entry',
                        style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showSmartChatPasteDialog,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Smart Paste Chat (AI)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminWebColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            // Main Body: 2-Column Responsive Layout
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        return isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT COLUMN: Order Details (Flex 3)
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildStep1(),
                                        const SizedBox(height: 18),
                                        _buildStep2(),
                                        const SizedBox(height: 18),
                                        _buildStep3(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),

                                  // RIGHT COLUMN: Payment, Forensics & Summary (Flex 2)
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildStep4(),
                                        const SizedBox(height: 18),
                                        _buildSubmitCard(),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStep1(),
                                  const SizedBox(height: 16),
                                  _buildStep2(),
                                  const SizedBox(height: 16),
                                  _buildStep3(),
                                  const SizedBox(height: 16),
                                  _buildStep4(),
                                  const SizedBox(height: 16),
                                  _buildSubmitCard(),
                                ],
                              );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
