import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

double angleFromUp(Vector2 v) => math.atan2(v.x, -v.y);

/// Rotates a local-space offset by [angle] (Flame's screen-clockwise convention).
Offset rotateOffset(double lx, double ly, double angle) {
  final c = math.cos(angle), s = math.sin(angle);
  return Offset(lx * c - ly * s, lx * s + ly * c);
}

class Samurai extends PositionComponent with HasGameReference<FlamekutGame> {
  Samurai({required Vector2 initialPosition})
      : super(
          position: initialPosition,
          anchor: Anchor.center,
          size: Vector2.all(180),
          priority: 10,
        );

  // ----- state -----
  double _bob = 0;
  bool _running = false;
  bool _victoryPose = false;
  double _opacity = 0.65;
  double _flinchT = 0;
  double _victoryT = 0;

  // path-following
  List<Vector2> _path = [];
  double _pathDist = 0;
  double _pathLen = 0;
  final List<double> _segLen = [];
  void Function()? _onArrived;

  // Stats are sourced from the active kit (Ronin / Wraith / etc).
  double get _speed => game.activeKit.speed;
  double get reach => game.activeKit.reach;
  double get _momentumCap => game.activeKit.momentumCap;

  // momentum — additive speed bonus that builds with kills
  double _momentum = 0;
  double get momentum => _momentum;
  double get momentumFactor =>
      _momentumCap == 0 ? 0 : (_momentum / _momentumCap).clamp(0.0, 1.0).toDouble();

  // power-up timers
  double _dragonT = 0;
  double _slowT = 0;
  double _ghostT = 0;
  bool get isDragon => _dragonT > 0;
  bool get isSlow => _slowT > 0;
  bool get isGhost => _ghostT > 0;
  double get dragonT => _dragonT;
  double get slowT => _slowT;
  double get ghostT => _ghostT;

  // vanish (victory dissolve into mist)
  double _vanishDur = 0;
  double _vanishT = 0;
  double _vanishStartOpacity = 1.0;

  // sword red-tinge after a hit (lingers briefly)
  double _bloodTinge = 0;

  bool get isRunning => _running;
  bool get inVictoryPose => _victoryPose;

  /// Sword tip position in world coords (for sword trail / strike origin).
  Vector2 swordTipWorld() {
    final off = rotateOffset(-3, -80, angle);
    return Vector2(position.x + off.dx, position.y + off.dy);
  }

  void facePlanned(Vector2 worldTarget) {
    final delta = worldTarget - position;
    if (delta.length2 < 1) return;
    angle = angleFromUp(delta);
  }

  void faceTowards(Vector2 from) {
    final delta = position - from;
    if (delta.length2 < 1) return;
    angle = angleFromUp(delta);
  }

  void resetToStart(Vector2 start) {
    position.setFrom(start);
    angle = 0;
    _opacity = 0.65;
    _running = false;
    _victoryPose = false;
    _flinchT = 0;
    _vanishDur = 0;
    _vanishT = 0;
    _bloodTinge = 0;
    _momentum = 0;
    _dragonT = 0;
    _slowT = 0;
    _ghostT = 0;
    _path = [];
    _pathDist = 0;
    _pathLen = 0;
    _segLen.clear();
  }

  void beginRunning(List<Vector2> path, {required void Function() onArrived}) {
    _path = path.map((p) => p.clone()).toList();
    _pathDist = 0;
    _segLen.clear();
    _pathLen = 0;
    for (var i = 0; i < _path.length - 1; i++) {
      final l = (_path[i + 1] - _path[i]).length;
      _segLen.add(l);
      _pathLen += l;
    }
    _running = true;
    _opacity = 1.0;
    _onArrived = onArrived;
    position.setFrom(_path.first);
  }

  void flinch(Vector2 hitFromDir) {
    _flinchT = 0.22;
    _bloodTinge = 1.0;
  }

  /// Build momentum on each kill. Persists for the rest of the run.
  void addMomentum(double bump) {
    _momentum = (_momentum + bump).clamp(0.0, _momentumCap);
  }

  /// Switch to title-screen pose — fully visible, idle breathing, no path.
  void setTitlePose() {
    _opacity = 1.0;
    _running = false;
    _victoryPose = false;
  }

  void activateDragon([double dur = 2.6]) =>
      _dragonT = math.max(_dragonT, dur);
  void activateSlow([double dur = 3.2]) => _slowT = math.max(_slowT, dur);
  void activateGhost([double dur = 3.0]) => _ghostT = math.max(_ghostT, dur);

  void beginVictoryPose() {
    _running = false;
    _victoryPose = true;
    _victoryT = 0;
  }

  /// Fade samurai's opacity to zero over [seconds] — used during victory mist.
  void vanishOver(double seconds) {
    _vanishDur = seconds;
    _vanishT = 0;
    _vanishStartOpacity = _opacity;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Cadence accelerates with momentum — running gait quickens.
    final runRate = 9.5 + 4.0 * momentumFactor;
    _bob += dt * (_running ? runRate : 2.5);
    if (_flinchT > 0) _flinchT -= dt;
    if (_bloodTinge > 0) _bloodTinge = (_bloodTinge - dt * 1.6).clamp(0.0, 1.0);
    if (_dragonT > 0) _dragonT -= dt;
    if (_slowT > 0) _slowT -= dt;
    if (_ghostT > 0) _ghostT -= dt;

    if (_vanishDur > 0) {
      _vanishT += dt;
      final p = (_vanishT / _vanishDur).clamp(0.0, 1.0);
      _opacity = _vanishStartOpacity * (1 - p);
      if (p >= 1.0) _vanishDur = 0;
    }

    if (_running) {
      final effSpeed = _speed + _momentum;
      _pathDist += effSpeed * dt;
      if (_pathDist >= _pathLen) {
        _pathDist = _pathLen;
        _running = false;
        if (_path.isNotEmpty) position.setFrom(_path.last);
        final cb = _onArrived;
        _onArrived = null;
        cb?.call();
      } else {
        var d = _pathDist;
        for (var i = 0; i < _segLen.length; i++) {
          if (d <= _segLen[i]) {
            final t = _segLen[i] == 0 ? 0.0 : d / _segLen[i];
            final newPos = _path[i] + (_path[i + 1] - _path[i]) * t;
            final delta = newPos - position;
            if (delta.length2 > 0.1) angle = angleFromUp(delta);
            position.setFrom(newPos);
            break;
          }
          d -= _segLen[i];
        }
      }

      // Push to motion trail.
      game.motionTrail.push(position.clone(), angle);

      // Distance-based collision with demons. Reach is kit-dependent.
      for (final demon in game.demons) {
        if (demon.dead) continue;
        final r = demon.bodyRadius + reach;
        if (demon.position.distanceToSquared(position) < r * r) {
          game.onSamuraiHitsDemon(demon);
        }
      }

      // Hazard collision — pure avoidance, instant defeat.
      for (final hazard in game.hazards) {
        if (hazard.collidesWithPoint(position, 30)) {
          game.onHazardHitsSamurai(hazard);
          break;
        }
      }
    }

    if (_victoryPose) {
      _victoryT += dt;
      angle = _lerpAngle(angle, 0, dt * 2.6);
    }
  }

  double _lerpAngle(double a, double b, double k) {
    final diff = ((b - a + math.pi) % (math.pi * 2)) - math.pi;
    return a + diff * k.clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    // Ghost mode dims the samurai significantly.
    final bodyA = _opacity * (isGhost ? 0.55 : 1.0);
    final flinchAmount = (_flinchT / 0.22).clamp(0.0, 1.0);
    final wobble = math.sin(_bob) * (_running ? 4.5 : 1.5);
    final scale = 1.0 +
        math.sin(_bob * 2) * (_running ? 0.045 : 0.018) +
        flinchAmount * 0.18;

    canvas.save();
    // Local (0,0) is top-left of bounds; shift to center for our drawings.
    canvas.translate(size.x / 2, size.y / 2);

    // Dragon aura — red halo around samurai
    if (isDragon) {
      final dPulse = math.sin(_bob * 1.6) * 0.15 + 1.0;
      final outerAura = Paint()
        ..color = Color.fromRGBO(220, 60, 40, 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
      canvas.drawCircle(Offset.zero, 86 * dPulse, outerAura);
      final innerAura = Paint()
        ..color = Color.fromRGBO(245, 130, 80, 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset.zero, 56 * dPulse, innerAura);
      // Curling flame lines
      final flame = Paint()
        ..color = Color.fromRGBO(245, 130, 80, 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + _bob * 0.4;
        final r1 = 42 + math.sin(_bob * 2 + i) * 4;
        final r2 = 60 + math.cos(_bob * 1.6 + i) * 6;
        canvas.drawLine(
          Offset(math.cos(a) * r1, math.sin(a) * r1),
          Offset(math.cos(a) * r2, math.sin(a) * r2),
          flame,
        );
      }
    }

    // Ghost crosshatch — diagonal hatchlines around the silhouette
    if (isGhost) {
      final hatch = Paint()
        ..color = Color.fromRGBO(164, 138, 190, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      for (var i = -3; i <= 3; i++) {
        canvas.drawLine(
          Offset(-50, i * 12.0 + math.sin(_bob + i) * 1.5),
          Offset(50, i * 12.0 + math.sin(_bob + i) * 1.5),
          hatch,
        );
      }
    }
    if (flinchAmount > 0) {
      final shake = math.sin(_flinchT * 80) * 0.04 * flinchAmount;
      canvas.rotate(shake);
    }
    canvas.scale(scale, scale);
    canvas.translate(0, wobble * 0.15);

    // Momentum aura — a fading red wisp trailing behind during run.
    if (_running && momentumFactor > 0.05) {
      final mf = momentumFactor;
      final tail = Paint()
        ..color = Color.fromRGBO(220, 60, 40, 0.32 * mf * bodyA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, 36 + mf * 22),
          width: 70 + mf * 30,
          height: 80 + mf * 60,
        ),
        tail,
      );
      // Tighter inner streak
      final streak = Paint()
        ..color = Color.fromRGBO(220, 60, 40, 0.55 * mf * bodyA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + mf * 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawLine(
        const Offset(0, 14),
        Offset(0, 60 + mf * 50),
        streak,
      );
    }

    // Drop shadow under body
    final shadow = Paint()
      ..color = Color.fromRGBO(26, 22, 18, 0.30 * bodyA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 10), width: 110, height: 70),
      shadow,
    );

    // Run-cycle stride: alternating leg/hakama hem peek visible at the bottom.
    final stride = _running ? math.sin(_bob * 0.5) : 0.0;

    // Pull palette from active kit so different variants visually differ.
    final kit = game.activeKit;
    final kasaColor = kit.kasaColor;
    final sashColor = kit.sashColor;
    final accentColor = kit.accentColor;
    final sayaColor = kit.sayaColor;

    // ═══════════════════════════════════════════════════════════
    // SAYA (sheath) — extends back-right from the obi belt
    // ═══════════════════════════════════════════════════════════
    final sayaWrap = Paint()
      ..color = sayaColor.withValues(alpha: 0.92 * bodyA);
    final sayaPath = Path()
      ..moveTo(8, 12)
      ..quadraticBezierTo(14, 40, 18, 64)
      ..lineTo(22, 64)
      ..quadraticBezierTo(18, 40, 12, 12)
      ..close();
    canvas.drawPath(sayaPath, sayaWrap);
    // Saya highlight rib
    final sayaHi = Paint()
      ..color = Color.fromRGBO(120, 88, 62, 0.55 * bodyA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(13, 14), const Offset(19, 62), sayaHi);
    // Saya endcap (kojiri)
    final sayaCap = Paint()..color = Color.fromRGBO(28, 18, 12, 0.95 * bodyA);
    canvas.drawCircle(const Offset(20, 64), 4.5, sayaCap);

    // ═══════════════════════════════════════════════════════════
    // HAKAMA (pleated lower trousers, visible behind body)
    // ═══════════════════════════════════════════════════════════
    final hakama = Paint()
      ..color = Color.fromRGBO(34, 32, 38, 0.95 * bodyA)
      ..blendMode = BlendMode.multiply;
    final hakamaPath = Path()
      ..moveTo(-32, 4)
      ..quadraticBezierTo(-38, 24, -36, 42)
      ..lineTo(36, 42)
      ..quadraticBezierTo(38, 24, 32, 4)
      ..close();
    canvas.drawPath(hakamaPath, hakama);
    // Pleat lines (vertical creases)
    final pleat = Paint()
      ..color = Color.fromRGBO(60, 56, 64, 0.55 * bodyA)
      ..strokeWidth = 0.8;
    for (var i = -2; i <= 2; i++) {
      final x = i * 9.0;
      canvas.drawLine(Offset(x, 6), Offset(x + i * 0.7, 38), pleat);
    }
    // Stride hem peek — lighter underleg color visible alternating
    if (_running) {
      final hem = Paint()
        ..color = Color.fromRGBO(80, 70, 56, 0.65 * bodyA);
      final off = stride * 6;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-12 + off, 44),
          width: 16,
          height: 6,
        ),
        hem,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(14 - off, 44),
          width: 16,
          height: 6,
        ),
        hem,
      );
    }

    // ═══════════════════════════════════════════════════════════
    // KOSODE (upper body kimono — peeks under the hat)
    // ═══════════════════════════════════════════════════════════
    final kosode = Paint()
      ..color = Color.fromRGBO(28, 24, 22, 0.92 * bodyA)
      ..blendMode = BlendMode.multiply;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0), width: 64, height: 44),
      kosode,
    );
    // Sode (sleeve pads) — small ovals at shoulders
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-30, 4), width: 22, height: 18),
      kosode,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(30, 4), width: 22, height: 18),
      kosode,
    );
    // V-collar (eri) — two small dark angled lines forming the V at chest
    final collar = Paint()
      ..color = Color.fromRGBO(245, 240, 225, 0.55 * bodyA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-12, -2), const Offset(0, 12), collar);
    canvas.drawLine(const Offset(12, -2), const Offset(0, 12), collar);

    // ═══════════════════════════════════════════════════════════
    // OBI (sash belt) — horizontal across midsection. Kit palette.
    // ═══════════════════════════════════════════════════════════
    final obiShadow = Paint()
      ..color = Color.lerp(sashColor, const Color(0xFF000000), 0.55)!
          .withValues(alpha: 0.85 * bodyA);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 7), width: 70, height: 9),
      obiShadow,
    );
    final obi = Paint()..color = sashColor.withValues(alpha: 0.96 * bodyA);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 6), width: 70, height: 7),
      obi,
    );
    // Obi highlight (toward white)
    final obiHi = Paint()
      ..color = Color.lerp(sashColor, const Color(0xFFFFFFFF), 0.4)!
          .withValues(alpha: 0.65 * bodyA);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 4.5), width: 70, height: 1.2),
      obiHi,
    );

    // ═══════════════════════════════════════════════════════════
    // KATANA — full sword with detail
    // ═══════════════════════════════════════════════════════════
    // Hands wrapping the tsuka (grip)
    final hand = Paint()..color = Color.fromRGBO(48, 32, 24, 0.95 * bodyA);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-8, -2), width: 11, height: 9),
      hand,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(7, -10), width: 10, height: 8),
      hand,
    );
    // Tsuka (grip wrap) — diamond-pattern ito
    final tsukaBase = Paint()..color = Color.fromRGBO(34, 26, 20, 0.95 * bodyA);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(-1, -10), width: 11, height: 16),
      tsukaBase,
    );
    final ito = Paint()
      ..color = Color.fromRGBO(220, 200, 170, 0.70 * bodyA)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    // Diamond X-pattern across the wrap
    for (var i = 0; i < 4; i++) {
      final y = -16 + i * 4.0;
      canvas.drawLine(Offset(-6, y), Offset(4, y + 4), ito);
      canvas.drawLine(Offset(-6, y + 4), Offset(4, y), ito);
    }
    // Kashira (pommel cap at handle butt)
    final kashira = Paint()..color = Color.fromRGBO(20, 17, 14, 0.98 * bodyA);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-1, -3), width: 13, height: 5),
      kashira,
    );

    // Tsuba (guard) — round disc
    final tsuba = Paint()..color = Color.fromRGBO(20, 17, 14, 0.98 * bodyA);
    canvas.drawCircle(const Offset(-2, -18), 9, tsuba);
    final tsubaRim = Paint()
      ..color = Color.fromRGBO(120, 90, 60, 0.6 * bodyA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(const Offset(-2, -18), 9, tsubaRim);
    // Tsuba notch (seppa-dai)
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(-2, -18), width: 5, height: 14),
      tsuba,
    );

    // Blade — proper tapering shape with curve (sori)
    final tinge = _bloodTinge;
    final bladeR = (240 - 70 * tinge).round();
    final bladeG = (236 - 180 * tinge).round();
    final bladeB = (220 - 175 * tinge).round();

    // Blade shadow / mune (back of blade) — slightly darker outline
    final bladeShadow = Paint()
      ..color = Color.fromRGBO(20, 17, 14, 0.55 * bodyA);
    final bladeShadowPath = Path()
      ..moveTo(-4, -22)
      ..lineTo(-2, -82)
      ..lineTo(0, -92)
      ..lineTo(3, -82)
      ..lineTo(1, -22)
      ..close();
    canvas.drawPath(bladeShadowPath, bladeShadow);

    // Blade body (steel)
    final blade = Paint()
      ..color = Color.fromRGBO(bladeR, bladeG, bladeB, 0.97 * bodyA);
    final bladePath = Path()
      ..moveTo(-3, -22)
      ..quadraticBezierTo(-2, -52, -1, -82)
      ..lineTo(0, -91)
      ..lineTo(2, -82)
      ..quadraticBezierTo(1, -52, 0, -22)
      ..close();
    canvas.drawPath(bladePath, blade);

    // Hamon (temper line) — wavy line near the cutting edge
    if (bodyA > 0.7) {
      final hamon = Paint()
        ..color = Color.fromRGBO(255, 250, 240, 0.65 * bodyA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      final hamonPath = Path()
        ..moveTo(-2, -24)
        ..cubicTo(-1.4, -34, -2.0, -44, -1.4, -54)
        ..cubicTo(-2.0, -64, -1.0, -74, -1.2, -84);
      canvas.drawPath(hamonPath, hamon);
    }

    // Blood tinge glow when active
    if (tinge > 0.01) {
      final glow = Paint()
        ..color = Color.fromRGBO(220, 60, 40, 0.55 * tinge * bodyA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..blendMode = BlendMode.plus;
      canvas.drawPath(bladePath, glow);
    }

    // Sword gleam during run — pulses along the blade
    if (_running) {
      final pulse = (math.sin(_bob * 3.2) * 0.5 + 0.5);
      final gleamPos = -22 - pulse * 60;
      final gleam = Paint()
        ..color = Color.fromRGBO(255, 250, 235, 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(-1, gleamPos), 5, gleam);
    }

    // ═══════════════════════════════════════════════════════════
    // KASA (woven straw hat) — main silhouette. Kit palette.
    // ═══════════════════════════════════════════════════════════
    final hatOuter = Paint()
      ..color = kasaColor.withValues(alpha: 0.97 * bodyA)
      ..blendMode = BlendMode.multiply;
    canvas.drawCircle(const Offset(0, -3), 38, hatOuter);

    // Soft inner ring (shows hat depth)
    final hatInner = Paint()
      ..color = Color.fromRGBO(50, 36, 26, 0.55 * bodyA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(const Offset(0, -3), 30, hatInner);

    // Radial weave creases — 12 spokes
    final crease = Paint()
      ..color = Color.fromRGBO(48, 36, 28, 0.55 * bodyA)
      ..strokeWidth = 0.7;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final to = Offset(math.cos(a) * 36, -3 + math.sin(a) * 36);
      canvas.drawLine(const Offset(0, -3), to, crease);
    }

    // Concentric weave rings (to suggest woven straw)
    for (var i = 0; i < 3; i++) {
      final r = 12.0 + i * 10;
      canvas.drawCircle(
        const Offset(0, -3),
        r,
        Paint()
          ..color = Color.fromRGBO(48, 36, 28, 0.35 * bodyA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }

    // Hat rim — outer ring slightly raised
    final hatRim = Paint()
      ..color = Color.fromRGBO(70, 56, 42, 0.75 * bodyA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(const Offset(0, -3), 38, hatRim);

    // Crown (peak of hat — highest point at center)
    final crown = Paint()..color = Color.fromRGBO(40, 30, 24, 0.9 * bodyA);
    canvas.drawCircle(const Offset(0, -3), 6, crown);
    final crownTip =
        Paint()..color = Color.fromRGBO(245, 240, 225, 0.4 * bodyA);
    canvas.drawCircle(const Offset(0, -3), 1.8, crownTip);

    // Brim shadow under hat — at front (forward-facing edge)
    final brimShadow = Paint()
      ..color = Color.fromRGBO(20, 17, 14, 0.75 * bodyA);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, -3), width: 60, height: 60),
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      brimShadow..style = PaintingStyle.stroke..strokeWidth = 5,
    );

    // ═══════════════════════════════════════════════════════════
    // Tiny eye-slits visible under the brim — face peeking out
    // ═══════════════════════════════════════════════════════════
    final eyeA = (_victoryPose ? 1.0 : 0.85) * bodyA;
    final eye = Paint()..color = Color.fromRGBO(245, 230, 200, eyeA);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(-5, -22), width: 4, height: 1.6),
      eye,
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(5, -22), width: 4, height: 1.6),
      eye,
    );

    // ═══════════════════════════════════════════════════════════
    // HIMO (cord across hat) — chin tie. Uses sash color for unity.
    // ═══════════════════════════════════════════════════════════
    final himo = Paint()..color = sashColor.withValues(alpha: 0.95 * bodyA);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -10), width: 64, height: 4),
      himo,
    );
    canvas.drawCircle(const Offset(-32, -10), 3, himo);
    canvas.drawCircle(const Offset(32, -10), 3, himo);
    // Forward accent mark — kit-tinted, brighter on victory pose.
    if (_victoryPose) {
      final mark = Paint()
        ..color = accentColor.withValues(alpha: 0.85 * bodyA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(0, -16), const Offset(0, -2), mark);
      canvas.drawLine(const Offset(-7, -10), const Offset(7, -10), mark);
    }

    // Flinch flash overlay
    if (flinchAmount > 0) {
      final flash = Paint()
        ..color = Color.fromRGBO(255, 240, 220, 0.55 * flinchAmount);
      canvas.drawCircle(Offset.zero, 54, flash);
    }

    // Victory pose: a brushstroke kanji-like mark pulses on the hat
    if (_victoryPose) {
      final pulse = math.sin(_victoryT * 4).abs();
      final mark = Paint()
        ..color = accentColor.withValues(alpha: 0.55 + 0.35 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final p = Path()
        ..moveTo(-14, -2)
        ..quadraticBezierTo(0, -10, 14, -2)
        ..moveTo(0, -12)
        ..lineTo(0, 10);
      canvas.drawPath(p, mark);
    }

    canvas.restore();
  }
}
