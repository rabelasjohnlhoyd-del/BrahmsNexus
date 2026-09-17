import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/branch.dart';
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

  /// Fetches all branches ordered by route sequence.
  static Future<List<Branch>> getBranches() async {
    final client = _client;
    if (client == null) {
      return List<Branch>.from(_inMemoryBranches);
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
        return list;
      }
      return List<Branch>.from(_inMemoryBranches);
    } catch (e) {
      debugPrint('SupabaseService.getBranches error: $e. Falling back to local cache.');
      return List<Branch>.from(_inMemoryBranches);
    }
  }

  /// Inserts or updates a branch record.
  static Future<bool> saveBranch(Branch branch) async {
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
    int pageSize = 10,
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

  /// Refreshes all staff profiles from remote Supabase table into in-memory cache.
  static Future<List<StaffMember>> refreshStaffFromRemote() async {
    final client = _client;
    if (client == null) return List.from(_inMemoryStaff);
    try {
      final data = await client.from('staff_profiles').select();
      final list = (data as List).map((row) => StaffMember.fromMap(row as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) {
        _inMemoryStaff
          ..clear()
          ..addAll(list);
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

  static Future<List<Map<String, dynamic>>> getBilaoPackages() async {
    final client = _client;
    if (client == null) {
      return [
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
    }

    try {
      final data = await client
          .from('bilao_packages')
          .select()
          .order('price', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('SupabaseService.getBilaoPackages error: $e');
      return [];
    }
  }
}
