import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/announcement.dart';
import '../models/branch.dart';
import '../models/branch_daily_inventory.dart';
import '../models/daily_report.dart';
import '../models/inventory_batch.dart';
import '../models/sales_record.dart';
import '../models/staff_member.dart';

/// Container for paginated data results.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<T> items;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages => (totalCount / pageSize).ceil().clamp(1, 99999);
  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}

/// Service dedicated to handling static, master, and infrequent-write data
/// in Supabase (PostgreSQL).
///
/// Moving user personal profiles, branch master directory, and packages here
/// ensures zero read quota consumption and zero document storage cost on Firebase.
class SupabaseService {
  const SupabaseService._();

  static SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isAvailable => _client != null;

  // Local in-memory caches to guarantee smooth operation even before
  // real Supabase credentials are provided or when offline.
  static final List<Branch> _inMemoryBranches = List.from(kSampleBranches);
  static final List<StaffMember> _inMemoryStaff = List.from(kSampleStaff);

  // ===========================================================================
  // 1. BRANCH MANAGEMENT (Static Master Directory)
  // ===========================================================================

  static DateTime? _branchesCacheTime;
  static const Duration _branchesCacheTtl = Duration(minutes: 5);

  /// Fetches all branches ordered by route sequence, with a 5-minute memory cache
  /// to eliminate unnecessary network queries during frequent screen navigation.
  static Future<List<Branch>> getBranches({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _branchesCacheTime != null &&
        now.difference(_branchesCacheTime!) < _branchesCacheTtl &&
        _inMemoryBranches.isNotEmpty) {
      return getAllBranchesSync();
    }

    final client = _client;
    if (client == null) {
      return getAllBranchesSync();
    }

    try {
      final data = await client
          .from('branches')
          .select()
          .order('daily_route_sequence', ascending: true);

      final list = (data as List).map((row) => Branch.fromMap(row)).toList();
      if (list.isNotEmpty) {
        _inMemoryBranches
          ..clear()
          ..addAll(list);
        _branchesCacheTime = DateTime.now();
        return getAllBranchesSync();
      }
      return getAllBranchesSync();
    } catch (e) {
      debugPrint('SupabaseService.getBranches error: $e. Falling back to local cache.');
      return getAllBranchesSync();
    }
  }

  /// Returns currently loaded branches synchronously from memory.
  static List<Branch> getAllBranchesSync() {
    final list = List<Branch>.from(_inMemoryBranches);
    list.sort((a, b) => a.dailyRouteSequence.compareTo(b.dailyRouteSequence));
    return list;
  }

  /// Inserts or updates a branch record.
  static Future<bool> saveBranch(Branch branch) async {
    _branchesCacheTime = null; // Invalidate cache immediately on edit
    final index = _inMemoryBranches.indexWhere((b) => b.id == branch.id);
    if (index >= 0) {
      _inMemoryBranches[index] = branch;
    } else {
      _inMemoryBranches.add(branch);
    }

    final client = _client;
    if (client == null) return true;

    try {
      await client.from('branches').upsert(branch.toMap());
      return true;
    } catch (e) {
      debugPrint('SupabaseService.saveBranch error: $e');
      return false;
    }
  }

  /// Deletes a branch by ID.
  static Future<bool> deleteBranch(String branchId) async {
    _branchesCacheTime = null; // Invalidate cache immediately on delete
    _inMemoryBranches.removeWhere((b) => b.id == branchId);

    final client = _client;
    if (client == null) return true;

    try {
      await client.from('branches').delete().eq('id', branchId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteBranch error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 2. STAFF PROFILE MANAGEMENT (Static Personal Master Records)
  // ===========================================================================

  /// Server-side paginated, sorted, and filtered staff query.
  /// - [page]: 1-indexed page number
  /// - [pageSize]: number of records per page (default 10)
  /// - [query]: search term matching name or username
  /// - [showArchived]: toggle between active vs archived staff
  /// - [branchFilter]: filter by specific branch (optional)
  /// - [positionFilter]: filter by role/position (optional)
  static Future<PaginatedResponse<StaffMember>> getStaffProfiles({
    int page = 1,
    int pageSize = 5,
    String query = '',
    bool showArchived = false,
    String? branchFilter,
    String? positionFilter,
  }) async {
    final client = _client;
    if (client == null) {
      return _localPaginatedStaff(
        page: page,
        pageSize: pageSize,
        query: query,
        showArchived: showArchived,
        branchFilter: branchFilter,
        positionFilter: positionFilter,
      );
    }

    try {
      final start = (page - 1) * pageSize;
      final end = start + pageSize - 1;

      var queryBuilder = client
          .from('staff_profiles')
          .select()
          .eq('is_archived', showArchived);

      if (query.trim().isNotEmpty) {
        final q = query.trim();
        queryBuilder = queryBuilder.or(
          'first_name.ilike.%$q%,last_name.ilike.%$q%,username.ilike.%$q%,position.ilike.%$q%',
        );
      }
      if (branchFilter != null && branchFilter != 'All') {
        queryBuilder = queryBuilder.eq('branch_name', branchFilter);
      }
      if (positionFilter != null && positionFilter != 'All') {
        queryBuilder = queryBuilder.eq('position', positionFilter);
      }

      final data = await queryBuilder
          .order('date_added', ascending: false)
          .range(start, end);

      final items = (data as List)
          .map((map) => StaffMember.fromMap(map as Map<String, dynamic>))
          .toList();

      // If remote Supabase table is empty or has not been seeded yet, fallback to in-memory staff
      if (items.isEmpty && _inMemoryStaff.isNotEmpty && !showArchived && query.isEmpty && branchFilter == null) {
        return _localPaginatedStaff(
          page: page,
          pageSize: pageSize,
          query: query,
          showArchived: showArchived,
          branchFilter: branchFilter,
          positionFilter: positionFilter,
        );
      }

      int totalCount = items.length;
      try {
        final countRes = await client
            .from('staff_profiles')
            .count(CountOption.exact)
            .eq('is_archived', showArchived);
        totalCount = countRes;
      } catch (_) {
        totalCount = items.length >= pageSize
            ? (page * pageSize + 1)
            : ((page - 1) * pageSize + items.length);
      }

      return PaginatedResponse(
        items: items,
        totalCount: totalCount,
        currentPage: page,
        pageSize: pageSize,
      );
    } catch (e) {
      debugPrint('SupabaseService.getStaffProfiles error: $e. Falling back to local staff directory.');
      return _localPaginatedStaff(
        page: page,
        pageSize: pageSize,
        query: query,
        showArchived: showArchived,
        branchFilter: branchFilter,
        positionFilter: positionFilter,
      );
    }
  }

  static PaginatedResponse<StaffMember> _localPaginatedStaff({
    int page = 1,
    int pageSize = 10,
    String query = '',
    bool showArchived = false,
    String? branchFilter,
    String? positionFilter,
  }) {
    var filtered = _inMemoryStaff.where((s) => s.isArchived == showArchived).toList();
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((s) {
        return s.fullName.toLowerCase().contains(q) ||
            s.username.toLowerCase().contains(q) ||
            s.branch.toLowerCase().contains(q) ||
            s.position.toLowerCase().contains(q);
      }).toList();
    }
    if (branchFilter != null && branchFilter != 'All') {
      filtered = filtered.where((s) => s.branch == branchFilter).toList();
    }
    if (positionFilter != null && positionFilter != 'All') {
      filtered = filtered.where((s) => s.position == positionFilter).toList();
    }

    final total = filtered.length;
    final start = (page - 1) * pageSize;
    if (start >= total) {
      return PaginatedResponse(
        items: [],
        totalCount: total,
        currentPage: page,
        pageSize: pageSize,
      );
    }
    final end = (start + pageSize) > total ? total : (start + pageSize);
    return PaginatedResponse(
      items: filtered.sublist(start, end),
      totalCount: total,
      currentPage: page,
      pageSize: pageSize,
    );
  }

  /// Inserts a new staff member profile into Supabase.
  static Future<bool> createStaffProfile(StaffMember staff) async {
    _inMemoryStaff.insert(0, staff);

    final client = _client;
    if (client == null) return true;

    try {
      await client.from('staff_profiles').insert(staff.toMap());
      return true;
    } catch (e) {
      debugPrint('SupabaseService.createStaffProfile error: $e');
      return false;
    }
  }

  /// Updates an existing staff member profile in Supabase.
  static Future<bool> updateStaffProfile(StaffMember staff) async {
    final index = _inMemoryStaff.indexWhere((s) => s.id == staff.id);
    if (index >= 0) {
      _inMemoryStaff[index] = staff;
    }

    final client = _client;
    if (client == null) return true;

    try {
      await client
          .from('staff_profiles')
          .update(staff.toMap())
          .eq('id', staff.id);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateStaffProfile error: $e');
      return false;
    }
  }

  /// Returns all staff in the in-memory cache.
  static List<StaffMember> getAllStaff() => List.unmodifiable(_inMemoryStaff);

  /// Checks if a staff member is active and not archived by username, ID, or full name.
  static bool isStaffActive({String? username, String? staffId, String? fullName}) {
    final member = _inMemoryStaff.firstWhere(
      (s) => (username != null && s.username.toLowerCase() == username.toLowerCase().trim()) ||
             (staffId != null && s.id == staffId) ||
             (fullName != null && s.fullName.toLowerCase() == fullName.toLowerCase().trim()),
      orElse: () => StaffMember(
        id: '',
        firstName: '',
        lastName: '',
        username: '',
        branch: '',
        position: '',
        isActive: true,
        isArchived: false,
      ),
    );
    if (member.id.isEmpty) return true;
    return member.isActive && !member.isArchived;
  }

  /// Asynchronously checks if a staff member is active in the remote Supabase database.
  /// Falls back to local in-memory cache if offline or unconfigured.
  static Future<bool> isStaffActiveAsync({String? username, String? staffId, String? fullName}) async {
    final client = _client;
    if (client != null) {
      try {
        var queryBuilder = client.from('staff_profiles').select('is_active, is_archived');
        if (username != null && username.trim().isNotEmpty) {
          queryBuilder = queryBuilder.eq('username', username.trim().toLowerCase());
        } else if (staffId != null && staffId.trim().isNotEmpty) {
          queryBuilder = queryBuilder.eq('id', staffId.trim());
        }
        final res = await queryBuilder.limit(1);
        if (res.isNotEmpty) {
          final row = res.first;
          final isActive = row['is_active'] as bool? ?? true;
          final isArchived = row['is_archived'] as bool? ?? false;
          final active = isActive && !isArchived;

          // Keep in-memory cache synchronized with remote DB
          if (username != null) {
            final uKey = username.trim().toLowerCase();
            for (int i = 0; i < _inMemoryStaff.length; i++) {
              if (_inMemoryStaff[i].username.toLowerCase() == uKey) {
                _inMemoryStaff[i] = _inMemoryStaff[i].copyWith(isActive: active);
                break;
              }
            }
          }
          return active;
        }
      } catch (e) {
        debugPrint('SupabaseService.isStaffActiveAsync query error: $e');
      }
    }

    // Fallback to in-memory check
    return isStaffActive(username: username, staffId: staffId, fullName: fullName);
  }

  /// Toggles active status for staff.
  static Future<bool> toggleStaffActive(String staffId, bool isActive) async {
    final index = _inMemoryStaff.indexWhere((s) => s.id == staffId);
    if (index >= 0) {
      _inMemoryStaff[index] = _inMemoryStaff[index].copyWith(isActive: isActive);
    }
    final sampleIndex = kSampleStaff.indexWhere((s) => s.id == staffId);
    if (sampleIndex >= 0) {
      kSampleStaff[sampleIndex] = kSampleStaff[sampleIndex].copyWith(isActive: isActive);
    }

    final client = _client;
    if (client == null) return true;

    try {
      // 1. Try updating existing row in remote Supabase
      final updateRes = await client
          .from('staff_profiles')
          .update({'is_active': isActive})
          .eq('id', staffId)
          .select('id');

      // 2. If row was not present in remote DB (e.g. static/sample staff),
      // upsert the full profile so it is permanently stored in Supabase!
      if (updateRes.isEmpty && index >= 0) {
        final staffToPersist = _inMemoryStaff[index].copyWith(isActive: isActive);
        await client.from('staff_profiles').upsert(staffToPersist.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('SupabaseService.toggleStaffActive error: $e');
      return false;
    }
  }

  /// Toggles active status for staff by username (covers staff not yet linked by UID).
  static Future<bool> toggleStaffActiveByUsername(String username, bool isActive) async {
    final usernameKey = username.trim().toLowerCase();

    // Update in-memory cache
    int foundIndex = -1;
    for (int i = 0; i < _inMemoryStaff.length; i++) {
      if (_inMemoryStaff[i].username.toLowerCase() == usernameKey) {
        _inMemoryStaff[i] = _inMemoryStaff[i].copyWith(isActive: isActive);
        foundIndex = i;
        break;
      }
    }

    final client = _client;
    if (client == null) return true;

    try {
      final updateRes = await client
          .from('staff_profiles')
          .update({'is_active': isActive})
          .eq('username', usernameKey)
          .select('id');

      // If row not present in remote DB, upsert it from in-memory cache
      if (updateRes.isEmpty && foundIndex >= 0) {
        final staffToPersist = _inMemoryStaff[foundIndex].copyWith(isActive: isActive);
        await client.from('staff_profiles').upsert(staffToPersist.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('SupabaseService.toggleStaffActiveByUsername error: $e');
      return false;
    }
  }

  static DateTime? _staffRefreshTime;
  static const Duration _staffRefreshTtl = Duration(minutes: 2);

  /// Refreshes all staff profiles from remote Supabase table into in-memory cache.
  /// Debounced to at most once every 2 minutes to prevent excessive network reads.
  static Future<List<StaffMember>> refreshStaffFromRemote({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _staffRefreshTime != null &&
        now.difference(_staffRefreshTime!) < _staffRefreshTtl &&
        _inMemoryStaff.isNotEmpty) {
      return List.from(_inMemoryStaff);
    }

    final client = _client;
    if (client == null) return List.from(_inMemoryStaff);
    try {
      final data = await client.from('staff_profiles').select();
      final list = (data as List).map((row) => StaffMember.fromMap(row as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) {
        _inMemoryStaff
          ..clear()
          ..addAll(list);
        _staffRefreshTime = DateTime.now();
      }
      return list;
    } catch (e) {
      debugPrint('SupabaseService.refreshStaffFromRemote error: $e');
      return List.from(_inMemoryStaff);
    }
  }

  /// Real-time stream of all staff profiles from Supabase.
  static Stream<List<StaffMember>> watchStaffProfiles() async* {
    // 1. Always yield the in-memory cache first so UI has something to show.
    yield List.unmodifiable(_inMemoryStaff);

    final client = _client;
    if (client == null) return;

    try {
      // 2. Subscribe to the remote stream.
      // Using await for ensures we can catch exceptions thrown by the stream itself
      // (like RealtimeSubscribeException if Realtime is not enabled on the table).
      final stream = client
          .from('staff_profiles')
          .stream(primaryKey: ['id']);

      await for (final rows in stream) {
        final list = rows.map((r) => StaffMember.fromMap(r)).toList();
        if (list.isNotEmpty) {
          _inMemoryStaff
            ..clear()
            ..addAll(list);
        }
        yield list;
      }
    } catch (e) {
      // 3. Gracefully handle subscription failures. The stream will terminate
      // but the initial yield above ensures the app is not left in an error state.
      debugPrint('Supabase Realtime unavailable for staff_profiles: $e');
    }
  }

  /// Looks up staff member by username or ID in memory cache, falling back to remote Supabase.
  static Future<StaffMember?> getStaffByUsernameOrId(String usernameOrId) async {
    final key = usernameOrId.trim().toLowerCase();
    for (final s in _inMemoryStaff) {
      if (s.username.toLowerCase() == key || s.id.toLowerCase() == key) {
        return s;
      }
    }
    final client = _client;
    if (client != null) {
      try {
        final res = await client
            .from('staff_profiles')
            .select()
            .or('username.ilike.$key,id.eq.$key')
            .limit(1);
        if ((res as List).isNotEmpty) {
          final s = StaffMember.fromMap(res.first);
          final idx = _inMemoryStaff.indexWhere((m) => m.id == s.id);
          if (idx >= 0) {
            _inMemoryStaff[idx] = s;
          } else {
            _inMemoryStaff.add(s);
          }
          return s;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Sets branch and Rest Day (rfid_tag) assignment in Supabase for cross-device synchronization.
  static Future<bool> updateStaffAssignment({
    required String staffIdOrUsername,
    required String branchName,
    required bool isRestDay,
  }) async {
    final key = staffIdOrUsername.trim().toLowerCase();

    // 1. Update in-memory cache
    String targetId = '';
    for (int i = 0; i < _inMemoryStaff.length; i++) {
      final s = _inMemoryStaff[i];
      if (s.id.toLowerCase() == key || s.username.toLowerCase() == key) {
        targetId = s.id;
        final newTag = isRestDay ? 'REST_DAY_${s.id}' : 'DUTY_${s.id}';
        _inMemoryStaff[i] = s.copyWith(
          branch: branchName.isNotEmpty ? branchName : s.branch,
          rfidTag: newTag,
          isActive: isRestDay ? s.isActive : true,
        );
        break;
      }
    }

    final client = _client;
    if (client == null) return true;

    try {
      final resolvedId = targetId.isNotEmpty ? targetId : key;
      final updateData = <String, dynamic>{
        'rfid_tag': isRestDay ? 'REST_DAY_$resolvedId' : 'DUTY_$resolvedId',
      };
      if (branchName.isNotEmpty) {
        updateData['branch_name'] = branchName;
      }
      if (!isRestDay) {
        updateData['is_active'] = true;
      }

      await client
          .from('staff_profiles')
          .update(updateData)
          .or('id.eq.$key,username.ilike.$key');
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateStaffAssignment error: $e');
      return false;
    }
  }

  /// Toggles archive status for staff.
  static Future<bool> toggleStaffArchived(String staffId, bool isArchived) async {
    final index = _inMemoryStaff.indexWhere((s) => s.id == staffId);
    if (index >= 0) {
      _inMemoryStaff[index] = _inMemoryStaff[index].copyWith(isArchived: isArchived);
    }
    final sampleIndex = kSampleStaff.indexWhere((s) => s.id == staffId);
    if (sampleIndex >= 0) {
      kSampleStaff[sampleIndex] = kSampleStaff[sampleIndex].copyWith(isArchived: isArchived);
    }

    final client = _client;
    if (client == null) return true;

    try {
      await client
          .from('staff_profiles')
          .update({'is_archived': isArchived})
          .eq('id', staffId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.toggleStaffArchived error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 3. BILAO PACKAGES MASTER PRICING (Static Catalog)
  // ===========================================================================

  static List<Map<String, dynamic>>? _cachedBilaoPackages;
  static DateTime? _bilaoPackagesCacheTime;
  static const Duration _bilaoPackagesCacheTtl = Duration(hours: 1);

  static final List<Map<String, dynamic>> _defaultBilaoPackages = [
    {
      'id': 'bp-small',
      'size': 'Small',
      'price': 650.0,
      'commission': 62.0,
      'pax': 10,
      'weight': '1 Kilo and 250 Grams',
      'description': 'Good for 10 Pax (1.25 kg)',
    },
    {
      'id': 'bp-medium',
      'size': 'Medium',
      'price': 900.0,
      'commission': 87.0,
      'pax': 15,
      'weight': '1 Kilo and 750 Grams',
      'description': 'Good for 15 Pax (1.75 kg)',
    },
    {
      'id': 'bp-large',
      'size': 'Large',
      'price': 1300.0,
      'commission': 125.0,
      'pax': 20,
      'weight': '2 Kilos and 500 Grams',
      'description': 'Good for 20 Pax (2.5 kg)',
    },
  ];

  static Future<List<Map<String, dynamic>>> getBilaoPackages() async {
    // Return from memory cache if still fresh (1 hour TTL)
    final now = DateTime.now();
    if (_cachedBilaoPackages != null &&
        _bilaoPackagesCacheTime != null &&
        now.difference(_bilaoPackagesCacheTime!) < _bilaoPackagesCacheTtl) {
      return _cachedBilaoPackages!;
    }

    final client = _client;
    if (client == null) return List.from(_defaultBilaoPackages);

    try {
      final data = await client
          .from('bilao_packages')
          .select()
          .order('price', ascending: true);
      final result = List<Map<String, dynamic>>.from(data);
      _cachedBilaoPackages = result;
      _bilaoPackagesCacheTime = now;
      return result;
    } catch (e) {
      debugPrint('SupabaseService.getBilaoPackages error: $e');
      return _cachedBilaoPackages ?? List.from(_defaultBilaoPackages);
    }
  }

  // ===========================================================================
  // 4. DAILY SALES & PAYROLL (Supabase PostgreSQL)
  // ===========================================================================

  static Map<String, dynamic> _salesRecordToMap(SalesRecord sales) {
    final rs = sales.remainingStock;
    return {
      'id': sales.id,
      'branch_id': sales.branchId,
      'branch_name': sales.branchName,
      'employee_id': sales.employeeId,
      'employee_name': sales.employeeName,
      'date': sales.date.toIso8601String(),
      'portions_sold': sales.portionsSold,
      'total_orders': sales.totalOrders ?? sales.displayTotalOrders,
      'commission_rate': sales.commissionRatePerPortion,
      'total_sales_amount': sales.totalSalesAmount,
      'wage': sales.wage ?? sales.computedWage,
      'regular_sold': sales.regularSold ?? 0,
      'medium_sold': sales.mediumSold ?? 0,
      'b1t1_sold': sales.b1t1OrdersSold ?? 0,
      'discrepancy_note': sales.discrepancyNote,
      'remaining_stock': rs != null
          ? {
              'mayo': rs.mayo,
              'toyo': rs.toyo,
              'styro': rs.styro,
              'regular': rs.regular,
              'medium': rs.medium,
              'b1t1': rs.b1t1,
            }
          : null,
    };
  }

  static SalesRecord _salesRecordFromMap(Map<String, dynamic> row) {
    final rs = row['remaining_stock'] as Map<String, dynamic>?;
    DateTime parsedDate;
    final rawDate = row['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return SalesRecord(
      id: row['id']?.toString() ?? '',
      branchId: row['branch_id']?.toString() ?? '',
      branchName: row['branch_name']?.toString() ?? '',
      employeeId: row['employee_id']?.toString() ?? '',
      employeeName: row['employee_name']?.toString() ?? '',
      date: parsedDate,
      portionsSold: (row['portions_sold'] as num?)?.toInt() ?? 0,
      commissionRatePerPortion: (row['commission_rate'] as num?)?.toDouble() ?? 5.0,
      totalSalesAmount: (row['total_sales_amount'] as num?)?.toDouble() ?? 0.0,
      wage: (row['wage'] as num?)?.toDouble(),
      regularSold: (row['regular_sold'] as num?)?.toInt(),
      mediumSold: (row['medium_sold'] as num?)?.toInt(),
      b1t1OrdersSold: (row['b1t1_sold'] as num?)?.toInt(),
      totalOrders: (row['total_orders'] as num?)?.toInt(),
      discrepancyNote: row['discrepancy_note']?.toString(),
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
  }

  /// Upserts a daily sales record to Supabase.
  static Future<bool> saveDailySales(SalesRecord sales) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('daily_sales').upsert(_salesRecordToMap(sales));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.saveDailySales error: $e');
      return false;
    }
  }

  /// Fetches recent sales from Supabase with zero per-document read penalty.
  static Future<List<SalesRecord>> getRecentSales({
    DateTime? startDate,
    int limit = 50,
  }) async {
    final client = _client;
    if (client == null) return [];
    try {
      var query = client.from('daily_sales').select();
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }
      final data = await query.order('date', ascending: false).limit(limit);
      return (data as List)
          .map((row) => _salesRecordFromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService.getRecentSales error: $e');
      return [];
    }
  }

  /// Real-time stream of recent sales from Supabase.
  static Stream<List<SalesRecord>> watchRecentSales({int limit = 50}) async* {
    final client = _client;
    if (client == null) return;
    try {
      final initial = await getRecentSales(limit: limit);
      if (initial.isNotEmpty) yield initial;

      final stream = client
          .from('daily_sales')
          .stream(primaryKey: ['id'])
          .order('date', ascending: false)
          .limit(limit);

      await for (final rows in stream) {
        yield rows.map((r) => _salesRecordFromMap(r)).toList();
      }
    } catch (e) {
      debugPrint('SupabaseService.watchRecentSales error: $e');
    }
  }

  // ===========================================================================
  // 5. DAILY REPORTS & INCIDENTS (Supabase PostgreSQL)
  // ===========================================================================

  static Map<String, dynamic> _dailyReportToMap(DailyReport report) {
    return {
      'id': report.id,
      'employee_id': report.employeeId,
      'employee_name': report.employeeName,
      'branch_id': report.branchId,
      'branch_name': report.branchName,
      'date': report.date.toIso8601String(),
      'content': report.content,
      'status': report.status.name,
      'owner_reply': report.ownerReply,
    };
  }

  static DailyReport _dailyReportFromMap(Map<String, dynamic> row) {
    DateTime parsedDate;
    final rawDate = row['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    final statusStr = row['status']?.toString() ?? 'submitted';

    return DailyReport(
      id: row['id']?.toString() ?? '',
      employeeId: row['employee_id']?.toString() ?? '',
      employeeName: row['employee_name']?.toString() ?? '',
      branchId: row['branch_id']?.toString() ?? '',
      branchName: row['branch_name']?.toString() ?? '',
      date: parsedDate,
      content: row['content']?.toString() ?? '',
      status: ReportSubmissionStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => ReportSubmissionStatus.submitted,
      ),
      ownerReply: row['owner_reply']?.toString(),
    );
  }

  /// Inserts a new employee daily report into Supabase.
  static Future<bool> saveDailyReport(DailyReport report) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('daily_reports').upsert(_dailyReportToMap(report));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.saveDailyReport error: $e');
      return false;
    }
  }

  /// Fetches daily reports from Supabase.
  static Future<List<DailyReport>> getDailyReports({int limit = 50}) async {
    final client = _client;
    if (client == null) return [];
    try {
      final data = await client
          .from('daily_reports')
          .select()
          .order('date', ascending: false)
          .limit(limit);
      return (data as List)
          .map((row) => _dailyReportFromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService.getDailyReports error: $e');
      return [];
    }
  }

  /// Real-time stream of daily reports from Supabase.
  static Stream<List<DailyReport>> watchDailyReports({int limit = 50}) async* {
    final client = _client;
    if (client == null) return;
    try {
      final initial = await getDailyReports(limit: limit);
      if (initial.isNotEmpty) yield initial;

      final stream = client
          .from('daily_reports')
          .stream(primaryKey: ['id'])
          .order('date', ascending: false)
          .limit(limit);

      await for (final rows in stream) {
        yield rows.map((r) => _dailyReportFromMap(r)).toList();
      }
    } catch (e) {
      debugPrint('SupabaseService.watchDailyReports error: $e');
    }
  }

  /// Updates owner reply on an employee report in Supabase.
  static Future<bool> replyToDailyReport({
    required String reportId,
    required String reply,
  }) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client
          .from('daily_reports')
          .update({'owner_reply': reply})
          .eq('id', reportId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.replyToDailyReport error: $e');
      return false;
    }
  }

  /// Confirms report received in Supabase.
  static Future<bool> confirmReportReceived({required String reportId}) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client
          .from('daily_reports')
          .update({'status': ReportSubmissionStatus.submitted.name})
          .eq('id', reportId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.confirmReportReceived error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 6. PRODUCTION BATCHES & RESEKO (Supabase PostgreSQL)
  // ===========================================================================

  static Map<String, dynamic> _batchToMap(KarneBatch batch) {
    return {
      'id': batch.id,
      'name': batch.name,
      'total_kilos': batch.totalKilos,
      'sessions': batch.sessions.map((s) => s.toMap()).toList(),
      'is_finished': batch.isFinished,
    };
  }

  static KarneBatch _batchFromMap(Map<String, dynamic> row) {
    final rawSessions = row['sessions'] as List<dynamic>? ?? [];
    return KarneBatch(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Batch',
      totalKilos: (row['total_kilos'] as num?)?.toDouble() ?? 0.0,
      sessions: rawSessions
          .map((s) => KarneSession.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      isFinished: row['is_finished'] as bool? ?? false,
    );
  }

  /// Upserts a production batch into Supabase.
  static Future<bool> saveProductionBatch(KarneBatch batch) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('production_batches').upsert(_batchToMap(batch));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.saveProductionBatch error: $e');
      return false;
    }
  }

  /// Fetches production batches from Supabase.
  static Future<List<KarneBatch>> getProductionBatches({int limit = 50}) async {
    final client = _client;
    if (client == null) return [];
    try {
      final data = await client
          .from('production_batches')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((row) => _batchFromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService.getProductionBatches error: $e');
      return [];
    }
  }

  /// Real-time stream of production batches from Supabase.
  static Stream<List<KarneBatch>> watchProductionBatches({int limit = 50}) async* {
    final client = _client;
    if (client == null) return;
    try {
      final initial = await getProductionBatches(limit: limit);
      if (initial.isNotEmpty) yield initial;

      final stream = client
          .from('production_batches')
          .stream(primaryKey: ['id'])
          .limit(limit);

      await for (final rows in stream) {
        yield rows.map((r) => _batchFromMap(r)).toList();
      }
    } catch (e) {
      debugPrint('SupabaseService.watchProductionBatches error: $e');
    }
  }

  /// Deletes a production batch from Supabase.
  static Future<bool> deleteProductionBatch(String batchId) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('production_batches').delete().eq('id', batchId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteProductionBatch error: $e');
      return false;
    }
  }

  // ===========================================================================
  // 7. ANNOUNCEMENTS (Supabase PostgreSQL)
  // ===========================================================================

  static Map<String, dynamic> _announcementToMap(Announcement ann) {
    return {
      'id': ann.id,
      'message_content': ann.messageContent,
      'date_posted': ann.datePosted.toIso8601String(),
      'target_position': ann.targetPosition,
    };
  }

  static Announcement _announcementFromMap(Map<String, dynamic> row) {
    DateTime parsedDate;
    final rawDate = row['date_posted'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    return Announcement(
      id: row['id']?.toString() ?? '',
      messageContent: row['message_content']?.toString() ?? '',
      datePosted: parsedDate,
      targetPosition: row['target_position']?.toString() ?? 'All Positions',
    );
  }

  /// Upserts an announcement into Supabase.
  static Future<bool> saveAnnouncement(Announcement announcement) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('announcements').upsert(_announcementToMap(announcement));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.saveAnnouncement error: $e');
      return false;
    }
  }

  /// Fetches announcements from Supabase.
  static Future<List<Announcement>> getAnnouncements() async {
    final client = _client;
    if (client == null) return [];
    try {
      final data = await client
          .from('announcements')
          .select()
          .order('date_posted', ascending: false);
      return (data as List)
          .map((row) => _announcementFromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService.getAnnouncements error: $e');
      return [];
    }
  }

  /// Real-time stream of announcements from Supabase.
  static Stream<List<Announcement>> watchAnnouncements() async* {
    final client = _client;
    if (client == null) return;
    try {
      final initial = await getAnnouncements();
      if (initial.isNotEmpty) yield initial;

      final stream = client
          .from('announcements')
          .stream(primaryKey: ['id'])
          .order('date_posted', ascending: false);

      await for (final rows in stream) {
        yield rows.map((r) => _announcementFromMap(r)).toList();
      }
    } catch (e) {
      debugPrint('SupabaseService.watchAnnouncements error: $e');
    }
  }

  /// Deletes an announcement from Supabase.
  static Future<bool> deleteAnnouncement(String id) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('announcements').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteAnnouncement error: $e');
      return false;
    }
  }
}
