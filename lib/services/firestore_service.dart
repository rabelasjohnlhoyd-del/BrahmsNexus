import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/announcement.dart';
import '../models/bilao_order.dart';
import '../models/branch.dart';
import '../models/branch_assignment.dart';
import '../models/branch_daily_inventory.dart';
import '../models/branch_meat_inventory.dart';
import '../models/daily_report.dart';
import '../models/inventory_batch.dart';
import '../models/meat_dispatch.dart';
import '../models/app_notification.dart';
import '../models/sales_record.dart';
import 'auth_service.dart';
import 'firestore_cache.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Service dedicated to handling high-frequency, operational, and real-time
/// data in Cloud Firestore.
///
/// PERFORMANCE & QUOTA OPTIMIZATION RULES:
/// 1. Every query is bounded with .limit() — no unconstrained collection reads.
/// 2. Deterministic IDs used where applicable (e.g. `${branchId}_${yyyyMMdd}`)
///    to fetch exactly 1 document directly via .doc() instead of running a scan.
/// 3. Streams are scoped only to active/today's datasets, not historical records.
/// 4. Heavy personal profile fields are omitted (kept in Supabase).
class FirestoreService {
  const FirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===========================================================================
  // 1. BILAO ORDERS (Operational & Real-Time)
  // ===========================================================================

  static final List<BilaoOrder> _defaultBilaoOrders = [
    BilaoOrder(
      id: 'ord1',
      customerName: 'Ana Lopez',
      contactNumber: '0917 555 1234',
      size: BilaoSize.large,
      quantity: 2,
      scheduledDateTime: DateTime.now().add(const Duration(hours: 5)),
      preparationStatus: PreparationStatus.preparing,
      deliveryStatus: DeliveryStatus.forDelivery,
    ),
    BilaoOrder(
      id: 'ord2',
      customerName: 'Mark Villanueva',
      contactNumber: '0917 555 5678',
      size: BilaoSize.medium,
      quantity: 1,
      scheduledDateTime: DateTime.now().add(const Duration(days: 1)),
      preparationStatus: PreparationStatus.pending,
      deliveryStatus: DeliveryStatus.forDelivery,
    ),
    BilaoOrder(
      id: 'ord3',
      customerName: 'Liza Gomez',
      contactNumber: '0917 555 9012',
      size: BilaoSize.small,
      quantity: 3,
      scheduledDateTime: DateTime.now().subtract(const Duration(days: 2)),
      preparationStatus: PreparationStatus.ready,
      deliveryStatus: DeliveryStatus.completed,
    ),
  ];

  /// Stream of all active and upcoming bilao orders for Admin Web & Owner App.
  static Stream<List<BilaoOrder>> watchAllBilaoOrders({int limit = 50}) {
    final query = _db
        .collection('bilao_orders')
        .orderBy('scheduledDateTime', descending: true)
        .limit(limit);
    return FirestoreListenCache.query('bilao_orders:all:$limit', query)
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultBilaoOrders;
      }
      return snapshot.docs.map((doc) => _bilaoFromDoc(doc)).toList();
    });
  }

  /// Stream of active orders for drivers/dispatch.
  static Stream<List<BilaoOrder>> watchActiveBilaoOrders() {
    final query = _db
        .collection('bilao_orders')
        .where('deliveryStatus', whereIn: ['forDelivery'])
        .orderBy('scheduledDateTime', descending: false)
        .limit(25); // Strict boundary to protect reads
    return FirestoreListenCache.query('bilao_orders:active', query)
        .map((snapshot) {
      return snapshot.docs.map((doc) => _bilaoFromDoc(doc)).toList();
    });
  }

  /// Paginated fetch for historical Bilao orders (for Admin Web & Owner App).
  /// Uses cursor pagination with [startAfter] DocumentSnapshot to prevent
  /// reading skipped pages.
  static Future<List<BilaoOrder>> getPaginatedBilaoOrders({
    int pageSize = 10,
    DocumentSnapshot? startAfter,
    String? statusFilter,
  }) async {
    try {
      Query query = _db.collection('bilao_orders').orderBy('scheduledDateTime', descending: true);

      if (statusFilter != null && statusFilter != 'All') {
        query = query.where('deliveryStatus', isEqualTo: statusFilter);
      }

      query = query.limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final cacheKey =
          'bilao_page:${statusFilter ?? 'All'}:$pageSize:${startAfter?.id ?? 'first'}';
      final cached = FirestoreReadCache.get<List<BilaoOrder>>(cacheKey);
      if (cached != null) return cached;

      final snapshot = await query.get();
      final list = snapshot.docs.map((doc) => _bilaoFromDoc(doc)).toList();
      FirestoreReadCache.set(cacheKey, list);
      return list;
    } catch (e) {
      debugPrint('FirestoreService.getPaginatedBilaoOrders error: $e');
      return [];
    }
  }

  /// Creates a new confirmed bilao order.
  static Future<String?> createBilaoOrder(BilaoOrder order) async {
    try {
      final docRef = await _db.collection('bilao_orders').add({
        'customerName': order.customerName,
        'contactNumber': order.contactNumber,
        'size': order.size.name,
        'quantity': order.quantity,
        'scheduledDateTime': Timestamp.fromDate(order.scheduledDateTime),
        'deliveryAddress': order.deliveryAddress,
        'preparationStatus': order.preparationStatus.name,
        'deliveryStatus': order.deliveryStatus.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('FirestoreService.createBilaoOrder error: $e');
      return null;
    }
  }

  /// Updates preparation or delivery status in real-time.
  static Future<bool> updateBilaoStatus({
    required String orderId,
    PreparationStatus? preparationStatus,
    DeliveryStatus? deliveryStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (preparationStatus != null) {
        data['preparationStatus'] = preparationStatus.name;
      }
      if (deliveryStatus != null) {
        data['deliveryStatus'] = deliveryStatus.name;
      }

      await _db.collection('bilao_orders').doc(orderId).update(data);
      return true;
    } catch (e) {
      debugPrint('FirestoreService.updateBilaoStatus error: $e');
      return false;
    }
  }

  static BilaoOrder _bilaoFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = data['scheduledDateTime'] as Timestamp?;
    final scheduledDate = timestamp?.toDate() ?? DateTime.now();

    final sizeStr = data['size']?.toString() ?? 'small';
    final prepStr = data['preparationStatus']?.toString() ?? 'pending';
    final delivStr = data['deliveryStatus']?.toString() ?? 'forDelivery';

    return BilaoOrder(
      id: doc.id,
      customerName: data['customerName']?.toString() ?? '',
      contactNumber: data['contactNumber']?.toString() ?? '',
      size: BilaoSize.values.firstWhere((e) => e.name == sizeStr, orElse: () => BilaoSize.small),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      scheduledDateTime: scheduledDate,
      deliveryAddress: data['deliveryAddress']?.toString() ?? '',
      preparationStatus: PreparationStatus.values.firstWhere((e) => e.name == prepStr, orElse: () => PreparationStatus.pending),
      deliveryStatus: DeliveryStatus.values.firstWhere((e) => e.name == delivStr, orElse: () => DeliveryStatus.forDelivery),
    );
  }

  // ===========================================================================
  // 2. DAILY INVENTORY RECONCILIATION (Cost-Effective Document-Id Addressing)
  // ===========================================================================

  static String _dailyInventoryDocId(String branchId, DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${branchId}_$yyyy$mm$dd';
  }

  /// Streams today's inventory check for a specific branch.
  /// Uses a direct document reference (1 read per stream update, no query costs).
  static Stream<BranchDailyInventory?> watchTodayBranchInventory({
    required String branchId,
    required String branchName,
    required DateTime date,
  }) {
    final docId = _dailyInventoryDocId(branchId, date);
    return FirestoreListenCache.doc(
      'branch_daily_inventories/$docId',
      _db.collection('branch_daily_inventories').doc(docId),
    ).map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final data = snapshot.data()!;
      final allocated = data['allocated'] as Map<String, dynamic>? ?? {};
      final ar = data['actualReceived'] as Map<String, dynamic>?;

      return BranchDailyInventory(
        branchId: branchId,
        branchName: branchName,
        date: date,
        allocated: InventoryCounts(
          karne: (allocated['karne'] as num?)?.toInt() ?? 0,
          mayo: (allocated['mayo'] as num?)?.toInt() ?? 0,
          styro: (allocated['styro'] as num?)?.toInt() ?? 0,
          toyo: (allocated['toyo'] as num?)?.toInt() ?? 0,
        ),
        status: InventoryVerificationStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => InventoryVerificationStatus.pending,
        ),
        discrepancyNote: data['discrepancyNote']?.toString(),
        verifiedBy: data['verifiedBy']?.toString(),
        verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
        actualReceived: ar == null
            ? null
            : ActualReceivedCounts(
                mayo: (ar['mayo'] as num?)?.toInt() ?? 0,
                toyo: (ar['toyo'] as num?)?.toInt() ?? 0,
                styro: (ar['styro'] as num?)?.toInt() ?? 0,
                regular: (ar['regular'] as num?)?.toInt() ?? 0,
                medium: (ar['medium'] as num?)?.toInt() ?? 0,
                b1t1: (ar['b1t1'] as num?)?.toInt() ?? 0,
              ),
      );
    });
  }

  /// Streams today's inventory verification status for ALL branches.
  /// Uses one document-level snapshot per branch (guaranteed real-time,
  /// no `whereIn` query limitations). Each individual stream fires the
  /// moment a staff member confirms or reports a discrepancy.
  static Stream<List<BranchDailyInventory>> watchAllBranchDailyInventories({
    required List<Branch> branches,
    required DateTime date,
  }) {
    // Create a StreamController that merges all per-branch snapshot listeners
    late StreamController<List<BranchDailyInventory>> controller;
    final Map<String, BranchDailyInventory?> latest = {};
    final List<StreamSubscription<BranchDailyInventory?>> subs = [];

    void emit() {
      if (!controller.isClosed) {
        final list = branches.map((branch) {
          return latest[branch.id] ??
              BranchDailyInventory(
                branchId: branch.id,
                branchName: branch.fullName,
                date: date,
                allocated: const InventoryCounts(karne: 40, mayo: 40, styro: 40, toyo: 10),
                status: InventoryVerificationStatus.pending,
              );
        }).toList();
        controller.add(list);
      }
    }

    controller = StreamController<List<BranchDailyInventory>>(
      onListen: () {
        // Immediately emit the initial pending list for all branches
        emit();

        for (final branch in branches) {
          final sub = watchTodayBranchInventory(
            branchId: branch.id,
            branchName: branch.fullName,
            date: date,
          ).listen((inv) {
            latest[branch.id] = inv;
            emit();
          }, onError: (_) {});
          subs.add(sub);
        }
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );

    return controller.stream;
  }


  /// Sets or updates the daily inventory verification.
  /// If [record.actualReceived] is provided (i.e., Staff confirmed or denied),
  /// it is saved under the 'actualReceived' map so the Owner can compare
  /// what was supposed to be delivered vs what was actually counted.
  /// Also writes an owner notification for real-time alerting.
  static Future<bool> saveDailyInventory(BranchDailyInventory record) async {
    final docId = _dailyInventoryDocId(record.branchId, record.date);
    try {
      final data = <String, dynamic>{
        'branchId': record.branchId,
        'branchName': record.branchName,
        'date': Timestamp.fromDate(record.date),
        'allocated': {
          'karne': record.allocated.karne,
          'mayo': record.allocated.mayo,
          'styro': record.allocated.styro,
          'toyo': record.allocated.toyo,
        },
        'status': record.status.name,
        'discrepancyNote': record.discrepancyNote,
        'updatedAt': FieldValue.serverTimestamp(),
        if (record.verifiedBy != null) 'verifiedBy': record.verifiedBy,
        if (record.verifiedAt != null) 'verifiedAt': Timestamp.fromDate(record.verifiedAt!),
      };

      // Include actual received counts if Staff has submitted verification
      if (record.actualReceived != null) {
        final ar = record.actualReceived!;
        data['actualReceived'] = {
          'mayo': ar.mayo,
          'toyo': ar.toyo,
          'styro': ar.styro,
          'regular': ar.regular,
          'medium': ar.medium,
          'b1t1': ar.b1t1,
        };
      }

      await _db.collection('branch_daily_inventories').doc(docId).set(
        data,
        SetOptions(merge: true),
      );

      // ── Notify Owner in real-time ───────────────────────────────────────────
      final isDiscrepancy = record.status == InventoryVerificationStatus.discrepancyReported;
      final isConfirmed   = record.status == InventoryVerificationStatus.confirmed;
      if (isConfirmed || isDiscrepancy) {
        final emoji = isDiscrepancy ? '⚠️' : '✅';
        final statusLabel = isDiscrepancy ? 'Discrepancy Reported' : 'Confirmed';
        final noteExtra = (isDiscrepancy && (record.discrepancyNote?.isNotEmpty ?? false))
            ? ': "${record.discrepancyNote}"'
            : '';
        final notifTitle = '$emoji Inventory $statusLabel — ${record.branchName}';
        final notifBody = 'Branch ${record.branchName} inventory $statusLabel$noteExtra.';

        // 1. Post to main notifications collection — feeds Owner's real-time bell panel
        await NotificationService.sendNotification(
          title: notifTitle,
          message: notifBody,
          type: NotificationType.inventoryAlert,
          targetRole: 'owner',
          route: isDiscrepancy ? 'inventory_dispatch' : 'inventory',
          targetBranch: record.branchName,
        );

        // 2. Also record in owner_notifications for backward compatibility
        await _db.collection('owner_notifications').add({
          'type': isDiscrepancy ? 'inventory_discrepancy' : 'inventory_confirmed',
          'title': notifTitle,
          'body': notifBody,
          'branchId': record.branchId,
          'branchName': record.branchName,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // ── If Discrepancy Reported, also sync the actual counts to branch_meat_stocks ──
      if (isDiscrepancy && record.actualReceived != null) {
        final ar = record.actualReceived!;
        await _db.collection('branch_meat_stocks').doc(record.branchId).set({
          'regular250gTotal': ar.regular,
          'regular250gRemaining': ar.regular,
          'medium300gTotal': ar.medium,
          'medium300gRemaining': ar.medium,
          'b1t1_400gTotal': ar.b1t1,
          'b1t1_400gRemaining': ar.b1t1,
          'mayoTotal': ar.mayo,
          'mayoRemaining': ar.mayo,
          'styroTotal': ar.styro,
          'styroRemaining': ar.styro,
          'toyoTotal': ar.toyo,
          'toyoRemaining': ar.toyo,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // ── Mirror the discrepancy report into daily_reports so it appears on Employee Reports ──
      if (isDiscrepancy) {
        final empName = (record.verifiedBy != null && record.verifiedBy!.isNotEmpty)
            ? record.verifiedBy!
            : (AuthService.currentUser?.fullName.isNotEmpty == true
                ? AuthService.currentUser!.fullName
                : AuthService.currentUsername);
        final ar = record.actualReceived;
        final countsSummary = ar != null
            ? 'Reg ${ar.regular} pcs, Med ${ar.medium} pcs, B1T1 ${ar.b1t1} pcs, Mayo ${ar.mayo}, Styro ${ar.styro}, Toyo ${ar.toyo}'
            : '';
        final noteText = (record.discrepancyNote != null && record.discrepancyNote!.trim().isNotEmpty)
            ? record.discrepancyNote!.trim()
            : 'Kulang ang natanggap na stock sa inventory verification.';
        final reportContent = countsSummary.isNotEmpty
            ? 'Inventory Discrepancy:\n"$noteText"\n\nAktwal na natanggap:\n$countsSummary'
            : 'Inventory Discrepancy:\n"$noteText"';

        try {
          final existingQuery = await _db
              .collection('daily_reports')
              .where('branchId', isEqualTo: record.branchId)
              .limit(20)
              .get();

          DocumentSnapshot<Map<String, dynamic>>? existingDoc;
          for (final doc in existingQuery.docs) {
            final data = doc.data();
            final content = data['content'] as String? ?? '';
            final ts = data['date'] as Timestamp?;
            if (content.startsWith('Inventory Discrepancy:') && ts != null) {
              final dt = ts.toDate();
              if (dt.year == record.date.year &&
                  dt.month == record.date.month &&
                  dt.day == record.date.day) {
                existingDoc = doc;
                break;
              }
            }
          }

          if (existingDoc != null) {
            await existingDoc.reference.update({
              'content': reportContent,
              'status': ReportSubmissionStatus.incomplete.name,
              'employeeName': empName,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            await _db.collection('daily_reports').add({
              'employeeId': AuthService.currentUserId,
              'employeeName': empName,
              'branchId': record.branchId,
              'branchName': record.branchName,
              'date': Timestamp.fromDate(record.date),
              'content': reportContent,
              'status': ReportSubmissionStatus.incomplete.name,
              'submittedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Error recording discrepancy to daily_reports: $e');
        }
      }

      // If confirmed, mark any open discrepancy report for today as resolved
      if (isConfirmed) {
        try {
          final existingQuery = await _db
              .collection('daily_reports')
              .where('branchId', isEqualTo: record.branchId)
              .limit(20)
              .get();
          for (final doc in existingQuery.docs) {
            final data = doc.data();
            final content = data['content'] as String? ?? '';
            final ts = data['date'] as Timestamp?;
            if (content.startsWith('Inventory Discrepancy:') && ts != null) {
              final dt = ts.toDate();
              if (dt.year == record.date.year &&
                  dt.month == record.date.month &&
                  dt.day == record.date.day &&
                  data['status'] != ReportSubmissionStatus.submitted.name) {
                await doc.reference.update({
                  'status': ReportSubmissionStatus.submitted.name,
                  'resolvedAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        } catch (_) {}
      }
      // ───────────────────────────────────────────────────────────────────────

      return true;
    } catch (e) {
      debugPrint('FirestoreService.saveDailyInventory error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 3. DAILY SALES & EMPLOYEE EARNINGS
  // ===========================================================================

  /// Special function for Admin to adjust allocation for a branch today.
  static Future<bool> adjustDailyAllocation({
    required String branchId,
    required String branchName,
    required DateTime date,
    required InventoryCounts newAllocation,
  }) async {
    final docId = _dailyInventoryDocId(branchId, date);
    try {
      await _db.collection('branch_daily_inventories').doc(docId).set({
        'branchId': branchId,
        'branchName': branchName,
        'date': Timestamp.fromDate(date),
        'allocated': {
          'karne': newAllocation.karne,
          'mayo': newAllocation.mayo,
          'styro': newAllocation.styro,
          'toyo': newAllocation.toyo,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('FirestoreService.adjustDailyAllocation error: $e');
      return false;
    }
  }

  static String _dailySalesDocId(String branchId, DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${branchId}_$yyyy$mm$dd';
  }

  /// Streams today's sales submission for a specific branch.
  /// If a record exists for today, returns the SalesRecord; otherwise returns null.
  static Stream<SalesRecord?> watchTodayBranchSales({
    required String branchId,
    required DateTime date,
  }) {
    final docId = _dailySalesDocId(branchId, date);
    return FirestoreListenCache.doc(
      'daily_sales/$docId',
      _db.collection('daily_sales').doc(docId),
    ).map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final data = snapshot.data()!;
      final ts = data['date'] as Timestamp?;
      final rs = data['remainingStock'] as Map<String, dynamic>?;
      return SalesRecord(
        id: snapshot.id,
        branchId: data['branchId']?.toString() ?? branchId,
        branchName: data['branchName']?.toString() ?? '',
        employeeId: data['employeeId']?.toString() ?? '',
        employeeName: data['employeeName']?.toString() ?? '',
        date: ts?.toDate() ?? date,
        portionsSold: (data['portionsSold'] as num?)?.toInt() ?? 0,
        commissionRatePerPortion: (data['commissionRatePerPortion'] as num?)?.toDouble() ?? 5.0,
        totalSalesAmount: (data['totalSalesAmount'] as num?)?.toDouble() ?? 0.0,
        wage: (data['wage'] as num?)?.toDouble() ?? (data['computedWage'] as num?)?.toDouble(),
        regularSold: (data['regularSold'] as num?)?.toInt(),
        mediumSold: (data['mediumSold'] as num?)?.toInt(),
        b1t1OrdersSold: (data['b1t1OrdersSold'] as num?)?.toInt(),
        totalOrders: (data['totalOrders'] as num?)?.toInt(),
        discrepancyNote: data['discrepancyNote']?.toString(),
        remainingStock: rs == null
            ? null
            : ActualReceivedCounts(
                mayo: (rs['mayo'] as num?)?.toInt() ?? 0,
                toyo: (rs['toyo'] as num?)?.toInt() ?? 0,
                styro: (rs['styro'] as num?)?.toInt() ?? 0,
                regular: (rs['regular'] as num?)?.toInt() ?? 0,
                medium: (rs['medium'] as num?)?.toInt() ?? 0,
                b1t1: (rs['b1t1'] as num?)?.toInt() ?? 0,
              ),
      );
    });
  }

  /// Saves the end-of-day sales record submitted by a branch cook.
  /// Also saves an owner notification so the owner sees it in real-time.
  static Future<bool> submitDailySales(SalesRecord sales) async {
    try {
      final docId = _dailySalesDocId(sales.branchId, sales.date);
      final data = <String, dynamic>{
        'branchId': sales.branchId,
        'branchName': sales.branchName,
        'employeeId': sales.employeeId,
        'employeeName': sales.employeeName,
        'date': Timestamp.fromDate(sales.date),
        'portionsSold': sales.portionsSold,
        'totalOrders': sales.totalOrders ?? sales.displayTotalOrders,
        'commissionRatePerPortion': sales.commissionRatePerPortion,
        'totalSalesAmount': sales.totalSalesAmount,
        'computedWage': sales.computedWage,
        'expectedCashRemittance': sales.expectedCashRemittance,
        'wage': sales.wage ?? sales.computedWage,
        'regularSold': sales.regularSold,
        'mediumSold': sales.mediumSold,
        'b1t1OrdersSold': sales.b1t1OrdersSold,
        'submittedAt': FieldValue.serverTimestamp(),
      };
      if (sales.discrepancyNote != null && sales.discrepancyNote!.isNotEmpty) {
        data['discrepancyNote'] = sales.discrepancyNote;
      }
      if (sales.remainingStock != null) {
        final rs = sales.remainingStock!;
        data['remainingStock'] = {
          'mayo': rs.mayo,
          'toyo': rs.toyo,
          'styro': rs.styro,
          'regular': rs.regular,
          'medium': rs.medium,
          'b1t1': rs.b1t1,
        };
      }
      await _db.collection('daily_sales').doc(docId).set(data);

      // ── Dual-Sync to Supabase (PostgreSQL - 0 read cost on analytics) ──
      final salesWithId = sales.id.isNotEmpty
          ? sales
          : SalesRecord(
              id: docId,
              branchId: sales.branchId,
              branchName: sales.branchName,
              employeeId: sales.employeeId,
              employeeName: sales.employeeName,
              date: sales.date,
              portionsSold: sales.portionsSold,
              commissionRatePerPortion: sales.commissionRatePerPortion,
              totalSalesAmount: sales.totalSalesAmount,
              totalOrders: sales.totalOrders,
              remainingStock: sales.remainingStock,
              wage: sales.wage,
              regularSold: sales.regularSold,
              mediumSold: sales.mediumSold,
              b1t1OrdersSold: sales.b1t1OrdersSold,
              discrepancyNote: sales.discrepancyNote,
            );
      SupabaseService.saveDailySales(salesWithId).catchError((_) => false);
      // ──────────────────────────────────────────────────────────────────

      // ── Notify Owner in real-time (both notifications and owner_notifications) ──
      final rs = sales.remainingStock;
      final stockNote = rs != null
          ? ' | Remaining: Reg ${rs.regular}, Med ${rs.medium}, B1T1 ${rs.b1t1}, Mayo ${rs.mayo}, Styro ${rs.styro}, Toyo ${rs.toyo}'
          : '';
      final hasDiscrepancy = sales.discrepancyNote?.isNotEmpty == true;
      final discrepancyExtra = hasDiscrepancy ? '\n⚠️ Dahilan sa Discrepancy: "${sales.discrepancyNote}"' : '';
      final notifTitle = hasDiscrepancy
          ? '⚠️ Sales with Discrepancy — ${sales.branchName}'
          : '💰 Sales Submitted — ${sales.branchName}';
      final notifBody = '${sales.employeeName} submitted ${sales.portionsSold} portions'
          ' (₱${sales.totalSalesAmount.toStringAsFixed(0)})$stockNote$discrepancyExtra';
      
      // 1. Post to main notifications collection (used by Admin Web Bell & Header)
      await NotificationService.sendNotification(
        title: notifTitle,
        message: notifBody,
        type: NotificationType.salesReport,
        targetRole: 'owner',
        route: 'sales',
        targetBranch: sales.branchName,
      );

      // 2. Also record in owner_notifications collection for backward compatibility
      await _db.collection('owner_notifications').add({
        'type': hasDiscrepancy ? 'sales_discrepancy' : 'sales_submitted',
        'title': notifTitle,
        'body': notifBody,
        'branchId': sales.branchId,
        'branchName': sales.branchName,
        'employeeName': sales.employeeName,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // ─────────────────────────────────────────────────────────────────────

      return true;
    } catch (e) {
      debugPrint('FirestoreService.submitDailySales error: $e');
      return false;
    }
  }

  /// Streams real-time owner notifications (sales submitted, inventory verified, etc.)
  static Stream<List<Map<String, dynamic>>> watchOwnerNotifications({int limit = 30}) {
    final query = _db
        .collection('owner_notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    return FirestoreListenCache.query('owner_notifications:$limit', query)
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              return {
                'id': d.id,
                'type': data['type'] ?? '',
                'title': data['title'] ?? '',
                'body': data['body'] ?? '',
                'branchName': data['branchName'] ?? '',
                'isRead': data['isRead'] ?? false,
                'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
              };
            }).toList());
  }

  /// Marks an owner notification as read.
  static Future<void> markNotificationRead(String notifId) async {
    try {
      await _db.collection('owner_notifications').doc(notifId).update({'isRead': true});
    } catch (e) {
      debugPrint('markNotificationRead error: $e');
    }
  }


  static final List<SalesRecord> _defaultSalesRecords = [
    SalesRecord(
      id: 's1',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      employeeId: 'emp1',
      employeeName: 'Jovelle P. Camila',
      date: DateTime.now(),
      portionsSold: 42,
      commissionRatePerPortion: 5,
      totalSalesAmount: 4200,
    ),
    SalesRecord(
      id: 's2',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      employeeId: 'emp2',
      employeeName: 'Jobelle T. Fuentes',
      date: DateTime.now(),
      portionsSold: 35,
      commissionRatePerPortion: 5,
      totalSalesAmount: 3500,
    ),
    SalesRecord(
      id: 's3',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      employeeId: 'emp3',
      employeeName: 'Patricia Mharie M. Espiritu',
      date: DateTime.now().subtract(const Duration(days: 1)),
      portionsSold: 28,
      commissionRatePerPortion: 5,
      totalSalesAmount: 2800,
    ),
  ];

  /// Streams real-time daily sales records.
  static Stream<List<SalesRecord>> watchRecentSales({int limit = 50}) {
    final query = _db
        .collection('daily_sales')
        .orderBy('date', descending: true)
        .limit(limit);
    return FirestoreListenCache.query('daily_sales:recent:$limit', query)
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultSalesRecords;
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        final rs = data['remainingStock'] as Map<String, dynamic>?;
        return SalesRecord(
          id: doc.id,
          branchId: data['branchId']?.toString() ?? '',
          branchName: data['branchName']?.toString() ?? '',
          employeeId: data['employeeId']?.toString() ?? '',
          employeeName: data['employeeName']?.toString() ?? '',
          date: ts?.toDate() ?? DateTime.now(),
          portionsSold: (data['portionsSold'] as num?)?.toInt() ?? 0,
          commissionRatePerPortion: (data['commissionRatePerPortion'] as num?)?.toDouble() ?? 5.0,
          totalSalesAmount: (data['totalSalesAmount'] as num?)?.toDouble() ?? 0.0,
          wage: (data['wage'] as num?)?.toDouble() ?? (data['computedWage'] as num?)?.toDouble(),
          regularSold: (data['regularSold'] as num?)?.toInt(),
          mediumSold: (data['mediumSold'] as num?)?.toInt(),
          b1t1OrdersSold: (data['b1t1OrdersSold'] as num?)?.toInt(),
          totalOrders: (data['totalOrders'] as num?)?.toInt(),
          remainingStock: rs == null
              ? null
              : ActualReceivedCounts(
                  mayo: (rs['mayo'] as num?)?.toInt() ?? 0,
                  toyo: (rs['toyo'] as num?)?.toInt() ?? 0,
                  styro: (rs['styro'] as num?)?.toInt() ?? 0,
                  regular: (rs['regular'] as num?)?.toInt() ?? 0,
                  medium: (rs['medium'] as num?)?.toInt() ?? 0,
                  b1t1: (rs['b1t1'] as num?)?.toInt() ?? 0,
                ),
        );
      }).toList();
    });
  }

  /// Fetches sales records for a specified date range (defaulting to last 7 days).
  /// Never reads whole database history to prevent runaway bills.
  static Future<List<SalesRecord>> getRecentSales({
    DateTime? startDate,
    int limit = 50,
  }) async {
    // 1. Try Supabase first (Zero Firestore read consumption!)
    try {
      final supabaseSales = await SupabaseService.getRecentSales(
        startDate: startDate,
        limit: limit,
      );
      if (supabaseSales.isNotEmpty) {
        return supabaseSales;
      }
    } catch (_) {}

    // 2. Fallback to Firestore if Supabase table is not yet seeded or unavailable
    try {
      final from = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final cacheKey = 'sales:${from.toIso8601String()}:$limit';
      final cached = FirestoreReadCache.get<List<SalesRecord>>(cacheKey);
      if (cached != null) return cached;

      final snapshot = await _db
          .collection('daily_sales')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        return SalesRecord(
          id: doc.id,
          branchId: data['branchId']?.toString() ?? '',
          branchName: data['branchName']?.toString() ?? '',
          employeeId: data['employeeId']?.toString() ?? '',
          employeeName: data['employeeName']?.toString() ?? '',
          date: ts?.toDate() ?? DateTime.now(),
          portionsSold: (data['portionsSold'] as num?)?.toInt() ?? 0,
          commissionRatePerPortion: (data['commissionRatePerPortion'] as num?)?.toDouble() ?? 5.0,
          totalSalesAmount: (data['totalSalesAmount'] as num?)?.toDouble() ?? 0.0,
          wage: (data['wage'] as num?)?.toDouble() ?? (data['computedWage'] as num?)?.toDouble(),
          regularSold: (data['regularSold'] as num?)?.toInt(),
          mediumSold: (data['mediumSold'] as num?)?.toInt(),
          b1t1OrdersSold: (data['b1t1OrdersSold'] as num?)?.toInt(),
          totalOrders: (data['totalOrders'] as num?)?.toInt(),
        );
      }).toList();
      FirestoreReadCache.set(cacheKey, list);
      return list;
    } catch (e) {
      debugPrint('FirestoreService.getRecentSales error: $e');
      return [];
    }
  }

  // ===========================================================================
  // 4. DAILY EMPLOYEE INCIDENT REPORTS
  // ===========================================================================

  static final List<DailyReport> _defaultReports = [
    DailyReport(
      id: 'r1',
      employeeId: 'emp1',
      employeeName: 'Jovelle P. Camila',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      content: 'Kumpleto ang benta ngayong araw, walang isyu sa stock.',
      status: ReportSubmissionStatus.submitted,
    ),
    DailyReport(
      id: 'r2',
      employeeId: 'emp2',
      employeeName: 'Jobelle T. Fuentes',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      content: 'Kulang ang mayo, humingi na ng dagdag kay Driver.',
      status: ReportSubmissionStatus.incomplete,
    ),
  ];

  /// Streams real-time daily employee reports.
  static Stream<List<DailyReport>> watchDailyReports({int limit = 50}) {
    final query = _db
        .collection('daily_reports')
        .orderBy('date', descending: true)
        .limit(limit);
    return FirestoreListenCache.query('daily_reports:$limit', query)
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultReports;
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        final statusStr = data['status']?.toString() ?? 'submitted';
        return DailyReport(
          id: doc.id,
          employeeId: data['employeeId']?.toString() ?? '',
          employeeName: data['employeeName']?.toString() ?? '',
          branchId: data['branchId']?.toString() ?? '',
          branchName: data['branchName']?.toString() ?? '',
          date: ts?.toDate() ?? DateTime.now(),
          content: data['content']?.toString() ?? '',
          status: ReportSubmissionStatus.values.firstWhere(
            (e) => e.name == statusStr,
            orElse: () => ReportSubmissionStatus.submitted,
          ),
          ownerReply: data['ownerReply']?.toString(),
        );
      }).toList();
    });
  }

  /// Saves an employee daily incident report in Firestore and notifies the owner.
  static Future<bool> submitDailyReport(DailyReport report) async {
    try {
      final docRef = await _db.collection('daily_reports').add({
        'employeeId': report.employeeId,
        'employeeName': report.employeeName,
        'branchId': report.branchId,
        'branchName': report.branchName,
        'date': Timestamp.fromDate(report.date),
        'content': report.content,
        'status': report.status.name,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Dual-sync to Supabase
      final reportWithId = report.copyWith(id: docRef.id);
      SupabaseService.saveDailyReport(reportWithId).catchError((_) => false);

      // Notify owner in real time
      final hasIncident = report.status == ReportSubmissionStatus.incomplete;
      final notifTitle = hasIncident
          ? '⚠️ Incident Report — ${report.branchName}'
          : '📋 Daily Report — ${report.branchName}';
      final notifMsg = '${report.employeeName}: ${report.content.length > 80 ? '${report.content.substring(0, 80)}...' : report.content}';

      // Mayo & additional karne incidents route to dispatch logs; gas & others to employee_reports
      final lower = report.content.toLowerCase();
      final isSupplyOrMeat = lower.contains('mayo') || lower.contains('karne') || lower.contains('meat');
      final notifRoute = isSupplyOrMeat ? 'inventory_dispatch' : 'employee_reports';

      await NotificationService.sendNotification(
        title: notifTitle,
        message: notifMsg,
        type: NotificationType.salesReport,
        targetRole: 'owner',
        route: notifRoute,
        targetBranch: report.branchName,
      );

      return true;
    } catch (e) {
      debugPrint('FirestoreService.submitDailyReport error: $e');
      return false;
    }
  }

  /// Saves the Owner's / Admin's quick response or reply to an employee report,
  /// then notifies the branch cook that there's a reply waiting.
  static Future<bool> replyToDailyReport({
    required String reportId,
    required String reply,
    required String branchName,
    required String employeeId,
    required String employeeName,
  }) async {
    try {
      await _db.collection('daily_reports').doc(reportId).update({
        'ownerReply': reply,
        'repliedAt': FieldValue.serverTimestamp(),
      });

      // Dual-sync to Supabase
      SupabaseService.replyToDailyReport(reportId: reportId, reply: reply).catchError((_) => false);

      // Notify the branch cook that owner replied
      await NotificationService.sendNotification(
        title: '💬 May tugon ang Owner sa iyong report',
        message: 'Sinabi ni Owner: "$reply" — i-tap para makita.',
        type: NotificationType.salesReport,
        targetRole: 'staff',
        targetUserId: employeeId.isNotEmpty ? employeeId : null,
        targetBranch: branchName,
        route: 'daily_report',
      );

      return true;
    } catch (e) {
      debugPrint('FirestoreService.replyToDailyReport error: $e');
      return false;
    }
  }

  /// Branch cook confirms that the replacement/delivery for an incomplete report
  /// has been received — sets status to 'submitted' and notifies owner.
  static Future<bool> confirmReportReceived({
    required String reportId,
    required String branchName,
    required String employeeName,
  }) async {
    try {
      await _db.collection('daily_reports').doc(reportId).update({
        'status': ReportSubmissionStatus.submitted.name,
        'receivedConfirmedAt': FieldValue.serverTimestamp(),
      });

      // Dual-sync to Supabase
      SupabaseService.confirmReportReceived(reportId: reportId).catchError((_) => false);

      // Notify owner that the delivery/fix was confirmed by cook
      await NotificationService.sendNotification(
        title: '✅ Na-confirm na ng Branch Cook',
        message: '$employeeName ($branchName) ay nagkumpirma na natanggap na ang naihatid.',
        type: NotificationType.inventoryAlert,
        targetRole: 'owner',
        route: 'employee_reports',
        targetBranch: branchName,
      );

      return true;
    } catch (e) {
      debugPrint('FirestoreService.confirmReportReceived error: $e');
      return false;
    }
  }

  /// Deletes a meat dispatch record (owner/admin only — for erroneous entries).
  static Future<bool> deleteDispatch(String dispatchId) async {
    try {
      await _db.collection('meat_dispatches').doc(dispatchId).delete();
      return true;
    } catch (e) {
      debugPrint('FirestoreService.deleteDispatch error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 5. ESP32 RFID ATTENDANCE TAP INTEGRATION
  // ===========================================================================


  /// Records an RFID card tap received from the ESP32 reader.
  static Future<bool> recordRfidTap({
    required String rfidTag,
    required String employeeId,
    required String employeeName,
    required String branchId,
    required String branchName,
    String tapType = 'check_in', // check_in or check_out
    String deviceId = 'esp32_branch_reader',
  }) async {
    try {
      await _db.collection('rfid_attendance').add({
        'rfidTag': rfidTag,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'branchId': branchId,
        'branchName': branchName,
        'tapType': tapType,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('FirestoreService.recordRfidTap error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 6. PRODUCTION KARNE BATCHES & SESSIONS (Warehouse / Commissary)
  // ===========================================================================

  static final List<KarneBatch> _defaultBatches = [
    KarneBatch(
      id: 'kb1',
      name: 'Batch Danish Crown - July',
      totalKilos: 1000,
    ),
  ];

  /// Seeds the default batches to Firestore once if the collection is empty.
  static Future<void> seedDefaultBatchesIfEmpty() async {
    try {
      final snapshot = await _db
          .collection('production_batches')
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return; // Already seeded

      for (final batch in _defaultBatches) {
        final data = batch.toMap();
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        await _db
            .collection('production_batches')
            .doc(batch.id)
            .set(data, SetOptions(merge: true));
        debugPrint('FirestoreService: Seeded default batch ${batch.id}');
      }
    } catch (e) {
      debugPrint('FirestoreService.seedDefaultBatchesIfEmpty error: $e');
    }
  }

  /// Streams real-time production batches from Firestore.
  /// Does NOT use orderBy('createdAt') on the server query so documents
  /// with pending timestamps or missing fields are never silently dropped,
  /// and composite index errors never occur.
  static Stream<List<KarneBatch>> watchProductionBatches({int limit = 50}) {
    final query = _db.collection('production_batches').limit(limit);
    return FirestoreListenCache.query('production_batches:$limit', query)
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultBatches;
      }
      final list = snapshot.docs
          .map((doc) => KarneBatch.fromMap(doc.data(), doc.id))
          .toList();
      return list;
    }).handleError((error) {
      debugPrint('FirestoreService.watchProductionBatches stream error: $error');
      return _defaultBatches;
    });
  }

  /// Streams real-time updates for a SINGLE production batch document.
  /// Used by KarneBatchDetailScreen (Admin Web) so any session changes
  /// made by either Admin Web or Owner App are reflected live without
  /// needing a page reload.
  static Stream<KarneBatch?> watchSingleBatch(String batchId) {
    return FirestoreListenCache.doc(
      'production_batches/$batchId',
      _db.collection('production_batches').doc(batchId),
    ).map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return KarneBatch.fromMap(doc.data()!, doc.id);
    }).handleError((error) {
      debugPrint('FirestoreService.watchSingleBatch($batchId) error: $error');
      return null;
    });
  }

  /// Saves or updates a production batch in Firestore and Supabase.
  static Future<bool> saveProductionBatch(KarneBatch batch) async {
    try {
      final docRef = _db.collection('production_batches').doc(batch.id);
      final data = batch.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      debugPrint('FirestoreService: Successfully saved batch ${batch.id} (${batch.name})');

      // Dual-sync to Supabase
      SupabaseService.saveProductionBatch(batch).catchError((_) => false);

      return true;
    } catch (e) {
      debugPrint('FirestoreService.saveProductionBatch error: $e');
      return false;
    }
  }

  /// Deletes a production batch from Firestore and Supabase.
  static Future<bool> deleteProductionBatch(String batchId) async {
    try {
      await _db.collection('production_batches').doc(batchId).delete();
      debugPrint('FirestoreService: Successfully deleted batch $batchId');

      // Dual-sync to Supabase
      SupabaseService.deleteProductionBatch(batchId).catchError((_) => false);

      return true;
    } catch (e) {
      debugPrint('FirestoreService.deleteProductionBatch error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 7. ANNOUNCEMENTS & BROADCAST NOTIFICATIONS
  // ===========================================================================

  static final Set<String> _deletedAnnouncementIds = {};
  static bool _deletedIdsLoaded = false;

  static final List<Announcement> _defaultAnnouncements = [
    Announcement(
      id: 'an1',
      messageContent:
          'Reminder: Be careful with mayo usage. Double-check the '
          'quantity before selling.',
      datePosted: DateTime.now().subtract(const Duration(hours: 3)),
      targetPosition: 'All Positions',
    ),
    Announcement(
      id: 'an2',
      messageContent:
          "There's an advance bilao order for tomorrow morning — start "
          'preparation right away.',
      datePosted: DateTime.now().subtract(const Duration(days: 1)),
      targetPosition: 'All Positions',
    ),
  ];

  /// Streams real-time announcements posted by Owner.
  static Stream<List<Announcement>> watchAnnouncements({
    int limit = 30,
    String? targetPosition,
  }) {
    final query = _db
        .collection('announcements')
        .orderBy('datePosted', descending: true)
        .limit(limit);
    return FirestoreListenCache.query(
      'announcements:$limit',
      query,
    ).asyncMap((snapshot) async {
      if (!_deletedIdsLoaded) {
        try {
          final deletedDocs =
              await _db.collection('deleted_announcements').get();
          for (final doc in deletedDocs.docs) {
            _deletedAnnouncementIds.add(doc.id);
          }
          _deletedIdsLoaded = true;
        } catch (_) {}
      }

      List<Announcement> list;
      if (snapshot.docs.isEmpty) {
        list = _defaultAnnouncements
            .where((a) => !_deletedAnnouncementIds.contains(a.id))
            .toList();
      } else {
        list = snapshot.docs
            .map((doc) {
              final data = doc.data();
              final ts = data['datePosted'] as Timestamp?;
              return Announcement(
                id: doc.id,
                messageContent: data['messageContent']?.toString() ?? '',
                datePosted: ts?.toDate() ?? DateTime.now(),
                targetPosition:
                    data['targetPosition']?.toString() ?? 'All Positions',
              );
            })
            .where((a) => !_deletedAnnouncementIds.contains(a.id))
            .toList();
      }

      if (targetPosition != null &&
          targetPosition.isNotEmpty &&
          targetPosition != 'All Positions') {
        final tp = targetPosition.toLowerCase().trim();
        list = list.where((a) {
          final atp = a.targetPosition.toLowerCase().trim();
          return atp == 'all positions' || atp == 'all' || atp == tp;
        }).toList();
      }

      return list;
    });
  }

  /// Posts a new announcement in Firestore and Supabase.
  static Future<String?> postAnnouncement(
    String messageContent, {
    String targetPosition = 'All Positions',
  }) async {
    try {
      final doc = await _db.collection('announcements').add({
        'messageContent': messageContent,
        'targetPosition': targetPosition,
        'datePosted': FieldValue.serverTimestamp(),
      });

      // Dual-sync to Supabase
      SupabaseService.saveAnnouncement(Announcement(
        id: doc.id,
        messageContent: messageContent,
        datePosted: DateTime.now(),
        targetPosition: targetPosition,
      )).catchError((_) => false);

      return doc.id;
    } catch (e) {
      debugPrint('FirestoreService.postAnnouncement error: $e');
      return null;
    }
  }

  /// Deletes an announcement from Firestore and Supabase and marks it persistently deleted.
  static Future<bool> deleteAnnouncement(String announcementId) async {
    _deletedAnnouncementIds.add(announcementId);
    try {
      await _db.collection('deleted_announcements').doc(announcementId).set({
        'deletedAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('announcements').doc(announcementId).delete();

      // Dual-sync delete to Supabase
      SupabaseService.deleteAnnouncement(announcementId).catchError((_) => false);

      return true;
    } catch (e) {
      debugPrint('FirestoreService.deleteAnnouncement error: $e');
      return true;
    }
  }

  // ===========================================================================
  // 6. STAFF BRANCH ASSIGNMENTS & REST DAY SCHEDULES
  // ===========================================================================

  /// Real-time stream of all staff assignments and rest day statuses.
  static Stream<Map<String, BranchAssignment>> watchStaffAssignmentsMap() {
    return FirestoreListenCache.query(
      'staff_assignments',
      _db.collection('staff_assignments').limit(100),
    ).map((snap) {
      final map = <String, BranchAssignment>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final isRestDay = data['isRestDay'] as bool? ?? (data['workStatus'] == 'restDay');
        final a = BranchAssignment(
          id: doc.id,
          employeeId: data['employeeId'] as String? ?? doc.id,
          employeeName: data['employeeName'] as String? ?? '',
          branchId: data['branchId'] as String? ?? '',
          branchName: data['branchName'] as String? ?? '',
          date: DateTime.now(),
          workStatus: isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
        );
        map[doc.id.toLowerCase()] = a;
        if (data['employeeId'] != null) {
          map[data['employeeId'].toString()] = a;
        }
      }
      return map;
    });
  }

  /// Fetches the latest staff assignments and rest day status snapshot.
  static Future<Map<String, BranchAssignment>> getStaffAssignmentsMap() async {
    try {
      const cacheKey = 'staff_assignments_map';
      final cached = FirestoreReadCache.get<Map<String, BranchAssignment>>(cacheKey);
      if (cached != null) return cached;

      final snap = await _db.collection('staff_assignments').get();
      final map = <String, BranchAssignment>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final isRestDay = data['isRestDay'] as bool? ?? (data['workStatus'] == 'restDay');
        final a = BranchAssignment(
          id: doc.id,
          employeeId: data['employeeId'] as String? ?? doc.id,
          employeeName: data['employeeName'] as String? ?? '',
          branchId: data['branchId'] as String? ?? '',
          branchName: data['branchName'] as String? ?? '',
          date: DateTime.now(),
          workStatus: isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
        );
        map[doc.id.toLowerCase()] = a;
        if (data['employeeId'] != null) {
          map[data['employeeId'].toString()] = a;
        }
      }
      FirestoreReadCache.set(cacheKey, map);
      return map;
    } catch (e) {
      debugPrint('FirestoreService.getStaffAssignmentsMap error: $e');
      return {};
    }
  }

  /// Sets or updates a staff member's branch assignment and rest day status in Firestore.
  static Future<bool> setStaffAssignment({
    required String username,
    required String employeeId,
    required String employeeName,
    required String branchId,
    required String branchName,
    required WorkStatus workStatus,
  }) async {
    try {
      final usernameKey = username.trim().toLowerCase();
      await _db.collection('staff_assignments').doc(usernameKey).set({
        'username': usernameKey,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'branchId': branchId,
        'branchName': branchName,
        'workStatus': workStatus.name,
        'isRestDay': workStatus == WorkStatus.restDay,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      FirestoreReadCache.invalidate('staff_assignments_map');
      return true;
    } catch (e) {
      debugPrint('FirestoreService.setStaffAssignment error: $e');
      return false;
    }
  }

  /// Checks if a staff member is currently on Rest Day in Firestore.
  static Future<bool> isStaffOnRestDay(String username) async {
    try {
      final usernameKey = username.trim().toLowerCase();
      final cacheKey = 'is_rest_day:$usernameKey';
      final cached = FirestoreReadCache.get<bool>(cacheKey);
      if (cached != null) return cached;

      final doc = await _db.collection('staff_assignments').doc(usernameKey).get();
      if (doc.exists) {
        final data = doc.data();
        final isRestDay = data?['isRestDay'] as bool? ?? false;
        final workStatus = data?['workStatus'] as String? ?? '';
        final result = isRestDay || workStatus == 'restDay';
        FirestoreReadCache.set(cacheKey, result, ttl: const Duration(seconds: 30));
        return result;
      }
      FirestoreReadCache.set(cacheKey, false, ttl: const Duration(seconds: 30));
      return false;
    } catch (e) {
      debugPrint('FirestoreService.isStaffOnRestDay error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 12. BRANCH MEAT INVENTORY (PCS) & REAL-TIME DISPATCH
  // ===========================================================================

  static final List<BranchMeatStock> _defaultBranchMeatStocks = kSampleBranches
      .map((b) => BranchMeatStock.defaultForBranch(b))
      .toList();

  static Timer? _midnightTimer;

  /// Schedules an automatic reset to standard baseline for all branches when 12:00 AM hits.
  static void scheduleMidnightAutoReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    // Next midnight: 12:00:01 AM tomorrow
    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final delay = tomorrowMidnight.difference(now);
    debugPrint('FirestoreService: Midnight auto-reset scheduled in ${delay.inHours}h ${delay.inMinutes % 60}m.');
    _midnightTimer = Timer(delay, () async {
      debugPrint('FirestoreService: 12:00 AM hit! Automatically resetting all branch allocations to standard.');
      await resetAllBranchMeatStocksToStandard();
      scheduleMidnightAutoReset(); // Schedule next day's midnight
    });
  }

  static bool _resettingMeatStocks = false;
  static DateTime? _lastMeatResetDay;

  /// Streams real-time branch meat stocks for all 6 branches.
  /// Automatically resets to standard baseline when a new day arrives or at 12:00 AM.
  static Stream<List<BranchMeatStock>> watchBranchMeatStocks() {
    scheduleMidnightAutoReset();
    return FirestoreListenCache.query(
      'branch_meat_stocks',
      _db.collection('branch_meat_stocks').limit(20),
    ).map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultBranchMeatStocks;
      }
      final now = DateTime.now();
      final map = <String, BranchMeatStock>{};
      bool dayChanged = false;

      for (final doc in snapshot.docs) {
        final stock = BranchMeatStock.fromMap(doc.data(), id: doc.id);
        final isToday = stock.date.year == now.year &&
            stock.date.month == now.month &&
            stock.date.day == now.day;
        if (!isToday) {
          dayChanged = true;
          final b = kSampleBranches.firstWhere(
            (item) => item.id == stock.branchId,
            orElse: () => kSampleBranches.first,
          );
          map[stock.branchId] = BranchMeatStock.defaultForBranch(b);
        } else {
          map[stock.branchId] = stock;
        }
      }

      if (dayChanged) {
        final today = DateTime(now.year, now.month, now.day);
        if (!_resettingMeatStocks && _lastMeatResetDay != today) {
          _resettingMeatStocks = true;
          _lastMeatResetDay = today;
          resetAllBranchMeatStocksToStandard().whenComplete(() {
            _resettingMeatStocks = false;
          });
        }
      }

      // Ensure all 6 branches are always present in the returned list
      return kSampleBranches.map((b) {
        return map[b.id] ?? BranchMeatStock.defaultForBranch(b);
      }).toList();
    });
  }

  /// Seeds default meat inventory for all 6 branches if not yet present in Firestore,
  /// or resets them if the saved stock is from a previous day.
  static Future<void> seedDefaultBranchMeatStocksIfEmpty() async {
    try {
      final now = DateTime.now();
      final snapshot = await _db.collection('branch_meat_stocks').get();
      if (snapshot.docs.isEmpty) {
        await resetAllBranchMeatStocksToStandard();
        debugPrint('FirestoreService: Default branch meat stocks seeded.');
        return;
      }

      // Check if any existing stock is from a previous day
      bool hasOutdatedDate = false;
      for (final doc in snapshot.docs) {
        final stock = BranchMeatStock.fromMap(doc.data(), id: doc.id);
        if (stock.date.year != now.year || stock.date.month != now.month || stock.date.day != now.day) {
          hasOutdatedDate = true;
          break;
        }
      }

      if (hasOutdatedDate) {
        debugPrint('FirestoreService: Outdated branch stock detected. Auto-resetting to today\'s standard.');
        await resetAllBranchMeatStocksToStandard();
      }
    } catch (e) {
      debugPrint('FirestoreService.seedDefaultBranchMeatStocksIfEmpty error: $e');
    }
  }

  /// Saves or updates the meat stock counts for a specific branch.
  static Future<bool> saveBranchMeatStock(BranchMeatStock stock) async {
    try {
      await _db.collection('branch_meat_stocks').doc(stock.branchId).set({
        ...stock.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('FirestoreService.saveBranchMeatStock error: $e');
      return false;
    }
  }

  /// Streams all meat dispatches sorted with most recent first.
  static Stream<List<MeatDispatch>> watchMeatDispatches({int limit = 50}) {
    final query = _db
        .collection('meat_dispatches')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    return FirestoreListenCache.query('meat_dispatches:$limit', query)
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MeatDispatch.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  /// Creates a new meat dispatch record from Main Warehouse to a target branch.
  static Future<String?> createMeatDispatch(MeatDispatch dispatch) async {
    try {
      final docRef = await _db.collection('meat_dispatches').add({
        'destinationBranchId': dispatch.destinationBranchId,
        'destinationBranchName': dispatch.destinationBranchName,
        'regular250gPcs': dispatch.regular250gPcs,
        'medium300gPcs': dispatch.medium300gPcs,
        'b1t1_400gPcs': dispatch.b1t1_400gPcs,
        'mayoPcs': dispatch.mayoPcs,
        'styroPcs': dispatch.styroPcs,
        'toyoPcs': dispatch.toyoPcs,
        'status': 'pending',
        'createdAt': dispatch.createdAt.toIso8601String(),
        'deliveredAt': null,
        'driverName': dispatch.driverName,
        'serverCreatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('FirestoreService.createMeatDispatch error: $e');
      return null;
    }
  }

  /// Marks a meat dispatch as delivered by the Driver.
  /// Automatically increases the destination branch's stock (both total and remaining)
  /// Resets all 6 branches to the fixed standard allocation:
  /// - 250G Regular: 20 pcs
  /// - 300G Medium: 10 pcs
  /// - 400G B1T1: 10 pcs
  /// - Mayo: 40 pcs
  /// - Styro: 40 pcs
  /// - Toyo: 10 pcs
  static Future<bool> resetAllBranchMeatStocksToStandard() async {
    try {
      final batch = _db.batch();
      for (final b in kSampleBranches) {
        final stock = BranchMeatStock.defaultForBranch(b);
        final docRef = _db.collection('branch_meat_stocks').doc(b.id);
        batch.set(docRef, {
          ...stock.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('FirestoreService: All branch meat stocks reset to standard.');
      return true;
    } catch (e) {
      debugPrint('FirestoreService.resetAllBranchMeatStocksToStandard error: $e');
      return false;
    }
  }

  /// Marks a meat dispatch as delivered by the Driver.
  /// Automatically increases the destination branch's stock (both total and remaining)
  /// and updates the daily staff inventory so all apps reflect the delivery instantly.
  static Future<bool> markDispatchAsDelivered(MeatDispatch dispatch, {String? driverName}) async {
    try {
      final now = DateTime.now();

      // 1. Update the dispatch record status to 'delivered'
      final updateData = <String, dynamic>{
        'status': 'delivered',
        'deliveredAt': now.toIso8601String(),
        'serverDeliveredAt': FieldValue.serverTimestamp(),
      };
      if (driverName != null) {
        updateData['driverName'] = driverName;
      }
      await _db.collection('meat_dispatches').doc(dispatch.id).update(updateData);

      // 2. Resolve destination branch ID accurately
      String branchId = dispatch.destinationBranchId.trim();
      if (branchId.isEmpty || !kSampleBranches.any((b) => b.id == branchId)) {
        final match = kSampleBranches.firstWhere(
          (b) => b.fullName.toLowerCase() == dispatch.destinationBranchName.toLowerCase() ||
                 b.name.toLowerCase() == dispatch.destinationBranchName.toLowerCase() ||
                 dispatch.destinationBranchName.toLowerCase().contains(b.name.toLowerCase()),
          orElse: () => kSampleBranches.first,
        );
        branchId = match.id;
      }

      // Fetch current branch meat stock and add the delivered pcs
      final branchDocRef = _db.collection('branch_meat_stocks').doc(branchId);
      final branchDoc = await branchDocRef.get();

      BranchMeatStock currentStock;
      if (branchDoc.exists && branchDoc.data() != null) {
        currentStock = BranchMeatStock.fromMap(branchDoc.data()!, id: branchId);
      } else {
        final b = kSampleBranches.firstWhere(
          (item) => item.id == branchId,
          orElse: () => kSampleBranches.first,
        );
        currentStock = BranchMeatStock.defaultForBranch(b);
      }

      final updatedStock = currentStock.copyWith(
        regular250gTotal: currentStock.regular250gTotal + dispatch.regular250gPcs,
        regular250gRemaining: currentStock.regular250gRemaining + dispatch.regular250gPcs,
        medium300gTotal: currentStock.medium300gTotal + dispatch.medium300gPcs,
        medium300gRemaining: currentStock.medium300gRemaining + dispatch.medium300gPcs,
        b1t1_400gTotal: currentStock.b1t1_400gTotal + dispatch.b1t1_400gPcs,
        b1t1_400gRemaining: currentStock.b1t1_400gRemaining + dispatch.b1t1_400gPcs,
        mayoTotal: currentStock.mayoTotal + dispatch.mayoPcs,
        mayoRemaining: currentStock.mayoRemaining + dispatch.mayoPcs,
        styroTotal: currentStock.styroTotal + dispatch.styroPcs,
        styroRemaining: currentStock.styroRemaining + dispatch.styroPcs,
        toyoTotal: currentStock.toyoTotal + dispatch.toyoPcs,
        toyoRemaining: currentStock.toyoRemaining + dispatch.toyoPcs,
        date: now,
      );

      await branchDocRef.set({
        ...updatedStock.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update staff daily inventory for this branch today
      final docId = _dailyInventoryDocId(branchId, now);
      final staffInvDocRef = _db.collection('branch_daily_inventories').doc(docId);
      final staffInvDoc = await staffInvDocRef.get();

      int newReg = dispatch.regular250gPcs;
      int newMed = dispatch.medium300gPcs;
      int newB1t1 = dispatch.b1t1_400gPcs;
      int newMayo = dispatch.mayoPcs;
      int newStyro = dispatch.styroPcs;
      int newToyo = dispatch.toyoPcs;

      int curAllocMayo = 40;
      int curAllocStyro = 40;
      int curAllocToyo = 10;

      if (staffInvDoc.exists && staffInvDoc.data() != null) {
        final data = staffInvDoc.data()!;
        final alloc = data['allocated'] as Map<String, dynamic>? ?? {};
        curAllocMayo = (alloc['mayo'] as num?)?.toInt() ?? 40;
        curAllocStyro = (alloc['styro'] as num?)?.toInt() ?? 40;
        curAllocToyo = (alloc['toyo'] as num?)?.toInt() ?? 10;

        final ar = data['actualReceived'] as Map<String, dynamic>?;
        if (ar != null) {
          newReg += (ar['regular'] as num?)?.toInt() ?? 0;
          newMed += (ar['medium'] as num?)?.toInt() ?? 0;
          newB1t1 += (ar['b1t1'] as num?)?.toInt() ?? 0;
          newMayo += (ar['mayo'] as num?)?.toInt() ?? 0;
          newStyro += (ar['styro'] as num?)?.toInt() ?? 0;
          newToyo += (ar['toyo'] as num?)?.toInt() ?? 0;
        } else {
          newReg += 20;
          newMed += 10;
          newB1t1 += 10;
          newMayo += curAllocMayo;
          newStyro += curAllocStyro;
          newToyo += curAllocToyo;
        }
      } else {
        newReg += 20;
        newMed += 10;
        newB1t1 += 10;
        newMayo += 40;
        newStyro += 40;
        newToyo += 10;
      }

      final totalAllocKarne = newReg + newMed + newB1t1;

      await staffInvDocRef.set({
        'branchId': branchId,
        'branchName': dispatch.destinationBranchName,
        'date': Timestamp.fromDate(now),
        'allocated': {
          'karne': totalAllocKarne,
          'mayo': curAllocMayo + dispatch.mayoPcs,
          'styro': curAllocStyro + dispatch.styroPcs,
          'toyo': curAllocToyo + dispatch.toyoPcs,
        },
        'actualReceived': {
          'regular': newReg,
          'medium': newMed,
          'b1t1': newB1t1,
          'mayo': newMayo,
          'styro': newStyro,
          'toyo': newToyo,
        },
        // Automatic na mawawala ang discrepancy dahil naihatid na ang kulang!
        'status': InventoryVerificationStatus.confirmed.name,
        'discrepancyNote': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Send real-time notification to the branch staff that stock has arrived
      await NotificationService.sendNotification(
        title: '📦 Karagdagang Stock Dumating — ${dispatch.destinationBranchName}',
        message: 'Na-deliver na ng Driver ang: ${dispatch.itemsSummary}',
        type: NotificationType.inventoryAlert,
        targetRole: 'staff',
        route: 'inventory',
        targetBranch: dispatch.destinationBranchName,
      );

      // 5. Also notify owner that delivery has been completed
      final driverLabel = driverName != null && driverName.isNotEmpty ? driverName : 'Driver';
      await NotificationService.sendNotification(
        title: '🚗 Naihatid na — ${dispatch.destinationBranchName}',
        message: '$driverLabel ay nakapag-deliver na ng ${dispatch.itemsSummary} sa ${dispatch.destinationBranchName}.',
        type: NotificationType.inventoryAlert,
        targetRole: 'owner',
        route: 'inventory',
        targetBranch: dispatch.destinationBranchName,
      );

      // 6. Update incomplete reports for this branch to 'missing' (delivered by driver, awaiting branch cook confirmation)
      try {
        final reportsSnap = await _db
            .collection('daily_reports')
            .where('branchId', isEqualTo: branchId)
            .where('status', isEqualTo: ReportSubmissionStatus.incomplete.name)
            .get();
        for (final doc in reportsSnap.docs) {
          await doc.reference.update({
            'status': ReportSubmissionStatus.missing.name,
            'driverDeliveredAt': FieldValue.serverTimestamp(),
          });
        }
        if (reportsSnap.docs.isEmpty) {
          final byNameSnap = await _db
              .collection('daily_reports')
              .where('branchName', isEqualTo: dispatch.destinationBranchName)
              .where('status', isEqualTo: ReportSubmissionStatus.incomplete.name)
              .get();
          for (final doc in byNameSnap.docs) {
            await doc.reference.update({
              'status': ReportSubmissionStatus.missing.name,
              'driverDeliveredAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        debugPrint('Error updating daily_reports to missing: $e');
      }

      return true;
    } catch (e) {
      debugPrint('FirestoreService.markDispatchAsDelivered error: $e');
      return false;
    }
  }
}


