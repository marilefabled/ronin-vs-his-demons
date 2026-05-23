/// Base class for chained-level modes (Endless, Speedrun). The game polls
/// [nextLevelJson] after each level to know what to load next.
abstract class GameRun {
  String get title; // "Endless", "Speedrun · Short"
  bool get showStory; // skip narrative cards in run modes
  bool get strictTimer; // count plan + run time, not just run

  /// Called after the player wins a level. [completedSoFar] includes this win.
  /// Returns the next level JSON, or null if the run is complete.
  String? nextLevelJson(int completedSoFar);

  /// Total seconds the player should be timed for. Stops when null is returned.
  /// Resets on a new GameRun.
  void onTick(double dtSec) {
    elapsedSec += dtSec;
  }

  double elapsedSec = 0;
  int levelsCompleted = 0;

  /// Reset for a fresh attempt of the same run.
  void reset() {
    elapsedSec = 0;
    levelsCompleted = 0;
  }

  /// Stable identifier for persistence (best times, etc.).
  String get id;
}
