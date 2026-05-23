import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show TextStyle, FontWeight, FontStyle;

import 'package:shared_preferences/shared_preferences.dart';

import 'audio/sfx.dart';
import 'audio/voice.dart';
import 'components/atmosphere.dart';
import 'components/backdrop.dart';
import 'components/demon.dart';
import 'components/effects.dart';
import 'components/hazards.dart';
import 'components/items.dart';
import 'components/lantern.dart';
import 'components/number_hud.dart';
import 'components/paper.dart';
import 'components/projectile.dart';
import 'components/samurai.dart';
import 'components/shader_effects.dart';
import 'components/torii.dart';
import 'components/trail.dart';
import 'kits.dart';
import 'levels.dart';
import 'runs/game_run.dart';
import 'runs/run_records.dart';
import 'scenes/credits_screen.dart';
import 'scenes/how_to_play.dart';
import 'scenes/kit_select.dart';
import 'scenes/level_select.dart';
import 'scenes/pause_screen.dart';
import 'scenes/run_results.dart';
import 'scenes/scene_fader.dart';
import 'scenes/settings_screen.dart';
import 'scenes/story_card.dart';
import 'scenes/title_screen.dart';
import 'settings.dart';
import 'shaders.dart';
import 'stats.dart';
import 'story.dart';

enum GamePhase { plan, running, victory, defeat }

enum AppScene { title, menu, gameplay, settings }

class FlamekutGame extends FlameGame {
  FlamekutGame({this.overrideLevelJson});

  /// If set, skips the asset manifest and uses this single level. Drops the
  /// player straight into gameplay, no title or level-select. Used by the
  /// editor's "test this level" mode.
  final String? overrideLevelJson;

  static const double worldW = 1080;
  static const double worldH = 1920;

  GamePhase phase = GamePhase.plan;

  late final Samurai samurai;
  late final Torii torii;
  late List<Demon> demons = const [];
  late List<Hazard> hazards = const [];
  late List<ItemPickup> items = const [];
  late final PathTrail trail;
  late final MotionTrail motionTrail;
  late final RunTone runTone;
  late final SlowTone slowTone;
  late final HypeAura hypeAura;
  late final NumberHUD numberHud;
  late final Voice voice;
  late final Bgm bgm;
  late final SfxBank sfx;
  final Shaders shaders = Shaders();

  AppScene scene = AppScene.title;
  AppScene? _previousScene;
  List<LevelData> allLevels = const [];
  List<LevelData> _authoredLevels = const [];
  late StatsStore statsStore;
  late GameSettings settings;
  late StoryProgress storyProgress;
  late RunRecords runRecords;
  late KitStore kitStore;

  /// Currently equipped samurai variant.
  SamuraiKit get activeKit => kitStore.active;

  /// Total stars across all authored levels (used for kit unlocks).
  int get totalStars {
    if (_authoredLevels.isEmpty) return 0;
    var sum = 0;
    for (final l in _authoredLevels) {
      sum += statsStore.recordFor(l.id).stars;
    }
    return sum;
  }

  /// Active chained-level run (Endless / Speedrun) or null for normal play.
  GameRun? activeRun;
  double _runFreshLevelStartT = 0; // wall-clock when the current level was loaded
  int currentLevel = 0;
  LevelSelect? _levelSelect;
  TitleScreen? _titleScreen;
  SettingsScreen? _settingsScreen;
  PauseScreen? _pauseScreen;
  PauseButton? _pauseBtn;
  HowToPlay? _howToPlay;
  bool _wasPaused = false;
  double _runStartT = 0;

  /// Time scale applied to enemy/projectile/hazard/item motion. Slowed
  /// by samurai's Slow power-up.
  double get worldTimeScale => samurai.isSlow ? 0.42 : 1.0;

  final List<Vector2> pathPoints = [];
  bool drawing = false;

  int combo = 0;
  int demonsAlive = 0;

  Vector2 get spawnPoint => Vector2(worldW * 0.5, worldH * 0.84);

  late TextComponent _subHud;
  late TextComponent _hint;
  late TextComponent _outcome;

  @override
  Color backgroundColor() => const Color(0xFFEFE7D6);

  @override
  Future<void> onLoad() async {
    voice = Voice();
    bgm = Bgm();
    sfx = SfxBank();
    unawaited(voice.preload());
    unawaited(sfx.preload());

    // Load shaders + stats + settings.
    await shaders.load();
    statsStore = await StatsStore.load();
    settings = await GameSettings.load();
    voice.voiceVolume = settings.voiceVolume;
    sfx.sfxVolume = settings.sfxVolume;
    storyProgress = await StoryProgress.load();
    runRecords = await RunRecords.load();
    kitStore = await KitStore.load();

    // Levels: editor override takes precedence over the asset manifest.
    if (overrideLevelJson != null) {
      allLevels = [parseLevelJson(overrideLevelJson!)];
    } else {
      _authoredLevels = await loadLevels();
      allLevels = _authoredLevels;
    }

    camera = CameraComponent.withFixedResolution(
      world: world,
      width: worldW,
      height: worldH,
    );
    camera.viewfinder.position = Vector2(worldW / 2, worldH / 2);

    await world.add(PaperBackground(size: Vector2(worldW, worldH)));
    await world.add(Backdrop());
    await world.add(Atmosphere(worldSize: Vector2(worldW, worldH)));

    samurai = Samurai(initialPosition: spawnPoint);
    await world.add(samurai);

    torii = Torii(position: Vector2(worldW * 0.5, worldH * 0.14));
    await world.add(torii);

    // Two flanking lanterns — they rely on torii position.
    await world.add(Lantern(position: Vector2(worldW * 0.5 - 200, worldH * 0.18)));
    await world.add(Lantern(
      position: Vector2(worldW * 0.5 + 200, worldH * 0.18),
      phase: 1.7,
    ));

    // Levels are loaded on demand via startLevel; menu starts empty.
    demons = const [];
    hazards = const [];
    items = const [];
    demonsAlive = 0;

    trail = PathTrail();
    await world.add(trail);

    motionTrail = MotionTrail();
    await world.add(motionTrail);

    runTone = RunTone();
    await world.add(runTone);
    slowTone = SlowTone();
    await world.add(slowTone);
    hypeAura = HypeAura();
    await world.add(hypeAura);

    await world.add(InputBackdrop(size: Vector2(worldW, worldH)));

    numberHud = NumberHUD(position: Vector2(60, 50));
    await camera.viewport.add(numberHud);

    _subHud = TextComponent(
      text: '',
      position: Vector2(60, 230),
      anchor: Anchor.topLeft,
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 30,
          fontWeight: FontWeight.w400,
          letterSpacing: 4,
        ),
      ),
    );
    await camera.viewport.add(_subHud);

    _hint = TextComponent(
      text: 'drag to draw a path · tap the gate to begin',
      position: Vector2(worldW / 2, worldH - 100),
      anchor: Anchor.center,
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0x991A1612),
          fontSize: 30,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ),
      ),
    );
    await camera.viewport.add(_hint);

    _outcome = TextComponent(
      text: '',
      position: Vector2(worldW / 2, worldH * 0.5),
      anchor: Anchor.center,
      priority: 2000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xEEEFE7D6),
          fontSize: 76,
          fontWeight: FontWeight.w300,
          letterSpacing: 12,
          shadows: [
            Shadow(color: Color(0xFF1A1612), blurRadius: 16),
            Shadow(color: Color(0xCC1A1612), blurRadius: 4),
          ],
        ),
      ),
    );
    await camera.viewport.add(_outcome);

    _updateHud();

    // Boot to title screen with music. Editor override skips the menu
    // and drops straight into gameplay.
    unawaited(bgm.play('music/ronin.mp3', volume: settings.bgmVolume));
    if (overrideLevelJson != null) {
      await startLevel(0);
    } else {
      await enterTitleScreen();
      // First-launch only: surface the how-to-play once.
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool('seen_how_to_play') ?? false)) {
        await p.setBool('seen_how_to_play', true);
        await openHowToPlay();
      }
    }
  }

  @override
  void onRemove() {
    bgm.stop();
    super.onRemove();
  }

  // ---------- scene transitions ----------

  /// Spawns a quick ink-wipe transition on top of everything.
  void _pushFade() {
    camera.viewport.add(SceneFader());
  }

  Future<void> enterTitleScreen() async {
    scene = AppScene.title;
    _pushFade();
    _clearLevelEntities();
    // Center the samurai on the title for atmosphere.
    samurai.resetToStart(Vector2(worldW * 0.50, worldH * 0.62));
    samurai.setTitlePose();
    pathPoints.clear();
    trail.clear();
    motionTrail.clear();
    runTone.setRunning(false);
    drawing = false;
    combo = 0;
    demonsAlive = 0;
    phase = GamePhase.plan;
    _outcome.text = '';
    _hint.text = '';
    _subHud.text = '';
    numberHud.reset();
    _levelSelect?.removeFromParent();
    _levelSelect = null;
    if (_titleScreen == null || !_titleScreen!.isMounted) {
      _titleScreen = TitleScreen();
      await world.add(_titleScreen!);
    }
  }

  Future<void> openSettings() async {
    if (_settingsScreen != null && _settingsScreen!.isMounted) return;
    _previousScene = scene;
    scene = AppScene.settings;
    _settingsScreen = SettingsScreen();
    await world.add(_settingsScreen!);
  }

  Future<void> closeSettings() async {
    _settingsScreen?.removeFromParent();
    _settingsScreen = null;
    scene = _previousScene ?? AppScene.title;
  }

  Future<void> openHowToPlay() async {
    if (_howToPlay != null && _howToPlay!.isMounted) return;
    _howToPlay = HowToPlay();
    await world.add(_howToPlay!);
  }

  void afterHowToPlay() {
    _howToPlay = null;
  }

  KitSelect? _kitSelect;
  CreditsScreen? _credits;

  Future<void> openKitSelect() async {
    if (_kitSelect != null && _kitSelect!.isMounted) return;
    _kitSelect = KitSelect();
    await world.add(_kitSelect!);
  }

  void closeKitSelect() {
    _kitSelect?.removeFromParent();
    _kitSelect = null;
  }

  Future<void> openCredits() async {
    if (_credits != null && _credits!.isMounted) return;
    _credits = CreditsScreen();
    await world.add(_credits!);
  }

  void closeCredits() {
    _credits?.removeFromParent();
    _credits = null;
  }

  /// Begin a chained run (endless / speedrun). Loads the run's first level
  /// directly (no story, no menu) and tracks total elapsed time.
  Future<void> startRun(GameRun run) async {
    activeRun = run;
    activeRun!.reset();
    _pushFade();
    _titleScreen?.removeFromParent();
    _titleScreen = null;
    _levelSelect?.removeFromParent();
    _levelSelect = null;
    final json = run.nextLevelJson(0);
    if (json == null) return;
    await _loadRunLevel(json);
  }

  Future<void> _loadRunLevel(String json) async {
    scene = AppScene.gameplay;
    _pushFade();
    _clearLevelEntities();
    samurai.resetToStart(spawnPoint);
    pathPoints.clear();
    trail.clear();
    motionTrail.clear();
    runTone.setRunning(false);
    drawing = false;
    combo = 0;
    demonsAlive = 0;
    phase = GamePhase.plan;
    _outcome.text = '';
    numberHud.reset();

    // Reset the camera back to whole-world view (the previous level's
    // victory zoom would otherwise persist into the next level).
    _resetCamera();

    // Replace allLevels with a single in-memory level for this leg.
    allLevels = [parseLevelJson(json)];
    currentLevel = 0;

    _hint.text = 'drag to draw a path · tap the gate to begin';
    if (!_hint.isMounted) {
      await world.add(_hint);
    }
    await _loadLevelEntities();
    _updateHud();

    if (_pauseBtn == null || !_pauseBtn!.isMounted) {
      _pauseBtn = PauseButton();
      await world.add(_pauseBtn!);
    }

    _runFreshLevelStartT = _now();
  }

  Future<void> resetAllProgress() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('level_records_v1');
    statsStore = await StatsStore.load();
    await storyProgress.reset();
    await runRecords.reset();
    await kitStore.reset();
    // Bounce back to title to reflect cleared state.
    closeSettings();
    await enterTitleScreen();
  }

  Future<void> enterLevelSelect() async {
    scene = AppScene.menu;
    _pushFade();
    activeRun = null;
    // Restore the authored level list (run modes replace it with a single
    // in-memory level).
    if (_authoredLevels.isNotEmpty) {
      allLevels = _authoredLevels;
    }
    // Tear down title or whatever was loaded for the level.
    _titleScreen?.removeFromParent();
    _titleScreen = null;
    _pauseScreen?.removeFromParent();
    _pauseScreen = null;
    _pauseBtn?.removeFromParent();
    _pauseBtn = null;
    paused = false;
    _clearLevelEntities();
    samurai.resetToStart(spawnPoint);
    pathPoints.clear();
    trail.clear();
    motionTrail.clear();
    runTone.setRunning(false);
    drawing = false;
    combo = 0;
    demonsAlive = 0;
    phase = GamePhase.plan;
    _outcome.text = '';
    _hint.text = '';
    _subHud.text = '';
    numberHud.reset();
    unawaited(bgm.setVolume(0.30));

    // Snap the camera back to whole-world view if a tween left it elsewhere.
    _resetCamera();

    if (_levelSelect == null) {
      _levelSelect = LevelSelect();
      await world.add(_levelSelect!);
    } else if (!_levelSelect!.isMounted) {
      await world.add(_levelSelect!);
      _levelSelect = LevelSelect();
      await world.add(_levelSelect!);
    } else {
      // Already mounted — refresh by recreating to pick up new stars.
      _levelSelect!.removeFromParent();
      _levelSelect = LevelSelect();
      await world.add(_levelSelect!);
    }
  }

  Future<void> startLevel(int idx) async {
    if (idx < 0 || idx >= allLevels.length) return;
    currentLevel = idx;
    scene = AppScene.gameplay;
    _pushFade();
    _levelSelect?.removeFromParent();
    _levelSelect = null;

    // Show act intro if this level has one and we haven't shown it yet
    // this playthrough. Editor-test mode skips intros.
    final intro = kLevelIntros[idx];
    if (intro != null &&
        overrideLevelJson == null &&
        !storyProgress.hasSeenIntro(idx)) {
      await storyProgress.markIntroSeen(idx);
      // Pre-roll the level entities behind the story card so the world
      // is ready when the card dismisses.
      await _stageGameplayAfterStory(intro);
      return;
    }

    await _resumeGameplaySetup();
  }

  Future<void> _stageGameplayAfterStory(StoryBeat beat) async {
    final card = StoryCard(
      beat: beat,
      onDismiss: () {
        unawaited(_resumeGameplaySetup());
      },
    );
    await world.add(card);
  }

  Future<void> _resumeGameplaySetup() async {
    _hint.text = 'drag to draw a path · tap the gate to begin';
    if (!_hint.isMounted) {
      await camera.viewport.add(_hint);
    }
    await _loadLevelEntities();
    _updateHud();

    // Pause button (top-right) lives on viewport so the victory zoom
    // doesn't scale it.
    if (_pauseBtn == null || !_pauseBtn!.isMounted) {
      _pauseBtn = PauseButton();
      await camera.viewport.add(_pauseBtn!);
    }
  }

  Future<void> pauseGameplay() async {
    if (scene != AppScene.gameplay) return;
    _wasPaused = paused;
    paused = true;
    _pauseScreen = PauseScreen();
    await world.add(_pauseScreen!);
  }

  Future<void> resumeGameplay() async {
    _pauseScreen?.removeFromParent();
    _pauseScreen = null;
    paused = _wasPaused;
  }

  Future<void> exitToLevelSelect() async {
    _pauseScreen?.removeFromParent();
    _pauseScreen = null;
    paused = false;
    _pauseBtn?.removeFromParent();
    _pauseBtn = null;
    if (activeRun != null) {
      // Quitting a run mid-flight ends it (and submits whatever progress).
      await _failRun();
      return;
    }
    if (overrideLevelJson != null) {
      // Editor test mode: nothing to return to. Just reset same level.
      await startLevel(0);
    } else {
      await enterLevelSelect();
    }
  }

  void _clearLevelEntities() {
    for (final d in demons) {
      d.removeFromParent();
    }
    for (final h in hazards) {
      h.removeFromParent();
    }
    for (final it in items) {
      it.removeFromParent();
    }
    for (final c in world.children.whereType<Projectile>().toList()) {
      c.removeFromParent();
    }
    for (final c in world.children.whereType<RedSun>().toList()) {
      c.removeFromParent();
    }
    for (final c in world.children.whereType<BlackMist>().toList()) {
      c.removeFromParent();
    }
    demons = const [];
    hazards = const [];
    items = const [];
  }

  Future<void> _loadLevelEntities() async {
    _clearLevelEntities();
    final lvl = allLevels[currentLevel];
    demons = lvl.demons(worldW, worldH);
    for (final d in demons) {
      await world.add(d);
    }
    demonsAlive = demons.length;
    hazards = lvl.hazards(worldW, worldH);
    for (final h in hazards) {
      await world.add(h);
    }
    items = lvl.items(worldW, worldH);
    for (final it in items) {
      await world.add(it);
    }
  }


  void _updateHud() {
    if (scene == AppScene.menu) {
      _subHud.text = '';
      return;
    }
    final lvlName = allLevels[currentLevel].name;
    if (phase == GamePhase.plan) {
      _subHud.text = 'demons · $demonsAlive    ${currentLevel + 1}. $lvlName';
    } else {
      final mom = samurai.momentumFactor;
      final dots = mom <= 0.01 ? '' : '   ${'·' * (1 + (mom * 4).round())}';
      _subHud.text = 'demons · $demonsAlive$dots';
    }
  }

  // ---------- planning ----------

  // Inset from world edges so the brushstroke never kisses the border.
  static const double _pathInset = 36;

  Vector2 _clamp(Vector2 v) {
    return Vector2(
      v.x.clamp(_pathInset, worldW - _pathInset),
      v.y.clamp(_pathInset, worldH - _pathInset),
    );
  }

  /// On touch platforms (iOS/Android), shift the drag origin upward so the
  /// finger doesn't cover the samurai/path. Mouse platforms get no offset.
  Vector2 _touchOffset() {
    if (kIsTouchPlatform) {
      return Vector2(0, -settings.touchOffset);
    }
    return Vector2.zero();
  }

  static final bool kIsTouchPlatform = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  void beginDraw(Vector2 worldPos) {
    if (phase != GamePhase.plan) return;
    drawing = true;
    pathPoints.clear();
    pathPoints.add(spawnPoint.clone());
    final adjusted = worldPos + _touchOffset();
    final clamped = _clamp(adjusted);
    if ((clamped - spawnPoint).length > 18) {
      pathPoints.add(clamped);
      samurai.position.setFrom(clamped);
      samurai.faceTowards(spawnPoint);
    } else {
      samurai.position.setFrom(spawnPoint);
    }
    trail.setPoints(pathPoints);
  }

  void extendDraw(Vector2 worldPos) {
    if (!drawing) return;
    if (pathPoints.isEmpty) {
      // Defensive: a level reset may have cleared the path mid-drag.
      drawing = false;
      return;
    }
    final adjusted = worldPos + _touchOffset();
    final clamped = _clamp(adjusted);
    final last = pathPoints.last;
    if ((clamped - last).length2 < 16 * 16) return;
    pathPoints.add(clamped);
    trail.setPoints(pathPoints);
    samurai.position.setFrom(clamped);
    samurai.faceTowards(pathPoints[pathPoints.length - 2]);
  }

  void endDraw() {
    drawing = false;
    if (pathPoints.length < 2) {
      pathPoints.clear();
      trail.clear();
      samurai.resetToStart(spawnPoint);
    }
  }

  void commitAndRun() {
    if (phase != GamePhase.plan) return;
    if (pathPoints.length < 2) return;
    if (scene != AppScene.gameplay) return;
    phase = GamePhase.running;
    _hint.removeFromParent();
    voice.play(VoiceLine.go);
    samurai.beginRunning(pathPoints, onArrived: _onArrived);
    runTone.setRunning(true);
    _runStartT = _now();
    _updateHud();
  }

  double _now() => DateTime.now().millisecondsSinceEpoch / 1000.0;

  /// Stops any in-flight camera tween and snaps + tweens back to the
  /// whole-world view. Safe to call between levels.
  void _resetCamera() {
    // Remove any active CameraTween/CameraImpact still running so they
    // don't fight the new tween.
    for (final c in children.whereType<CameraTween>().toList()) {
      c.removeFromParent();
    }
    for (final c in children.whereType<CameraImpact>().toList()) {
      c.removeFromParent();
    }
    add(CameraTween(
      vf: camera.viewfinder,
      targetZoom: 1.0,
      targetPos: Vector2(worldW / 2, worldH / 2),
      duration: 0.6,
    ));
  }

  void _onArrived() {
    if (demonsAlive == 0) {
      _victory();
    } else {
      _defeat();
    }
  }

  void onSamuraiHitsDemon(Demon demon) {
    if (phase != GamePhase.running) return;

    // Gate check — numbered demon refuses anyone below its number.
    // Dragon Mode bypasses the number check.
    if (demon.isNumbered &&
        combo < demon.requiredNumber &&
        !samurai.isDragon) {
      _defeatTooSlow(demon);
      return;
    }

    final approach = demon.position - samurai.position;
    final relAngle = angleFromUp(approach) - samurai.angle;
    final isFinal = demonsAlive == 1;
    // Tier scales the juice. Computed BEFORE the increment so combo 0→1 = tier 0.1.
    final preTier = (combo / 10.0).clamp(0.0, 1.0).toDouble();
    final postTier = ((combo + 1) / 10.0).clamp(0.0, 1.0).toDouble();
    // Combos of 3+ get the showy spin cut occasionally; final blow is always spin.
    final useSpin = isFinal || (combo >= 3 && combo % 3 == 2);
    SwordStyle style;
    if (useSpin) {
      style = SwordStyle.spinCut;
    } else {
      // Kit signature biases: ~55% chance to use the kit's signature style.
      final sig = activeKit.signatureStyle;
      final useSig = sig != null && math.Random().nextDouble() < 0.55;
      style = useSig ? _styleFromName(sig) : _styleForAngle(relAngle);
    }

    final slashTint = activeKit.accentColor;

    // Primary slash
    world.add(SwordSlash(
      position: samurai.position.clone(),
      angle: samurai.angle,
      style: style,
      tint: slashTint,
    ));
    // Extra slash arcs scale with tier — at high combo you get fan-cuts.
    final extraSlashes = (postTier * 3).floor(); // 0,1,2,3
    for (var i = 0; i < extraSlashes; i++) {
      final offsetAng = (i + 1) * 0.18 * (i.isEven ? 1 : -1);
      world.add(SwordSlash(
        position: samurai.position.clone(),
        angle: samurai.angle + offsetAng,
        style: i == 0
            ? SwordStyle.diagonalSlash
            : (i == 1 ? SwordStyle.reverseSlash : SwordStyle.horizontalSlash),
        tint: slashTint,
      ));
    }

    world.add(InkSplash(position: demon.position.clone()));
    if (postTier > 0.5) {
      world.add(InkSplash(
        position: demon.position +
            Vector2((math.Random().nextDouble() - 0.5) * 60,
                (math.Random().nextDouble() - 0.5) * 60),
      ));
    }
    sfx.play(Sfx.slash, volumeMul: 0.7 + 0.5 * postTier);
    world.add(KanjiMark(
      position: demon.position - Vector2(0, 70),
      style: style,
    ));
    if (postTier > 0.6) {
      // Second kanji mark at samurai for hyped combos
      world.add(KanjiMark(
        position: samurai.position + Vector2(0, -120),
        style: useSpin ? SwordStyle.thrust : SwordStyle.spinCut,
      ));
    }

    // ImpactFlash: scale size with tier
    world.add(ImpactFlash(
      position: demon.position.clone(),
      big: isFinal || postTier > 0.7,
    ));
    // Real bloom via fragment shader — additive radial glow.
    final glowColor = Color.lerp(
      const Color(0xFFFFE6BE),
      const Color(0xFFFF6E3A),
      postTier,
    )!;
    world.add(ShaderGlow(
      position: demon.position.clone(),
      color: glowColor,
      radius: 280 + 140 * postTier,
      peak: 0.9 + 0.4 * postTier,
      hotCore: 0.4 + 0.5 * postTier,
      duration: 0.36 + 0.08 * postTier,
    ));
    // Chromatic burst at higher combo — RGB-split rim flash (skipped if
    // the player turned on reduced motion).
    if (combo + 1 >= 5 && !settings.reducedMotion) {
      world.add(ChromaticBurst(
        intensity: 0.4 + 0.6 * postTier,
        duration: 0.28 + 0.08 * postTier,
      ));
    }

    // ScreenPulse: alpha + warmth shift with tier
    final pulseColor = Color.lerp(
      const Color(0xFFFFF5E0),
      const Color(0xFFFFB86A),
      postTier,
    )!;
    world.add(ScreenPulse(
      color: isFinal ? const Color(0xFFFFE2C0) : pulseColor,
      peak: 0.18 + 0.18 * postTier + (isFinal ? 0.10 : 0.0),
      dur: 0.18 + 0.10 * postTier,
    ));

    final cutAngle = math.atan2(approach.y, approach.x) + math.pi / 2;
    demon.die(cutAngle);

    // Momentum is kit-driven — Fox builds it fast, Wraith slow, etc.
    final gain = activeKit.momentumGain;
    samurai.addMomentum(isFinal ? gain * 1.4 : gain * (1 + 0.25 * preTier));

    demonsAlive--;
    combo++;
    voice.playCombo(combo);
    // Stacked taunt voice on top of combo voice for hype thresholds
    if (combo == 5) voice.play(VoiceLine.kira);
    if (combo == 7) voice.play(VoiceLine.killMore);
    if (combo == 9) voice.play(VoiceLine.dragonCut);
    if (combo == 10) voice.play(VoiceLine.noRegrets);

    _updateHud();
    numberHud.bump();
    hypeAura.bump();

    // BGM volume swells with combo for that "the music is hyping" feel.
    final vol = 0.30 + 0.25 * postTier;
    unawaited(bgm.setVolume(vol));

    samurai.flinch(approach);
    // Hit punch — zoom in, hold, ease out + shake. Scales with combo.
    // Reduced motion mode dampens shake + zoom for accessibility.
    final motionMul = settings.reducedMotion ? 0.35 : 1.0;
    final shakeIntensity =
        ((isFinal ? 22.0 : 12.0) + 14 * postTier) * motionMul;
    final peakZoom = 1.0 +
        (0.10 + 0.10 * postTier + (isFinal ? 0.06 : 0)) * motionMul;
    final punchDur = 0.36 + 0.10 * postTier;
    add(CameraImpact(
      vf: camera.viewfinder,
      peakZoom: peakZoom,
      shakeIntensity: shakeIntensity,
      duration: punchDur,
      panToward: demon.position.clone(),
      panAmount: (0.05 + 0.03 * postTier) * motionMul,
    ));
    _hitstop((isFinal ? 130 : 95) + (40 * postTier).round());
  }

  /// Pickup callback fired by ItemPickup.
  void onItemPickup(ItemPickup item) {
    switch (item.kind) {
      case PowerUp.dragon:
        samurai.activateDragon();
        voice.play(VoiceLine.dragonCut);
        world.add(ScreenPulse(
          color: const Color(0xFFFF8A50),
          peak: 0.30,
          dur: 0.35,
        ));
        break;
      case PowerUp.slow:
        samurai.activateSlow();
        world.add(ScreenPulse(
          color: const Color(0xFF82C8DC),
          peak: 0.28,
          dur: 0.40,
        ));
        break;
      case PowerUp.ghost:
        samurai.activateGhost();
        world.add(ScreenPulse(
          color: const Color(0xFFB69ED2),
          peak: 0.28,
          dur: 0.40,
        ));
        break;
    }
    world.add(ImpactFlash(position: item.position.clone()));
  }

  Future<void> _hitstop(int ms) async {
    paused = true;
    await Future<void>.delayed(Duration(milliseconds: ms));
    paused = false;
  }

  SwordStyle _styleFromName(String name) => switch (name) {
        'thrust' => SwordStyle.thrust,
        'horizontalSlash' => SwordStyle.horizontalSlash,
        'verticalChop' => SwordStyle.verticalChop,
        'diagonalSlash' => SwordStyle.diagonalSlash,
        'reverseSlash' => SwordStyle.reverseSlash,
        'spinCut' => SwordStyle.spinCut,
        _ => SwordStyle.horizontalSlash,
      };

  /// Map relative angle (samurai-heading → demon) to a sword style.
  /// 8 sectors of 45° each. Forward sectors prefer thrust/diagonals;
  /// side sectors prefer the wide arc; back is rare but gets the chop.
  SwordStyle _styleForAngle(double rel) {
    final a = (rel + math.pi * 4) % (math.pi * 2);
    final sector = ((a / (math.pi / 4)).round()) % 8;
    switch (sector) {
      case 0:
        return SwordStyle.thrust;
      case 1:
        return SwordStyle.diagonalSlash;
      case 2:
        return SwordStyle.horizontalSlash;
      case 3:
        return SwordStyle.reverseSlash;
      case 4:
        return SwordStyle.verticalChop;
      case 5:
        return SwordStyle.diagonalSlash;
      case 6:
        return SwordStyle.horizontalSlash;
      case 7:
      default:
        return SwordStyle.reverseSlash;
    }
  }

  // ---------- victory / defeat ----------

  Future<void> _victory() async {
    phase = GamePhase.victory;
    trail.fade();
    runTone.setVictory();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    voice.play(VoiceLine.winner);

    add(CameraTween(
      vf: camera.viewfinder,
      targetZoom: 1.7,
      targetPos: samurai.position.clone(),
      duration: 1.2,
    ));

    samurai.beginVictoryPose();

    // Red sun behind samurai
    await world.add(RedSun(position: samurai.position.clone()));

    await Future<void>.delayed(const Duration(milliseconds: 600));
    await world.add(BlackMist(position: samurai.position.clone()));

    // Samurai dissolves into the mist — gone by the time the cloud peaks.
    samurai.vanishOver(1.4);

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    voice.play(VoiceLine.newJourney);

    final runActive = activeRun;
    final elapsed = runActive != null && runActive.strictTimer
        ? _now() - _runFreshLevelStartT
        : _now() - _runStartT;
    final lvl = allLevels[currentLevel];
    final stars = starsFor(elapsed, lvl.thresholds.three, lvl.thresholds.two);
    if (runActive == null) {
      await statsStore.submit(
        levelId: lvl.id,
        stars: stars,
        timeSec: elapsed,
      );
    } else {
      runActive.elapsedSec += elapsed;
      runActive.levelsCompleted += 1;
    }
    // Rotate BGM track between levels for variety (only outside runs).
    if (runActive == null) {
      unawaited(bgm.nextTrack());
    }

    // Run mode: short outcome, then advance.
    if (runActive != null) {
      _outcome.text =
          '${runActive.levelsCompleted} · ${runActive.elapsedSec.toStringAsFixed(2)}s';
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final next = runActive.nextLevelJson(runActive.levelsCompleted);
      if (next == null) {
        await _completeRun();
      } else {
        await _loadRunLevel(next);
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 2200));
    final starGlyph = '★' * stars + '☆' * (3 - stars);
    final outcomeLine = pickOutcome(
      kVictoryOutcomes,
      currentLevel * 7 + stars,
    );
    _outcome.text = '$starGlyph    ${elapsed.toStringAsFixed(2)}s\n$outcomeLine';

    await Future<void>.delayed(const Duration(milliseconds: 2400));

    // Endings: check if we just unlocked a milestone
    if (overrideLevelJson == null) {
      final ending = _checkForEnding();
      if (ending != null) {
        await _showEndingCard(ending.beat, ending.key);
        return;
      }
    }

    if (overrideLevelJson != null) {
      await startLevel(0);
    } else {
      await enterLevelSelect();
    }
  }

  /// Finish a run cleanly — submit best + show results scene.
  Future<void> _completeRun() async {
    final run = activeRun;
    if (run == null) return;
    final improved = await runRecords.submit(
      runId: run.id,
      elapsedSec: run.elapsedSec,
      levelsCompleted: run.levelsCompleted,
    );
    activeRun = null;
    await _showRunResults(run, improved, completed: true);
  }

  Future<void> _failRun() async {
    final run = activeRun;
    if (run == null) return;
    final improved = await runRecords.submit(
      runId: run.id,
      elapsedSec: run.elapsedSec,
      levelsCompleted: run.levelsCompleted,
    );
    activeRun = null;
    await _showRunResults(run, improved, completed: false);
  }

  Future<void> _showRunResults(GameRun run, bool improved, {required bool completed}) async {
    final card = RunResultsScreen(
      runTitle: run.title,
      runId: run.id,
      elapsedSec: run.elapsedSec,
      levelsCompleted: run.levelsCompleted,
      completed: completed,
      improved: improved,
      onDismiss: () {
        unawaited(enterLevelSelect());
      },
    );
    await world.add(card);
  }

  ({StoryBeat beat, String key})? _checkForEnding() {
    final ids = allLevels.map((l) => l.id).toList();
    final allCompleted =
        ids.every((id) => statsStore.recordFor(id).completed);
    if (!allCompleted) return null;

    final allThreeStar =
        ids.every((id) => statsStore.recordFor(id).stars >= 3);

    if (allThreeStar && !storyProgress.hasSeenEnding('three_star')) {
      return (beat: kThreeStarEnding, key: 'three_star');
    }
    if (!storyProgress.hasSeenEnding('first_clear')) {
      return (beat: kFirstClearEnding, key: 'first_clear');
    }
    return null;
  }

  Future<void> _showEndingCard(StoryBeat beat, String key) async {
    await storyProgress.markEndingSeen(key);
    final card = StoryCard(
      beat: beat,
      onDismiss: () {
        unawaited(enterLevelSelect());
      },
    );
    await world.add(card);
  }

  Future<void> _defeat() async {
    phase = GamePhase.defeat;
    voice.play(VoiceLine.dying);
    _outcome.text = pickOutcome(kDefeatOutcomes, currentLevel * 5 + combo);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (activeRun != null) {
      await _failRun();
      return;
    }
    if (overrideLevelJson != null) {
      await startLevel(0);
    } else {
      await enterLevelSelect();
    }
  }

  /// Spawn a projectile in the world (called by TurretDemon).
  void spawnProjectile(Vector2 origin, Vector2 velocity) {
    world.add(Projectile(position: origin, velocity: velocity));
  }

  /// Samurai contacted a hazard during run — instant defeat, cool palette.
  /// Dragon Mode is invulnerable; Ghost Mode passes through Walls only.
  Future<void> onHazardHitsSamurai(Hazard h) async {
    if (phase != GamePhase.running) return;
    if (samurai.isDragon) return;
    if (samurai.isGhost && h is Wall) return;
    phase = GamePhase.defeat;
    voice.play(VoiceLine.dying);
    world.add(ImpactFlash(position: samurai.position.clone(), big: true));
    world.add(InkSplash(position: samurai.position.clone()));
    world.add(ScreenPulse(
      color: const Color(0xFF82D8C8),
      peak: 0.40,
      dur: 0.32,
    ));
    samurai.flinch(h.position - samurai.position);
    sfx.play(Sfx.hurt);
    world.add(FailureMarker(
      position: h.position.clone(),
      label: 'avoid this',
    ));
    _outcome.text =
        pickOutcome(kConsumedOutcomes, currentLevel * 4 + combo);
    paused = true;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    paused = false;
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (activeRun != null) {
      await _failRun();
      return;
    }
    if (overrideLevelJson != null) {
      await startLevel(0);
    } else {
      await enterLevelSelect();
    }
  }

  /// Samurai eats a projectile during run.
  Future<void> onProjectileHitsSamurai(Projectile projectile) async {
    if (phase != GamePhase.running) return;
    if (samurai.isDragon) return; // shrugged off
    phase = GamePhase.defeat;
    voice.play(VoiceLine.dying);
    sfx.play(Sfx.hurt, volumeMul: 1.2);
    world.add(ImpactFlash(position: samurai.position.clone(), big: true));
    world.add(InkSplash(position: samurai.position.clone()));
    world.add(ScreenPulse(
      color: const Color(0xFFE5392B),
      peak: 0.42,
      dur: 0.32,
    ));
    world.add(FailureMarker(
      position: samurai.position.clone(),
      label: 'struck down',
    ));
    samurai.flinch(projectile.velocity);
    _outcome.text =
        pickOutcome(kStruckOutcomes, currentLevel * 3 + combo);
    paused = true;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    paused = false;
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (activeRun != null) {
      await _failRun();
      return;
    }
    if (overrideLevelJson != null) {
      await startLevel(0);
    } else {
      await enterLevelSelect();
    }
  }

  /// Player ran into a numbered demon with insufficient number.
  /// Big visual rejection + voice line.
  Future<void> _defeatTooSlow(Demon demon) async {
    phase = GamePhase.defeat;
    voice.play(VoiceLine.tooSlow);
    // Visual feedback: flash + ink splash but the demon survives.
    world.add(ImpactFlash(position: demon.position.clone(), big: true));
    world.add(ScreenPulse(
      color: const Color(0xFFE5392B),
      peak: 0.32,
      dur: 0.32,
    ));
    samurai.flinch(demon.position - samurai.position);
    sfx.play(Sfx.hurt);
    final need = demon.requiredNumber;
    world.add(FailureMarker(
      position: demon.position.clone(),
      label: 'need $need · had $combo',
      duration: 2.4,
    ));
    _outcome.text =
        pickOutcome(kTooSlowOutcomes, currentLevel * 2 + combo);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    paused = true;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    paused = false;
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (activeRun != null) {
      await _failRun();
      return;
    }
    if (overrideLevelJson != null) {
      await startLevel(0);
    } else {
      await enterLevelSelect();
    }
  }
}

class InputBackdrop extends PositionComponent
    with DragCallbacks, TapCallbacks, HasGameReference<FlamekutGame> {
  InputBackdrop({required Vector2 size})
      : super(size: size, priority: -100);

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.beginDraw(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    game.extendDraw(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.endDraw();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (game.phase == GamePhase.plan) {
      game.pathPoints.clear();
      game.trail.clear();
      game.samurai.resetToStart(game.spawnPoint);
    }
  }
}

class CameraTween extends Component {
  CameraTween({
    required this.vf,
    required this.targetZoom,
    required this.targetPos,
    required this.duration,
  });

  final Viewfinder vf;
  final double targetZoom;
  final Vector2 targetPos;
  final double duration;

  late final double _startZoom = vf.zoom;
  late final Vector2 _startPos = vf.position.clone();
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    final p = (_t / duration).clamp(0.0, 1.0);
    final e = 1 - math.pow(1 - p, 3).toDouble();
    vf.zoom = _startZoom + (targetZoom - _startZoom) * e;
    vf.position = _startPos + (targetPos - _startPos) * e;
    if (p >= 1.0) removeFromParent();
  }
}
