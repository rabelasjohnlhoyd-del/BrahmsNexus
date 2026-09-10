import 'package:flutter/material.dart';

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
    List<KarneSession>? sessions,
    bool? isFinished,
  }) {
    return KarneBatch(
      id: id,
      name: name,
      totalKilos: totalKilos,
      sessions: sessions ?? this.sessions,
      isFinished: isFinished ?? this.isFinished,
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
  final double resekoApplied;
  final int boilingMinutes;
  final double kilosCooked;
  final int actualPcs;

  int get kota {
    // NEW COMPUTATION LOGIC:
    // 1. Portion Base = Minutes * 10 (e.g., 25 mins = 250)
    // 2. Outcome = (Kilos * 1000) / Portion Base (e.g., 150,000 / 250 = 600)
    // 3. Kota = Outcome - Reseko% (e.g., 600 - 28% = 432)
    
    final double portionBase = boilingMinutes * 10.0;
    if (portionBase <= 0) return 0;
    
    final double outcome = (kilosCooked * 1000) / portionBase;
    final int finalKota = (outcome * (1 - (resekoApplied / 100))).round();
    
    return finalKota;
  }

  int get sobra => (actualPcs > 0 && actualPcs > kota) ? actualPcs - kota : 0;
  int get short => (actualPcs > 0 && actualPcs < kota) ? kota - actualPcs : 0;
}
