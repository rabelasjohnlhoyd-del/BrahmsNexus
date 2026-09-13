import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/announcement.dart';
import '../models/bilao_order.dart';
import '../models/branch_daily_inventory.dart';
import '../models/daily_report.dart';
import '../models/inventory_batch.dart';
import '../models/sales_record.dart';

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
    return _db
        .collection('bilao_orders')
        .orderBy('scheduledDateTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultBilaoOrders;
      }
      return snapshot.docs.map((doc) => _bilaoFromDoc(doc)).toList();
    });
  }

  /// Stream of active orders for drivers/dispatch.
  static Stream<List<BilaoOrder>> watchActiveBilaoOrders() {
    return _db
        .collection('bilao_orders')
        .where('deliveryStatus', whereIn: ['forDelivery'])
        .orderBy('scheduledDateTime', descending: false)
        .limit(25) // Strict boundary to protect reads
        .snapshots()
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

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => _bilaoFromDoc(doc)).toList();
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
    return _db.collection('branch_daily_inventories').doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final data = snapshot.data()!;
      final allocated = data['allocated'] as Map<String, dynamic>? ?? {};

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
      );
    });
  }

  /// Sets or updates the daily inventory verification.
  static Future<bool> saveDailyInventory(BranchDailyInventory record) async {
    final docId = _dailyInventoryDocId(record.branchId, record.date);
    try {
      await _db.collection('branch_daily_inventories').doc(docId).set({
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
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('FirestoreService.saveDailyInventory error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 3. DAILY SALES & EMPLOYEE EARNINGS
  // ===========================================================================

  /// Saves the end-of-day sales record submitted by a branch cook.
  static Future<bool> submitDailySales(SalesRecord sales) async {
    try {
      await _db.collection('daily_sales').add({
        'branchId': sales.branchId,
        'branchName': sales.branchName,
        'employeeId': sales.employeeId,
        'employeeName': sales.employeeName,
        'date': Timestamp.fromDate(sales.date),
        'portionsSold': sales.portionsSold,
        'commissionRatePerPortion': sales.commissionRatePerPortion,
        'totalSalesAmount': sales.totalSalesAmount,
        'computedWage': sales.computedWage,
        'expectedCashRemittance': sales.expectedCashRemittance,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('FirestoreService.submitDailySales error: $e');
      return false;
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
    return _db
        .collection('daily_sales')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultSalesRecords;
      }
      return snapshot.docs.map((doc) {
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
    try {
      final from = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await _db
          .collection('daily_sales')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
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
        );
      }).toList();
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
    return _db
        .collection('daily_reports')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
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
        );
      }).toList();
    });
  }

  /// Saves an employee daily incident report in Firestore.
  static Future<bool> submitDailyReport(DailyReport report) async {
    try {
      await _db.collection('daily_reports').add({
        'employeeId': report.employeeId,
        'employeeName': report.employeeName,
        'branchId': report.branchId,
        'branchName': report.branchName,
        'date': Timestamp.fromDate(report.date),
        'content': report.content,
        'status': report.status.name,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('FirestoreService.submitDailyReport error: $e');
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

  /// Streams real-time production batches from Firestore.
  /// Falls back to default batches if none exist yet.
  static Stream<List<KarneBatch>> watchProductionBatches({int limit = 20}) {
    return _db
        .collection('production_batches')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultBatches;
      }
      return snapshot.docs
          .map((doc) => KarneBatch.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Saves or updates a production batch in Firestore.
  static Future<bool> saveProductionBatch(KarneBatch batch) async {
    try {
      final docRef = _db.collection('production_batches').doc(batch.id);
      final data = batch.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();

      final existing = await docRef.get();
      if (!existing.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await docRef.set(data, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('FirestoreService.saveProductionBatch error: $e');
      return false;
    }
  }

  /// Deletes a production batch from Firestore.
  static Future<bool> deleteProductionBatch(String batchId) async {
    try {
      await _db.collection('production_batches').doc(batchId).delete();
      return true;
    } catch (e) {
      debugPrint('FirestoreService.deleteProductionBatch error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 7. ANNOUNCEMENTS & BROADCAST NOTIFICATIONS
  // ===========================================================================

  static final List<Announcement> _defaultAnnouncements = [
    Announcement(
      id: 'an1',
      messageContent:
          'Reminder: Be careful with mayo usage. Double-check the '
          'quantity before selling.',
      datePosted: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Announcement(
      id: 'an2',
      messageContent:
          "There's an advance bilao order for tomorrow morning — start "
          'preparation right away.',
      datePosted: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Streams real-time announcements posted by Owner.
  static Stream<List<Announcement>> watchAnnouncements({int limit = 30}) {
    return _db
        .collection('announcements')
        .orderBy('datePosted', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _defaultAnnouncements;
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['datePosted'] as Timestamp?;
        return Announcement(
          id: doc.id,
          messageContent: data['messageContent']?.toString() ?? '',
          datePosted: ts?.toDate() ?? DateTime.now(),
        );
      }).toList();
    });
  }

  /// Posts a new announcement in Firestore.
  static Future<String?> postAnnouncement(String messageContent) async {
    try {
      final doc = await _db.collection('announcements').add({
        'messageContent': messageContent,
        'datePosted': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      debugPrint('FirestoreService.postAnnouncement error: $e');
      return null;
    }
  }

  /// Deletes an announcement from Firestore.
  static Future<bool> deleteAnnouncement(String announcementId) async {
    try {
      await _db.collection('announcements').doc(announcementId).delete();
      return true;
    } catch (e) {
      debugPrint('FirestoreService.deleteAnnouncement error: $e');
      return false;
    }
  }
}

