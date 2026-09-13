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
      await client
          .from('staff_profiles')
          .update({'is_active': isActive})
          .eq('id', staffId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.toggleStaffActive error: $e');
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
