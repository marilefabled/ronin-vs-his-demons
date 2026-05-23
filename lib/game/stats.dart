import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LevelRecord {
  const LevelRecord({
    required this.completed,
    required this.stars,
    required this.bestTime,
  });

  final bool completed;
  final int stars; // 0..3
  final double bestTime; // seconds

  LevelRecord copyWith({bool? completed, int? stars, double? bestTime}) {
    return LevelRecord(
      completed: completed ?? this.completed,
      stars: stars ?? this.stars,
      bestTime: bestTime ?? this.bestTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': completed,
        'stars': stars,
        'bestTime': bestTime,
      };

  static LevelRecord fromJson(Map<String, dynamic> m) => LevelRecord(
        completed: m['completed'] as bool? ?? false,
        stars: (m['stars'] as num?)?.toInt() ?? 0,
        bestTime: (m['bestTime'] as num?)?.toDouble() ?? double.infinity,
      );

  static const empty = LevelRecord(
    completed: false,
    stars: 0,
    bestTime: double.infinity,
  );
}

class StatsStore {
  StatsStore._(this._prefs, this._records);

  static const _key = 'level_records_v1';

  final SharedPreferences _prefs;
  final Map<String, LevelRecord> _records;

  static Future<StatsStore> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    final map = <String, LevelRecord>{};
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          map[entry.key] = LevelRecord.fromJson(
              (entry.value as Map).cast<String, dynamic>());
        }
      } catch (_) {}
    }
    return StatsStore._(p, map);
  }

  LevelRecord recordFor(String levelId) =>
      _records[levelId] ?? LevelRecord.empty;

  /// Returns true if this run was a new best (stars or time).
  Future<bool> submit({
    required String levelId,
    required int stars,
    required double timeSec,
  }) async {
    final prior = recordFor(levelId);
    final newStars = stars > prior.stars ? stars : prior.stars;
    final newTime =
        timeSec < prior.bestTime ? timeSec : prior.bestTime;
    final updated = LevelRecord(
      completed: true,
      stars: newStars,
      bestTime: newTime,
    );
    _records[levelId] = updated;
    await _save();
    return newStars > prior.stars ||
        (timeSec < prior.bestTime &&
            (prior.bestTime != double.infinity));
  }

  /// Whether [levelIndex] should be tappable. First level always unlocked;
  /// later levels require the previous to be completed.
  bool isUnlocked(List<String> orderedIds, int levelIndex) {
    if (levelIndex == 0) return true;
    if (levelIndex >= orderedIds.length) return false;
    return recordFor(orderedIds[levelIndex - 1]).completed;
  }

  Future<void> _save() async {
    final encoded = json.encode({
      for (final entry in _records.entries) entry.key: entry.value.toJson(),
    });
    await _prefs.setString(_key, encoded);
  }
}

/// Compute star count from elapsed seconds + thresholds.
int starsFor(double timeSec, double threeAt, double twoAt) {
  if (timeSec <= threeAt) return 3;
  if (timeSec <= twoAt) return 2;
  return 1;
}
