import 'package:shared_preferences/shared_preferences.dart';

import 'audio/voice.dart';

/// A single narrative beat — text shown before a level (or as an ending).
class StoryBeat {
  const StoryBeat({
    required this.lines,
    this.voice,
    this.lingerSec = 4.6,
  });

  final List<String> lines;
  final VoiceLine? voice;
  final double lingerSec;
}

/// Map of level-index → intro beat. Plays once per fresh playthrough
/// before that level loads.
const Map<int, StoryBeat> kLevelIntros = {
  0: StoryBeat(
    lines: ['my hands.', 'my history.'],
    voice: VoiceLine.myHistory,
    lingerSec: 5.2,
  ),
  5: StoryBeat(
    lines: [
      'I do not remember their faces.',
      'only the weight.',
    ],
    lingerSec: 4.8,
  ),
  10: StoryBeat(
    lines: [
      'the gate has its rules.',
      'I am not yet free.',
    ],
    lingerSec: 4.8,
  ),
  14: StoryBeat(
    lines: [
      'one more circle.',
      'or a thousand.',
    ],
    lingerSec: 4.4,
  ),
};

/// Endings — shown when conditions are met after a victory.
const StoryBeat kFirstClearEnding = StoryBeat(
  lines: [
    'fifteen circles.',
    'the gate has opened.',
    'until I return.',
  ],
  voice: VoiceLine.noRegrets,
  lingerSec: 7.0,
);

const StoryBeat kThreeStarEnding = StoryBeat(
  lines: [
    'no shadow on the blade.',
    'no weight on the hands.',
    'I am released.',
  ],
  voice: VoiceLine.newJourney,
  lingerSec: 8.0,
);

/// Outcome text variants — picked by hash of the level + run state to
/// feel varied without total chaos.
const List<String> kVictoryOutcomes = [
  'until next time',
  'the dawn finds you again',
  'they wait for you still',
  'another circle',
  'the field releases you · briefly',
];

const List<String> kDefeatOutcomes = [
  'demons remain',
  'the field claims you',
  'again, then',
  'still bound',
];

const List<String> kStruckOutcomes = [
  'struck down',
  'the wind takes you',
  'a swift end',
];

const List<String> kConsumedOutcomes = [
  'consumed',
  'the mist takes you',
  'unmade',
];

const List<String> kTooSlowOutcomes = [
  'too slow',
  'not yet ready',
  'the gate refuses',
];

String pickOutcome(List<String> options, int seed) {
  if (options.isEmpty) return '';
  return options[seed.abs() % options.length];
}

/// Tracks which intros + endings the player has already seen, so we
/// don't replay them on retries / mid-session.
class StoryProgress {
  StoryProgress._(this._prefs)
      : _introsSeen = (_prefs.getStringList(_kIntros) ?? <String>[]).toSet(),
        _endingsSeen = (_prefs.getStringList(_kEndings) ?? <String>[]).toSet();

  static const _kIntros = 'story_intros_seen';
  static const _kEndings = 'story_endings_seen';

  final SharedPreferences _prefs;
  final Set<String> _introsSeen;
  final Set<String> _endingsSeen;

  static Future<StoryProgress> load() async {
    final p = await SharedPreferences.getInstance();
    return StoryProgress._(p);
  }

  bool hasSeenIntro(int levelIdx) => _introsSeen.contains('$levelIdx');
  bool hasSeenEnding(String key) => _endingsSeen.contains(key);

  Future<void> markIntroSeen(int levelIdx) async {
    _introsSeen.add('$levelIdx');
    await _prefs.setStringList(_kIntros, _introsSeen.toList());
  }

  Future<void> markEndingSeen(String key) async {
    _endingsSeen.add(key);
    await _prefs.setStringList(_kEndings, _endingsSeen.toList());
  }

  Future<void> reset() async {
    _introsSeen.clear();
    _endingsSeen.clear();
    await _prefs.remove(_kIntros);
    await _prefs.remove(_kEndings);
  }
}
