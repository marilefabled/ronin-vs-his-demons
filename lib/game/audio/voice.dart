import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';

class Bgm {
  bool _initialized = false;
  bool _actuallyStarted = false;
  String? _current;
  int _trackIdx = 0;
  double _baseVolume = 0.32;

  /// Tracks in rotation. The first one always boots first; subsequent ones
  /// cycle on each `nextTrack()` call.
  static const List<String> tracks = [
    'music/ronin.mp3',
    'music/warriors_soul.mp3',
    'music/lotus_lane.mp3',
  ];

  Future<void> init() async {
    if (_initialized) return;
    FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll(tracks);
    _initialized = true;
  }

  Future<void> play(String track, {double volume = 0.32}) async {
    if (!_initialized) await init();
    _baseVolume = volume;
    // Autoplay-safe: if a previous play call was blocked (browser hadn't
    // received a user gesture yet), retry now even if `track == _current`.
    if (_current == track && _actuallyStarted) return;
    _current = track;
    try {
      await FlameAudio.bgm.play(track, volume: volume);
      _actuallyStarted = true;
    } catch (_) {}
  }

  /// Called on the first user gesture so blocked autoplay is unblocked.
  Future<void> ensureStarted() async {
    if (_actuallyStarted) return;
    final t = _current ?? tracks.first;
    _current = null; // force re-play
    await play(t, volume: _baseVolume);
  }

  /// Rotate to the next track in the loop. Volume preserved.
  Future<void> nextTrack() async {
    _trackIdx = (_trackIdx + 1) % tracks.length;
    final next = tracks[_trackIdx];
    if (next == _current) return;
    _current = next;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play(next, volume: _baseVolume);
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    _baseVolume = v.clamp(0.0, 1.0);
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(_baseVolume);
    } catch (_) {}
  }

  Future<void> stop() async {
    _current = null;
    _actuallyStarted = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }
}

enum VoiceLine {
  go,
  winner,
  newJourney,
  dying,
  dragonCut,
  killMore,
  whosNext,
  noRegrets,
  kira,
  tooSlow,
  myHistory,
}

const _files = {
  VoiceLine.go: ['voice/akirago1.mp3', 'voice/akirago2.mp3'],
  VoiceLine.winner: ['voice/akirawinner1.mp3'],
  VoiceLine.newJourney: ['voice/akiranewjourney1.mp3'],
  VoiceLine.dying: ['voice/akiradying1.mp3'],
  VoiceLine.dragonCut: ['voice/akiradragoncut1.mp3'],
  VoiceLine.killMore: ['voice/akirakillmore1.mp3'],
  VoiceLine.whosNext: ['voice/akirawhosnext1.mp3'],
  VoiceLine.noRegrets: ['voice/akiranoregrets1.mp3'],
  VoiceLine.kira: ['voice/akirakira1.mp3'],
  VoiceLine.tooSlow: ['voice/akiratooslow1.mp3'],
  VoiceLine.myHistory: ['voice/akiramyhistory1.mp3'],
};

const _comboCount = [
  'voice/akiraichi1.mp3', // 1
  'voice/akirani1.mp3',   // 2
  'voice/akirasan1.mp3',  // 3
  'voice/akirashi1.mp3',  // 4
];

const _comboTaunts = [
  'voice/akirawhosnext1.mp3',
  'voice/akirakillmore1.mp3',
  'voice/akirakira1.mp3',
  'voice/akiranoregrets1.mp3',
];

class Voice {
  final math.Random _rng = math.Random();
  double voiceVolume = 1.0;

  Future<void> preload() async {
    final all = <String>{
      for (final list in _files.values) ...list,
      ..._comboCount,
      ..._comboTaunts,
    };
    await FlameAudio.audioCache.loadAll(all.toList());
  }

  Future<void> play(VoiceLine line) async {
    final candidates = _files[line];
    if (candidates == null || candidates.isEmpty) return;
    final pick = candidates[_rng.nextInt(candidates.length)];
    try {
      await FlameAudio.play(pick, volume: voiceVolume * 0.95);
    } catch (_) {}
  }

  Future<void> playCombo(int combo) async {
    if (combo <= 0) return;
    String pick;
    if (combo <= _comboCount.length) {
      pick = _comboCount[combo - 1];
    } else {
      pick = _comboTaunts[_rng.nextInt(_comboTaunts.length)];
    }
    try {
      await FlameAudio.play(pick, volume: voiceVolume * 0.95);
    } catch (_) {}
  }
}
