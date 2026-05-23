import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show TextStyle, TextPainter, TextSpan, TextDirection, FontWeight, Shadow;

import '../flamekut_game.dart';

class Demon extends PositionComponent with HasGameReference<FlamekutGame> {
  Demon({required Vector2 position, this.requiredNumber = 0})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(120),
          priority: 4,
        );

  /// 0 = any player number can break through. >0 = player must reach this
  /// number before contact, otherwise the run fails.
  final int requiredNumber;
  bool get isNumbered => requiredNumber > 0;

  bool dead = false;
  double bodyRadius = 36;
  double _t = 0;
  double _deathT = 0;
  double _cutAngle = 0; // angle of the cut (perpendicular = drift direction)
  double _proximity = 0; // 0..1, closer the samurai → tighter breathing
  Vector2 _eyeLook = Vector2.zero();
  late final double _tOffset = math.Random().nextDouble() * math.pi * 2;

  void die(double cutAngle) {
    if (dead) return;
    dead = true;
    _deathT = 0;
    _cutAngle = cutAngle;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ts = game.worldTimeScale;
    _t += dt * ts;
    if (dead) {
      _deathT += dt;
      if (_deathT > 0.9) removeFromParent();
      return;
    }
    final dist = (game.samurai.position - position).length;
    final tgt = (1 - (dist / 700).clamp(0.0, 1.0)).toDouble();
    _proximity += (tgt - _proximity) * dt * 3.0;

    // Eye tracking: the eyes nudge toward the samurai (clamped, max ~3px).
    final delta = game.samurai.position - position;
    if (delta.length2 > 1) {
      final n = delta.normalized();
      final target = n * 3.2;
      _eyeLook += (target - _eyeLook) * dt * 6;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    if (dead) {
      _renderDeath(canvas);
      return;
    }

    final t = _t + _tOffset;
    final breathRate = 3.2 + _proximity * 4.5;
    final wob1 = math.sin(t * breathRate) * (4 + _proximity * 2);
    final wob2 = math.cos(t * (breathRate * 0.85)) * (5 + _proximity * 2.5);

    // Soft outer aura — additive bloom that intensifies with proximity
    final aura = Paint()
      ..color = Color.fromRGBO(229, 57, 43, 0.18 + _proximity * 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(wob1, wob2), bodyRadius + 14, aura);

    // Body — three overlapping ink blots that breathe (multiply for richness)
    final body = Paint()
      ..color = const Color(0xFF1A1612)
      ..blendMode = BlendMode.multiply;
    canvas.drawCircle(Offset(wob1, wob2), bodyRadius, body);
    canvas.drawCircle(Offset(-wob2 * 0.6, wob1 * 0.7), bodyRadius * 0.78, body);
    canvas.drawCircle(Offset(wob1 * 0.5, -wob2 * 0.8), bodyRadius * 0.62, body);

    // Drips
    final drip = Paint()..color = const Color(0xCC1A1612);
    canvas.drawCircle(
      Offset(-bodyRadius * 0.4 + wob1 * 0.2, bodyRadius * 0.7),
      5,
      drip,
    );
    canvas.drawCircle(
      Offset(bodyRadius * 0.5, bodyRadius * 0.85 + wob2 * 0.2),
      4,
      drip,
    );

    // Tendrils — small claw-like marks reaching out (more aggressive when near)
    if (_proximity > 0.05) {
      final tendril = Paint()
        ..color = Color.fromRGBO(20, 17, 14, 0.5 + _proximity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + t * 0.6;
        final r1 = bodyRadius + 4;
        final r2 = bodyRadius + 14 + _proximity * 12;
        canvas.drawLine(
          Offset(math.cos(a) * r1, math.sin(a) * r1),
          Offset(math.cos(a) * r2, math.sin(a) * r2),
          tendril,
        );
      }
    }

    // Red eyes — tracked toward samurai
    final ex = _eyeLook.x, ey = _eyeLook.y;
    final eyeGlow = Paint()
      ..color = Color.fromRGBO(229, 57, 43, 0.4 + _proximity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(Offset(-8 + ex, -5 + ey), 7, eyeGlow);
    canvas.drawCircle(Offset(8 + ex, -5 + ey), 7, eyeGlow);

    final eye = Paint()..color = const Color(0xFFE5392B);
    canvas.drawCircle(Offset(-8 + ex, -5 + ey), 3.6, eye);
    canvas.drawCircle(Offset(8 + ex, -5 + ey), 3.6, eye);

    final pupil = Paint()..color = Color.fromRGBO(255, 230, 220, 0.85);
    canvas.drawCircle(Offset(-8 + ex * 1.3, -5 + ey * 1.3), 1.0, pupil);
    canvas.drawCircle(Offset(8 + ex * 1.3, -5 + ey * 1.3), 1.0, pupil);

    // Number marker — drawn over the body for numbered demons.
    if (isNumbered) {
      // Pulsing red disc background
      final discPulse = math.sin(_t * 2.5) * 0.5 + 0.5;
      final disc = Paint()
        ..color = Color.fromRGBO(229, 57, 43, 0.55 + 0.15 * discPulse);
      canvas.drawCircle(const Offset(0, -8), 22, disc);

      final discRim = Paint()
        ..color = Color.fromRGBO(245, 240, 225, 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawCircle(const Offset(0, -8), 22, discRim);

      final tp = TextPainter(
        text: TextSpan(
          text: '$requiredNumber',
          style: const TextStyle(
            color: Color(0xFFEFE7D6),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.0,
            shadows: [
              Shadow(color: Color(0xCC1A1612), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -8 - tp.height / 2));
    }
  }

  void _renderDeath(Canvas canvas) {
    final p = (_deathT / 0.9).clamp(0.0, 1.0);

    // Drift direction is perpendicular to cut.
    final perp = _cutAngle + math.pi / 2;
    final dx = math.cos(perp), dy = math.sin(perp);
    final drift = 60 * p;

    // Cut line — a quick white slash through the body, fading fast.
    if (p < 0.35) {
      final cutFade = 1 - (p / 0.35);
      final cutPaint = Paint()
        ..color = Color.fromRGBO(245, 240, 225, cutFade)
        ..strokeWidth = 4 * cutFade + 1
        ..strokeCap = StrokeCap.round;
      final cdx = math.cos(_cutAngle), cdy = math.sin(_cutAngle);
      canvas.drawLine(
        Offset(-cdx * 70, -cdy * 70),
        Offset(cdx * 70, cdy * 70),
        cutPaint,
      );
    }

    // Draw two halves drifting apart, fading to ink particles.
    canvas.save();
    final halfAlpha = (1 - p * 1.2).clamp(0.0, 1.0);
    final halfPaint = Paint()..color = Color.fromRGBO(20, 17, 14, halfAlpha);

    // Half A
    canvas.save();
    canvas.translate(dx * drift, dy * drift);
    canvas.drawCircle(Offset.zero, bodyRadius * (1 - p * 0.4), halfPaint);
    canvas.drawCircle(Offset(-6, -6), bodyRadius * 0.6 * (1 - p * 0.4), halfPaint);
    canvas.restore();

    // Half B
    canvas.save();
    canvas.translate(-dx * drift, -dy * drift);
    canvas.drawCircle(Offset.zero, bodyRadius * (1 - p * 0.4), halfPaint);
    canvas.drawCircle(Offset(8, 4), bodyRadius * 0.55 * (1 - p * 0.4), halfPaint);
    canvas.restore();

    canvas.restore();

    // Soul spark — a red ember rising upward from center, fading
    final sparkY = -120 * p;
    final sparkA = (1 - p * 0.85).clamp(0.0, 1.0);
    final sparkGlow = Paint()
      ..color = Color.fromRGBO(229, 57, 43, 0.55 * sparkA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset(0, sparkY), 16 + p * 14, sparkGlow);
    final sparkCore = Paint()..color = Color.fromRGBO(245, 200, 180, sparkA);
    canvas.drawCircle(Offset(0, sparkY), 4, sparkCore);
    final sparkTrail = Paint()
      ..color = Color.fromRGBO(229, 57, 43, 0.45 * sparkA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, sparkY + 24), Offset(0, sparkY + 4), sparkTrail);
  }
}

/// Patrols back and forth between two points.
class PatrolDemon extends Demon {
  PatrolDemon({
    required super.position,
    required Vector2 endPoint,
    this.speed = 95,
    super.requiredNumber,
  })  : startPoint = position.clone(),
        _endPoint = endPoint.clone();

  final Vector2 startPoint;
  final Vector2 _endPoint;
  final double speed;
  late final double _segLen = (_endPoint - startPoint).length;
  late final double _cycleDur = _segLen == 0 ? 1.0 : (_segLen / speed) * 2;
  double _patrolT = math.Random().nextDouble() * 1.5;

  @override
  void update(double dt) {
    if (!dead) {
      _patrolT += dt * game.worldTimeScale;
      final phase = (_patrolT % _cycleDur) / _cycleDur;
      final t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
      // smoothstep for a softer pause at extremes
      final eased = t * t * (3 - 2 * t);
      position
        ..x = startPoint.x + (_endPoint.x - startPoint.x) * eased
        ..y = startPoint.y + (_endPoint.y - startPoint.y) * eased;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    // Faint patrol path — only during plan phase, so the player can read it.
    if (!dead && game.phase == GamePhase.plan) {
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      final pathPaint = Paint()
        ..color = Color.fromRGBO(20, 17, 14, 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      // Dashed pattern via repeated short strokes
      final delta = _endPoint - startPoint;
      final len = delta.length;
      final n = (len / 18).floor();
      for (var i = 0; i < n; i += 2) {
        final t1 = i / n;
        final t2 = (i + 1) / n;
        final p1 = startPoint + delta * t1 - position;
        final p2 = startPoint + delta * t2 - position;
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), pathPaint);
      }
      canvas.restore();
    }
    super.render(canvas);
  }
}

/// Orbits around a fixed center point at a constant angular speed.
class OrbitalDemon extends Demon {
  OrbitalDemon({
    required this.orbitCenter,
    this.radius = 110,
    this.angularSpeed = 1.4,
    this.startPhase = 0,
    super.requiredNumber,
  }) : super(
          position: Vector2(
            orbitCenter.x + math.cos(startPhase) * radius,
            orbitCenter.y + math.sin(startPhase) * radius,
          ),
        );

  final Vector2 orbitCenter;
  final double radius;
  final double angularSpeed;
  final double startPhase;
  double _orbitAngle = 0;

  @override
  void update(double dt) {
    if (!dead) {
      _orbitAngle += angularSpeed * dt * game.worldTimeScale;
      position
        ..x = orbitCenter.x + math.cos(startPhase + _orbitAngle) * radius
        ..y = orbitCenter.y + math.sin(startPhase + _orbitAngle) * radius;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!dead) {
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      final ringOffset =
          Offset(orbitCenter.x - position.x, orbitCenter.y - position.y);
      final ring = Paint()
        ..color = Color.fromRGBO(20, 17, 14, 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawCircle(ringOffset, radius, ring);
      final anchor = Paint()..color = Color.fromRGBO(20, 17, 14, 0.55);
      canvas.drawCircle(ringOffset, 5, anchor);
      canvas.restore();
    }
    super.render(canvas);
  }
}

/// Stationary turret that rotates a barrel toward the samurai and fires
/// projectiles on a regular cadence.
class TurretDemon extends Demon {
  TurretDemon({
    required super.position,
    this.fireInterval = 2.6,
    this.firePhase = 0,
    super.requiredNumber,
  }) {
    bodyRadius = 44;
    _fireT = -firePhase;
  }

  final double fireInterval;
  final double firePhase;
  double? _barrelAngle;
  double _fireT = 0;
  double _muzzleFlash = 0;
  double _aimWarn = 0; // warning red glow that pulses just before firing

  @override
  void update(double dt) {
    if (!dead) {
      final ts = game.worldTimeScale;
      final dir = game.samurai.position - position;
      if (dir.length2 > 1) {
        final target = math.atan2(dir.y, dir.x);
        if (_barrelAngle == null) {
          _barrelAngle = target;
        } else {
          _barrelAngle = _lerpAngle(
              _barrelAngle!, target, (dt * 1.5 * ts).clamp(0.0, 1.0));
        }
      }

      _fireT += dt * ts;
      // Warning ramps in the last 0.5s before firing
      _aimWarn = ((_fireT - (fireInterval - 0.5)) / 0.5).clamp(0.0, 1.0);
      if (_fireT >= fireInterval) {
        _fireT -= fireInterval;
        _fire();
        _muzzleFlash = 0.18;
      }
      if (_muzzleFlash > 0) _muzzleFlash -= dt;
    }
    super.update(dt);
  }

  void _fire() {
    final angle = _barrelAngle ?? 0;
    final dir = Vector2(math.cos(angle), math.sin(angle));
    final origin = position + dir * (bodyRadius + 26);
    game.spawnProjectile(origin, dir * 380);
  }

  double _lerpAngle(double a, double b, double k) {
    final diff = ((b - a + math.pi) % (math.pi * 2)) - math.pi;
    return a + diff * k.clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (dead) return;

    // After super.render, canvas is translated to local center.
    final ang = _barrelAngle ?? 0;

    canvas.save();
    canvas.rotate(ang);

    // Barrel
    final barrel = Paint()..color = const Color(0xFF1A1612);
    canvas.drawRect(
      Rect.fromLTWH(bodyRadius - 2, -8, 38, 16),
      barrel,
    );
    final barrelHi = Paint()
      ..color = Color.fromRGBO(245, 240, 225, 0.18);
    canvas.drawRect(
      Rect.fromLTWH(bodyRadius - 2, -8, 38, 3),
      barrelHi,
    );

    // Aim warning glow at barrel tip — pulses red as fire approaches.
    if (_aimWarn > 0) {
      final glow = Paint()
        ..color = Color.fromRGBO(229, 57, 43, 0.55 * _aimWarn)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(bodyRadius + 36, 0), 10 + 6 * _aimWarn, glow);
    }

    // Muzzle flash on fire
    if (_muzzleFlash > 0) {
      final f = (_muzzleFlash / 0.18).clamp(0.0, 1.0);
      final flash = Paint()
        ..color = Color.fromRGBO(255, 220, 160, 0.85 * f);
      canvas.drawCircle(Offset(bodyRadius + 38, 0), 18 * f, flash);
      final flashGlow = Paint()
        ..color = Color.fromRGBO(255, 180, 100, 0.5 * f)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset(bodyRadius + 38, 0), 28 * f, flashGlow);
    }

    canvas.restore();
  }
}
