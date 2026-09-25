class KarneBatch {
  KarneBatch({
    required this.id,
    required this.name,
    required this.totalKilos,
    DateTime? date,
    this.cookedKilos,
    this.cookedBy,
    this.cookedAt,
    this.cookingStatus = 'pending',
    this.target250g,
    this.target300g,
    this.target400g,
    this.targetsSetAt,
    this.actual250g,
    this.actual300g,
    this.actual400g,
    this.brand,
    this.boilingMinutes,
    this.resekoApplied,
    this.cutterRemainingGrams,
    this.cutterName,
    this.cutterReportedAt,
    this.cutterNotes,
    this.sessions = const [],
    this.isFinished = false,
  }) : date = date ?? DateTime.now();

  final String id;
  final String name;
  final DateTime date;
  final String? brand;
  final int? boilingMinutes;
  final double? resekoApplied;
  final double totalKilos; // Target kilos assigned by Owner to cook
  final double? cookedKilos; // Actual kilos cooked and reported by Cook
  final String? cookedBy;
  final DateTime? cookedAt;
  final String cookingStatus; // 'pending', 'cooked', 'cutting', 'completed'

  // Targets set by Owner for Meat Cutter
  final int? target250g;
  final int? target300g;
  final int? target400g;
  final DateTime? targetsSetAt;

  // Actual output cut and reported by Meat Cutter
  final int? actual250g;
  final int? actual300g;
  final int? actual400g;
  final int? cutterRemainingGrams;
  final String? cutterName;
  final DateTime? cutterReportedAt;
  final String? cutterNotes;

  final List<KarneSession> sessions;
  final bool isFinished;

  double get remainingKilos {
    double used = 0;
    for (var s in sessions) {
      used += s.kilosCooked;
    }
    return totalKilos - used;
  }

  int get totalShort {
    int sum = 0;
    for (var s in sessions) {
      sum += s.short;
    }
    return sum;
  }

  int get totalSobra {
    int sum = 0;
    for (var s in sessions) {
      sum += s.sobra;
    }
    return sum;
  }

  int get totalPcsNagawa {
    int sum = 0;
    for (var s in sessions) {
      sum += s.nagawa;
    }
    return sum;
  }

  double get totalNalutoKg {
    double sum = 0;
    for (var s in sessions) {
      if (s.nalutoKg != null) {
        sum += s.nalutoKg!;
      }
    }
    return sum;
  }

  KarneBatch copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? brand,
    int? boilingMinutes,
    double? resekoApplied,
    double? totalKilos,
    double? cookedKilos,
    String? cookedBy,
    DateTime? cookedAt,
    String? cookingStatus,
    int? target250g,
    int? target300g,
    int? target400g,
    DateTime? targetsSetAt,
    int? actual250g,
    int? actual300g,
    int? actual400g,
    int? cutterRemainingGrams,
    String? cutterName,
    DateTime? cutterReportedAt,
    String? cutterNotes,
    List<KarneSession>? sessions,
    bool? isFinished,
  }) {
    return KarneBatch(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      brand: brand ?? this.brand,
      boilingMinutes: boilingMinutes ?? this.boilingMinutes,
      resekoApplied: resekoApplied ?? this.resekoApplied,
      totalKilos: totalKilos ?? this.totalKilos,
      cookedKilos: cookedKilos ?? this.cookedKilos,
      cookedBy: cookedBy ?? this.cookedBy,
      cookedAt: cookedAt ?? this.cookedAt,
      cookingStatus: cookingStatus ?? this.cookingStatus,
      target250g: target250g ?? this.target250g,
      target300g: target300g ?? this.target300g,
      target400g: target400g ?? this.target400g,
      targetsSetAt: targetsSetAt ?? this.targetsSetAt,
      actual250g: actual250g ?? this.actual250g,
      actual300g: actual300g ?? this.actual300g,
      actual400g: actual400g ?? this.actual400g,
      cutterRemainingGrams: cutterRemainingGrams ?? this.cutterRemainingGrams,
      cutterName: cutterName ?? this.cutterName,
      cutterReportedAt: cutterReportedAt ?? this.cutterReportedAt,
      cutterNotes: cutterNotes ?? this.cutterNotes,
      sessions: sessions ?? this.sessions,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'brand': brand,
      'boilingMinutes': boilingMinutes,
      'resekoApplied': resekoApplied,
      'totalKilos': totalKilos,
      'cookedKilos': cookedKilos,
      'cookedBy': cookedBy,
      'cookedAt': cookedAt?.toIso8601String(),
      'cookingStatus': cookingStatus,
      'target250g': target250g,
      'target300g': target300g,
      'target400g': target400g,
      'targetsSetAt': targetsSetAt?.toIso8601String(),
      'actual250g': actual250g,
      'actual300g': actual300g,
      'actual400g': actual400g,
      'cutterRemainingGrams': cutterRemainingGrams,
      'cutterName': cutterName,
      'cutterReportedAt': cutterReportedAt?.toIso8601String(),
      'cutterNotes': cutterNotes,
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'isFinished': isFinished,
    };
  }

  factory KarneBatch.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawSessions = map['sessions'] as List<dynamic>? ?? [];
    DateTime parsedDate = DateTime.now();
    final rawDate = map['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    DateTime? parsedCookedAt;
    final rawCookedAt = map['cookedAt'];
    if (rawCookedAt is String) {
      parsedCookedAt = DateTime.tryParse(rawCookedAt);
    }

    DateTime? parsedTargetsSetAt;
    final rawTargetsSetAt = map['targetsSetAt'];
    if (rawTargetsSetAt is String) {
      parsedTargetsSetAt = DateTime.tryParse(rawTargetsSetAt);
    }

    DateTime? parsedCutterReportedAt;
    final rawCutterReportedAt = map['cutterReportedAt'];
    if (rawCutterReportedAt is String) {
      parsedCutterReportedAt = DateTime.tryParse(rawCutterReportedAt);
    }

    return KarneBatch(
      id: docId ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Batch',
      date: parsedDate,
      brand: map['brand']?.toString(),
      boilingMinutes: (map['boilingMinutes'] as num?)?.toInt(),
      resekoApplied: (map['resekoApplied'] as num?)?.toDouble(),
      totalKilos: (map['totalKilos'] as num?)?.toDouble() ?? 0.0,
      cookedKilos: (map['cookedKilos'] as num?)?.toDouble(),
      cookedBy: map['cookedBy']?.toString(),
      cookedAt: parsedCookedAt,
      cookingStatus: map['cookingStatus']?.toString() ?? 'pending',
      target250g: (map['target250g'] as num?)?.toInt(),
      target300g: (map['target300g'] as num?)?.toInt(),
      target400g: (map['target400g'] as num?)?.toInt(),
      targetsSetAt: parsedTargetsSetAt,
      actual250g: (map['actual250g'] as num?)?.toInt(),
      actual300g: (map['actual300g'] as num?)?.toInt(),
      actual400g: (map['actual400g'] as num?)?.toInt(),
      cutterRemainingGrams: (map['cutterRemainingGrams'] as num?)?.toInt(),
      cutterName: map['cutterName']?.toString(),
      cutterReportedAt: parsedCutterReportedAt,
      cutterNotes: map['cutterNotes']?.toString(),
      sessions: rawSessions
          .map((s) => KarneSession.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      isFinished: map['isFinished'] as bool? ?? false,
    );
  }
}

class KarneSession {
  KarneSession({
    this.id,
    required this.date,
    required this.brand,
    required this.resekoApplied,
    required this.boilingMinutes,
    required this.kilosCooked,
    this.cookedKilos,
    this.cookedBy,
    this.cookedAt,
    this.status = 'pending',
    this.target250g,
    this.target300g,
    this.target400g,
    this.actual250g,
    this.actual300g,
    this.actual400g,
    this.actualPcs = 0,
    this.cutterName,
    this.cutterReportedAt,
    this.cutterRemainingGrams,
    this.cutterNotes,
  });

  final String? id;
  final DateTime date;
  final String brand;
  final double resekoApplied; // Base target reseko limit (e.g. 28%)
  final int boilingMinutes; // Set by owner per brand (e.g. 25, 35)
  final double kilosCooked; // Raw meat kilos to cook (e.g. 151.0 kg)
  final double? cookedKilos; // Actual kilos cooked by Cook (e.g. 120.25 kg)
  final String? cookedBy;
  final DateTime? cookedAt;
  final String status; // 'pending', 'cooked', 'cutting', 'completed'

  // Targets
  final int? target250g;
  final int? target300g;
  final int? target400g;

  // Actual portioning results from Cutter
  final int? actual250g;
  final int? actual300g;
  final int? actual400g;
  final int actualPcs;
  final String? cutterName;
  final DateTime? cutterReportedAt;
  final int? cutterRemainingGrams;
  final String? cutterNotes;

  /// Hilaw raw meat kilos assigned for this cooking session (alias for kilosCooked)
  double get hilawKilos => kilosCooked;

  /// Display session identifier
  String get sessionNumber => id != null && id!.isNotEmpty ? id! : '1';

  /// 1. The Basis (100% Ideal Yield)
  /// Always 4 pieces per kilo (1000g / 250g)
  double get idealYield => kilosCooked * 4.0;

  /// 2. The Quota (Target Pieces at standard Reseko limit)
  /// Formula: Ideal Yield * (1 - resekoApplied%)
  int get kota => (idealYield * (1 - (resekoApplied / 100))).round();

  /// 3. Total cooked grams from portioned packs (400g x pcs + 300g x pcs + 250g x pcs)
  double get totalCookedGrams {
    if (actual250g != null || actual300g != null || actual400g != null) {
      return ((actual400g ?? 0) * 400.0) +
          ((actual300g ?? 0) * 300.0) +
          ((actual250g ?? 0) * 250.0);
    }
    if (actualPcs > 0) {
      return actualPcs * 250.0;
    }
    if (cookedKilos != null && cookedKilos! > 0) {
      return cookedKilos! * 1000.0;
    }
    return 0.0;
  }

  /// 4. Naluto (KG) base kay Meat Cutter
  /// Pinag-add na (400G x pcs + 300G x pcs + 250G x pcs) / 1000
  double? get nalutoKg {
    if (totalCookedGrams > 0) {
      return totalCookedGrams / 1000.0;
    }
    if (cookedKilos != null && cookedKilos! > 0) {
      return cookedKilos!;
    }
    return null;
  }

  /// 5. Nagawa: Kabuuang piraso na nagawa (400G + 300G + 250G)
  int get nagawa {
    if (actual250g != null || actual300g != null || actual400g != null) {
      return (actual400g ?? 0) + (actual300g ?? 0) + (actual250g ?? 0);
    }
    return actualPcs;
  }

  /// Alias for nagawa
  int get totalPieces => nagawa;

  /// Equivalent Yield in 250g base pieces (for reference)
  double get equivalentYield {
    if (actual250g != null || actual300g != null || actual400g != null) {
      return totalCookedGrams > 0 ? (totalCookedGrams / 250.0) : 0.0;
    }
    if (actualPcs > 0) {
      return actualPcs.toDouble();
    }
    return 0.0;
  }

  bool get hasActualOutput =>
      (actual250g != null && actual250g! > 0) ||
      (actual300g != null && actual300g! > 0) ||
      (actual400g != null && actual400g! > 0) ||
      actualPcs > 0;

  /// 6. Result: Sobra o Kulang base sa Nagawa vs Kota
  /// Result = Nagawa - Kota
  int get resultDifference => nagawa - kota;

  int get sobra => (hasActualOutput && nagawa > kota)
      ? (nagawa - kota)
      : 0;

  int get short => (hasActualOutput && nagawa < kota)
      ? (kota - nagawa)
      : 0;

  /// 7. Actual Reseko % base sa formula ni Owner:
  /// Hakbang 1: Diperensya = Ideal Yield - Nagawa
  /// Hakbang 2: Output = Diperensya ÷ Ideal Yield
  /// Hakbang 3: Actual Reseko % = Output * 100
  /// Halimbawa: 604 - 437 = 167; 167 / 604 = 0.27649 * 100 = 27.65%
  double? get actualReseko {
    if (!hasActualOutput || idealYield <= 0) return null;
    final diff = idealYield - nagawa;
    return (diff / idealYield) * 100.0;
  }

  KarneSession copyWith({
    String? id,
    DateTime? date,
    String? brand,
    double? resekoApplied,
    int? boilingMinutes,
    double? kilosCooked,
    double? cookedKilos,
    String? cookedBy,
    DateTime? cookedAt,
    String? status,
    int? target250g,
    int? target300g,
    int? target400g,
    int? actual250g,
    int? actual300g,
    int? actual400g,
    int? actualPcs,
    String? cutterName,
    DateTime? cutterReportedAt,
    int? cutterRemainingGrams,
    String? cutterNotes,
  }) {
    return KarneSession(
      id: id ?? this.id,
      date: date ?? this.date,
      brand: brand ?? this.brand,
      resekoApplied: resekoApplied ?? this.resekoApplied,
      boilingMinutes: boilingMinutes ?? this.boilingMinutes,
      kilosCooked: kilosCooked ?? this.kilosCooked,
      cookedKilos: cookedKilos ?? this.cookedKilos,
      cookedBy: cookedBy ?? this.cookedBy,
      cookedAt: cookedAt ?? this.cookedAt,
      status: status ?? this.status,
      target250g: target250g ?? this.target250g,
      target300g: target300g ?? this.target300g,
      target400g: target400g ?? this.target400g,
      actual250g: actual250g ?? this.actual250g,
      actual300g: actual300g ?? this.actual300g,
      actual400g: actual400g ?? this.actual400g,
      actualPcs: actualPcs ?? this.actualPcs,
      cutterName: cutterName ?? this.cutterName,
      cutterReportedAt: cutterReportedAt ?? this.cutterReportedAt,
      cutterRemainingGrams: cutterRemainingGrams ?? this.cutterRemainingGrams,
      cutterNotes: cutterNotes ?? this.cutterNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'brand': brand,
      'resekoApplied': resekoApplied,
      'boilingMinutes': boilingMinutes,
      'kilosCooked': kilosCooked,
      'cookedKilos': cookedKilos,
      'cookedBy': cookedBy,
      'cookedAt': cookedAt?.toIso8601String(),
      'status': status,
      'target250g': target250g,
      'target300g': target300g,
      'target400g': target400g,
      'actual250g': actual250g,
      'actual300g': actual300g,
      'actual400g': actual400g,
      'actualPcs': actualPcs,
      'cutterName': cutterName,
      'cutterReportedAt': cutterReportedAt?.toIso8601String(),
      'cutterRemainingGrams': cutterRemainingGrams,
      'cutterNotes': cutterNotes,
    };
  }

  factory KarneSession.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedCookedAt;
    final rawCookedAt = map['cookedAt'];
    if (rawCookedAt is String) {
      parsedCookedAt = DateTime.tryParse(rawCookedAt);
    }

    DateTime? parsedCutterReportedAt;
    final rawCutterReportedAt = map['cutterReportedAt'];
    if (rawCutterReportedAt is String) {
      parsedCutterReportedAt = DateTime.tryParse(rawCutterReportedAt);
    }

    return KarneSession(
      id: map['id']?.toString(),
      date: parsedDate,
      brand: map['brand']?.toString() ?? '',
      resekoApplied: (map['resekoApplied'] as num?)?.toDouble() ?? 28.0,
      boilingMinutes: (map['boilingMinutes'] as num?)?.toInt() ?? 25,
      kilosCooked: (map['kilosCooked'] as num?)?.toDouble() ?? 0.0,
      cookedKilos: (map['cookedKilos'] as num?)?.toDouble(),
      cookedBy: map['cookedBy']?.toString(),
      cookedAt: parsedCookedAt,
      status: map['status']?.toString() ?? 'pending',
      target250g: (map['target250g'] as num?)?.toInt(),
      target300g: (map['target300g'] as num?)?.toInt(),
      target400g: (map['target400g'] as num?)?.toInt(),
      actual250g: (map['actual250g'] as num?)?.toInt(),
      actual300g: (map['actual300g'] as num?)?.toInt(),
      actual400g: (map['actual400g'] as num?)?.toInt(),
      actualPcs: (map['actualPcs'] as num?)?.toInt() ?? 0,
      cutterName: map['cutterName']?.toString(),
      cutterReportedAt: parsedCutterReportedAt,
      cutterRemainingGrams: (map['cutterRemainingGrams'] as num?)?.toInt(),
      cutterNotes: map['cutterNotes']?.toString(),
    );
  }
}
