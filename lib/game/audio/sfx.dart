import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';

enum Sfx {
  slash, // randomized slash variant
  hurt,  // samurai eats damage
}

class SfxBank {
  final math.Random _rng = math.Random();
  bool _ready = false;
  double sfxVolume = 1.0;

  Future<void> preload() async {
    if (_ready) return;
    try {
      await FlameAudio.audioCache.loadAll([
        'sfx/slash_a.mp3',
        'sfx/slash_b.mp3',
        'sfx/slash_c.mp3',
        'sfx/hurt.mp3',
      ]);
      _ready = true;
    } catch (_) {}
  }

  Future<void> play(Sfx kind, {double volumeMul = 1.0}) async {
    final file = switch (kind) {
      Sfx.slash => _slashVariants[_rng.nextInt(_slashVariants.length)],
      Sfx.hurt => 'sfx/hurt.mp3',
    };
    try {
      await FlameAudio.play(file, volume: 0.85 * sfxVolume * volumeMul);
    } catch (_) {}
  }

  static const _slashVariants = ['sfx/slash_a.mp3', 'sfx/slash_b.mp3', 'sfx/slash_c.mp3'];
}
