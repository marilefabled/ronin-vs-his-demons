import 'package:shared_preferences/shared_preferences.dart';

class GameSettings {
  GameSettings._(this._prefs)
      : bgmVolume = _prefs.getDouble(_kBgm) ?? 0.32,
        voiceVolume = _prefs.getDouble(_kVoice) ?? 0.95,
        sfxVolume = _prefs.getDouble(_kSfx) ?? 0.85,
        reducedMotion = _prefs.getBool(_kReducedMotion) ?? false,
        colorblindShapes =
            _prefs.getBool(_kColorblindShapes) ?? false,
        touchOffset = _prefs.getDouble(_kTouchOffset) ?? 90.0;

  static const _kBgm = 'set_bgm_vol';
  static const _kVoice = 'set_voice_vol';
  static const _kSfx = 'set_sfx_vol';
  static const _kReducedMotion = 'set_reduced_motion';
  static const _kColorblindShapes = 'set_colorblind_shapes';
  static const _kTouchOffset = 'set_touch_offset';

  final SharedPreferences _prefs;
  double bgmVolume;
  double voiceVolume;
  double sfxVolume;
  bool reducedMotion;
  bool colorblindShapes;
  double touchOffset; // pixels above finger during drag (mobile only)

  static Future<GameSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return GameSettings._(p);
  }

  Future<void> save() async {
    await _prefs.setDouble(_kBgm, bgmVolume);
    await _prefs.setDouble(_kVoice, voiceVolume);
    await _prefs.setDouble(_kSfx, sfxVolume);
    await _prefs.setBool(_kReducedMotion, reducedMotion);
    await _prefs.setBool(_kColorblindShapes, colorblindShapes);
    await _prefs.setDouble(_kTouchOffset, touchOffset);
  }
}
