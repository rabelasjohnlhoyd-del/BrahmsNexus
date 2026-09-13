class KarneBatch {
  KarneBatch({
    required this.id,
    required this.name,
    required this.totalKilos,
    this.sessions = const [],
    this.isFinished = false,
  });

  final String id;
  final String name;
  final double totalKilos;
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
      sum += s.actualPcs;
    }
    return sum;
  }

  KarneBatch copyWith({
    String? id,
    String? name,
    double? totalKilos,
    List<KarneSession>? sessions,
    bool? isFinished,
  }) {
    return KarneBatch(
      id: id ?? this.id,
      name: name ?? this.name,
      totalKilos: totalKilos ?? this.totalKilos,
      sessions: sessions ?? this.sessions,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'totalKilos': totalKilos,
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'isFinished': isFinished,
    };
  }

  factory KarneBatch.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawSessions = map['sessions'] as List<dynamic>? ?? [];
    return KarneBatch(
      id: docId ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Batch',
      totalKilos: (map['totalKilos'] as num?)?.toDouble() ?? 0.0,
      sessions: rawSessions
          .map((s) => KarneSession.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      isFinished: map['isFinished'] as bool? ?? false,
    );
  }
}

class KarneSession {
  KarneSession({
    required this.date,
    required this.brand,
    required this.resekoApplied,
    required this.boilingMinutes,
    required this.kilosCooked,
    this.actualPcs = 0,
  });

  final DateTime date;
  final String brand;
  final double resekoApplied; // The Target Reseko Limit (e.g. 28%)
  final int boilingMinutes;
  final double kilosCooked;
  final int actualPcs;

  /// 1. The Basis (100% Ideal Yield)
  /// Always 4 pieces per kilo (1000g / 250g)
  double get idealYield => kilosCooked * 4.0;

  /// 2. The Quota (Target Pieces at Quota Limit)
  /// Formula: Ideal Yield - Reseko%
  int get kota {
    // Truncate to whole number as per requirements
    return (idealYield * (1 - (resekoApplied / 100))).toInt();
  }

  /// 3. Actual Reseko achieved in the session
  /// Formula: ((Ideal Yield - Actual Pieces) / Ideal Yield) * 100
  double? get actualReseko {
    if (actualPcs <= 0) return null;
    return ((idealYield - actualPcs) / idealYield) * 100;
  }

  int get sobra => (actualPcs > 0 && actualPcs > kota) ? actualPcs - kota : 0;
  int get short => (actualPcs > 0 && actualPcs < kota) ? kota - actualPcs : 0;

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'brand': brand,
      'resekoApplied': resekoApplied,
      'boilingMinutes': boilingMinutes,
      'kilosCooked': kilosCooked,
      'actualPcs': actualPcs,
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

    return KarneSession(
      date: parsedDate,
      brand: map['brand']?.toString() ?? '',
      resekoApplied: (map['resekoApplied'] as num?)?.toDouble() ?? 28.0,
      boilingMinutes: (map['boilingMinutes'] as num?)?.toInt() ?? 25,
      kilosCooked: (map['kilosCooked'] as num?)?.toDouble() ?? 0.0,
      actualPcs: (map['actualPcs'] as num?)?.toInt() ?? 0,
    );
  }
}
