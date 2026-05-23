import 'package:shared_preferences/shared_preferences.dart';

class RunRecord {
  const RunRecord({required this.bestTimeSec, required this.bestLevels});
  final double bestTimeSec;
  final int bestLevels;

  static const empty = RunRecord(
    bestTimeSec: double.infinity,
    bestLevels: 0,
  );
}

class RunRecords {
  RunRecords._(this._prefs);

  static const _prefix = 'run_record_';

  final SharedPreferences _prefs;

  static Future<RunRecords> load() async {
    final p = await SharedPreferences.getInstance();
    return RunRecords._(p);
  }

  RunRecord get(String runId) {
    final t = _prefs.getDouble('${_prefix}${runId}_t');
    final l = _prefs.getInt('${_prefix}${runId}_l');
    if (t == null && l == null) return RunRecord.empty;
    return RunRecord(
      bestTimeSec: t ?? double.infinity,
      bestLevels: l ?? 0,
    );
  }

  /// Returns true if either the time or levels-cleared improved.
  Future<bool> submit({
    required String runId,
    required double elapsedSec,
    required int levelsCompleted,
  }) async {
    final prior = get(runId);
    var improved = false;
    if (levelsCompleted > prior.bestLevels) {
      await _prefs.setInt('${_prefix}${runId}_l', levelsCompleted);
      improved = true;
    }
    // Best time is only meaningful if you completed *more* levels (or tied).
    if (levelsCompleted >= prior.bestLevels &&
        elapsedSec < prior.bestTimeSec) {
      await _prefs.setDouble('${_prefix}${runId}_t', elapsedSec);
      improved = true;
    }
    return improved;
  }

  Future<void> reset() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
