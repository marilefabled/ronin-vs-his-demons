import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'game_run.dart';

class SpeedrunSet {
  const SpeedrunSet({
    required this.id,
    required this.label,
    required this.levelFiles,
  });
  final String id;
  final String label;
  final List<String> levelFiles;
  int get count => levelFiles.length;
}

/// The three locked-in speedrun sets. No procgen at runtime — every player
/// runs the same demons in the same positions.
const Map<String, SpeedrunSet> kSpeedrunSets = {
  'short': SpeedrunSet(
    id: 'short',
    label: 'short',
    levelFiles: ['L01.json', 'L02.json', 'L03.json', 'L04.json', 'L05.json'],
  ),
  'medium': SpeedrunSet(
    id: 'medium',
    label: 'medium',
    levelFiles: [
      'L01.json', 'L02.json', 'L03.json', 'L04.json', 'L05.json',
      'L06.json', 'L07.json', 'L08.json', 'L09.json', 'L10.json',
    ],
  ),
  'long': SpeedrunSet(
    id: 'long',
    label: 'long',
    levelFiles: [
      'L01.json', 'L02.json', 'L03.json', 'L04.json', 'L05.json',
      'L06.json', 'L07.json', 'L08.json', 'L09.json', 'L10.json',
      'L11.json', 'L12.json', 'L13.json', 'L14.json', 'L15.json',
    ],
  ),
};

class SpeedrunRun extends GameRun {
  SpeedrunRun({required this.set});

  final SpeedrunSet set;
  final List<String> _preloaded = [];

  /// Preload all level JSONs so transitions are instant (timer accuracy).
  Future<void> preload() async {
    _preloaded.clear();
    for (final f in set.levelFiles) {
      final raw = await rootBundle.loadString('assets/levels/$f');
      // Re-encode so we know it parses (validate-on-load) — keeps the
      // schema check cheap and uniform.
      json.decode(raw);
      _preloaded.add(raw);
    }
  }

  @override
  String get id => 'speedrun_${set.id}';

  @override
  String get title => 'speedrun · ${set.label}';

  @override
  bool get showStory => false;

  @override
  bool get strictTimer => true;

  @override
  String? nextLevelJson(int completedSoFar) {
    if (completedSoFar >= _preloaded.length) return null;
    return _preloaded[completedSoFar];
  }
}
