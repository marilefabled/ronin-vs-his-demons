import '../proc_gen.dart';
import 'game_run.dart';

/// Procgen endless mode — difficulty ramps with each level cleared.
class EndlessRun extends GameRun {
  EndlessRun({required this.seed});

  final int seed;

  @override
  String get id => 'endless';

  @override
  String get title => 'endless';

  @override
  bool get showStory => false;

  @override
  bool get strictTimer => false;

  @override
  String? nextLevelJson(int completedSoFar) {
    // Difficulty curves smoothly from 1 → 10 over the first ~25 levels,
    // then caps. Each level uses a derived seed so reruns are reproducible.
    final d = (1 + (completedSoFar * 0.4)).clamp(1, 10).round();
    final levelSeed = seed + completedSoFar * 31;
    return ProcGen(seed: levelSeed, difficulty: d).generateJson();
  }
}
