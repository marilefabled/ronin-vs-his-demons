import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// A samurai variant — different stats + palette + unlock condition.
class SamuraiKit {
  const SamuraiKit({
    required this.id,
    required this.name,
    required this.tagline,
    required this.speed,
    required this.momentumGain,
    required this.momentumCap,
    required this.reach,
    required this.kasaColor,
    required this.sashColor,
    required this.accentColor,
    required this.sayaColor,
    required this.unlockStars,
    this.signatureStyle,
  });

  /// Stable identifier for persistence.
  final String id;

  /// Display name.
  final String name;

  /// One-line description shown beneath the name.
  final String tagline;

  // ---- gameplay stats ----

  /// Base run speed in px/s. Default `Ronin` is 660.
  final double speed;

  /// Momentum bonus added per kill (added to running speed).
  final double momentumGain;

  /// Momentum cap — additive ceiling.
  final double momentumCap;

  /// Collision-test radius added to the demon body radius for kill registration.
  /// Default Ronin is 38; bigger = more forgiving slashes.
  final double reach;

  // ---- visual palette ----

  final Color kasaColor;     // hat silhouette
  final Color sashColor;     // obi belt + himo cord
  final Color accentColor;   // face mark + tsuba mark
  final Color sayaColor;     // sheath wrap

  // ---- unlock ----

  /// Total stars across all authored levels required to unlock. 0 = always.
  final int unlockStars;

  // ---- signature ----

  /// String key matching a SwordStyle name (`thrust`, `horizontalSlash`,
  /// `verticalChop`, `diagonalSlash`, `reverseSlash`, `spinCut`). When set,
  /// the kit biases hits toward this style. null = full angle-based variety.
  final String? signatureStyle;
}

const SamuraiKit kitRonin = SamuraiKit(
  id: 'ronin',
  name: 'Ronin',
  tagline: 'the wandering blade',
  speed: 660,
  momentumGain: 90,
  momentumCap: 480,
  reach: 38,
  kasaColor: Color(0xFF161210),
  sashColor: Color(0xFFA72920),
  accentColor: Color(0xFFA72920),
  sayaColor: Color(0xFF3A2418),
  unlockStars: 0,
);

const SamuraiKit kitWraith = SamuraiKit(
  id: 'wraith',
  name: 'Wraith',
  tagline: 'fast · fragile · precise',
  speed: 780,
  momentumGain: 70,
  momentumCap: 420,
  reach: 30,
  kasaColor: Color(0xFF0F0E18),
  sashColor: Color(0xFFE0DCD2),
  accentColor: Color(0xFFE0DCD2),
  sayaColor: Color(0xFF1A1820),
  unlockStars: 12,
  signatureStyle: 'thrust',
);

const SamuraiKit kitFox = SamuraiKit(
  id: 'fox',
  name: 'Fox',
  tagline: 'momentum is a religion',
  speed: 600,
  momentumGain: 140,
  momentumCap: 620,
  reach: 38,
  kasaColor: Color(0xFF3D1F0F),
  sashColor: Color(0xFFE89A2A),
  accentColor: Color(0xFFE89A2A),
  sayaColor: Color(0xFF5C3018),
  unlockStars: 24,
  signatureStyle: 'spinCut',
);

const SamuraiKit kitOni = SamuraiKit(
  id: 'oni',
  name: 'Oni',
  tagline: 'slow · vast · forgiving',
  speed: 580,
  momentumGain: 80,
  momentumCap: 380,
  reach: 52,
  kasaColor: Color(0xFF1A0A08),
  sashColor: Color(0xFF6E0E0A),
  accentColor: Color(0xFFD45438),
  sayaColor: Color(0xFF2A0E0A),
  unlockStars: 36,
  signatureStyle: 'verticalChop',
);

const SamuraiKit kitYurei = SamuraiKit(
  id: 'yurei',
  name: 'Yūrei',
  tagline: 'release at last',
  speed: 720,
  momentumGain: 110,
  momentumCap: 540,
  reach: 36,
  kasaColor: Color(0xFFE8E4D8),
  sashColor: Color(0xFFC8D8E0),
  accentColor: Color(0xFFB68AC8),
  sayaColor: Color(0xFFCEC8B8),
  unlockStars: 45,
  signatureStyle: 'diagonalSlash',
);

const List<SamuraiKit> kAllKits = [
  kitRonin,
  kitWraith,
  kitFox,
  kitOni,
  kitYurei,
];

SamuraiKit kitById(String id) {
  for (final k in kAllKits) {
    if (k.id == id) return k;
  }
  return kitRonin;
}

class KitStore {
  KitStore._(this._prefs)
      : selectedId = _prefs.getString(_kSelected) ?? kitRonin.id;

  static const _kSelected = 'kit_selected';
  static const _kSeenUnlock = 'kit_seen_unlock_';

  final SharedPreferences _prefs;
  String selectedId;

  static Future<KitStore> load() async {
    final p = await SharedPreferences.getInstance();
    return KitStore._(p);
  }

  SamuraiKit get active => kitById(selectedId);

  bool isUnlocked(SamuraiKit k, int totalStars) =>
      totalStars >= k.unlockStars;

  Future<void> select(String id) async {
    selectedId = id;
    await _prefs.setString(_kSelected, id);
  }

  /// Whether the player has already been notified about an unlock for [id].
  bool seenUnlock(String id) =>
      _prefs.getBool('$_kSeenUnlock$id') ?? false;

  Future<void> markSeenUnlock(String id) async {
    await _prefs.setBool('$_kSeenUnlock$id', true);
  }

  Future<void> reset() async {
    selectedId = kitRonin.id;
    await _prefs.setString(_kSelected, kitRonin.id);
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(_kSeenUnlock))
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
