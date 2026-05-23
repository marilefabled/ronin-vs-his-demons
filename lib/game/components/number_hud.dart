import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// The big kut counter top-left. Animates dramatically on each kill —
/// scale-pop, color tier, halo, shockwave rings, and ink sparks at high combo.
class NumberHUD extends Component
    with HasGameReference<FlamekutGame> {
  NumberHUD({required this.position}) : super(priority: 1100);

  final Vector2 position;

  int _displayedCombo = 0;
  double _popT = 1.0; // 0..1 popping in, 1 = settled
  double _hypeT = 0;  // 0..1 hype intensity, slow decay
  double _shockT = 1.0; // 0..1 shockwave ring expansion
  final List<_Spark> _sparks = [];
  final math.Random _rng = math.Random();

  /// Hype tier (0..1) — derived from current combo.
  double get tier =>
      (game.combo / 10.0).clamp(0.0, 1.0).toDouble();

  /// Called when the kut count just incremented.
  void bump() {
    _displayedCombo = game.combo;
    _popT = 0;
    _shockT = 0;
    _hypeT = 1.0;

    // Spawn ink sparks proportional to tier
    final n = (4 + tier * 14).round();
    for (var i = 0; i < n; i++) {
      _sparks.add(_Spark(
        angle: _rng.nextDouble() * math.pi * 2,
        speed: 240 + _rng.nextDouble() * 360,
        size: 3 + _rng.nextDouble() * 5,
        red: i % 4 == 0 || _rng.nextDouble() < tier,
      ));
    }
  }

  /// Reset between runs so the menu shows blank.
  void reset() {
    _displayedCombo = 0;
    _popT = 1;
    _shockT = 1;
    _hypeT = 0;
    _sparks.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_popT < 1) {
      _popT = math.min(1.0, _popT + dt * 4.5);
    }
    if (_shockT < 1) {
      _shockT = math.min(1.0, _shockT + dt * 3.0);
    }
    // Hype decays slowly so glow lingers between kills
    _hypeT = math.max(tier, _hypeT - dt * 0.22);

    // Sparks drift outward + age
    for (var i = _sparks.length - 1; i >= 0; i--) {
      _sparks[i].t += dt;
      if (_sparks[i].t > 0.55) _sparks.removeAt(i);
    }
  }

  @override
  void render(Canvas canvas) {
    if (game.scene == AppScene.menu) return;
    final t = tier;
    final hype = _hypeT;
    canvas.save();
    canvas.translate(position.x, position.y);

    // ---- Halo behind digit — grows with combo ----
    if (hype > 0.05) {
      final haloR = 110 + 90 * hype;
      final haloC = Color.lerp(
        const Color(0xFFA72920),
        const Color(0xFFFFB86A),
        t,
      )!;
      final outer = Paint()
        ..color = haloC.withValues(alpha: 0.25 * hype)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 28 + 16 * hype);
      canvas.drawCircle(const Offset(60, 80), haloR, outer);
      final inner = Paint()
        ..color = haloC.withValues(alpha: 0.42 * hype)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(const Offset(60, 80), haloR * 0.55, inner);
    }

    // ---- Shockwave rings — expanding outward on each bump ----
    if (_shockT < 1) {
      final p = _shockT;
      final fade = 1 - p;
      final ringPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFA72920),
          const Color(0xFFFFE6C0),
          t,
        )!
            .withValues(alpha: 0.6 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * fade + 1;
      canvas.drawCircle(const Offset(60, 80), 30 + p * 200, ringPaint);
      if (t > 0.3) {
        final ring2 = Paint()
          ..color = Color.fromRGBO(245, 240, 225, 0.5 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * fade + 0.5;
        canvas.drawCircle(const Offset(60, 80), 60 + p * 240, ring2);
      }
    }

    // ---- Sparks ----
    final inkPaint = Paint()..color = const Color(0xCC1A1612);
    final redPaint = Paint()..color = const Color(0xFFE5392B);
    for (final s in _sparks) {
      final p = (s.t / 0.55).clamp(0.0, 1.0);
      final dist = s.speed * p;
      final dx = math.cos(s.angle) * dist;
      final dy = math.sin(s.angle) * dist;
      final r = s.size * (1 - p * 0.5);
      final paint = s.red ? redPaint : inkPaint;
      paint.color = paint.color.withValues(alpha: (1 - p) * 0.95);
      canvas.drawCircle(Offset(60 + dx, 80 + dy), r, paint);
    }

    // ---- The digit itself ----
    final pop = _popT < 1
        ? 1.0 + (1 - _popT) * 0.45 // 1.45x at start, eases to 1.0
        : 1.0;

    // Color tier — base ink → ember → red-hot
    Color digitColor;
    if (t < 0.3) {
      digitColor = Color.lerp(
          const Color(0xFF1A1612), const Color(0xFF6E2818), t / 0.3)!;
    } else if (t < 0.7) {
      digitColor = Color.lerp(const Color(0xFF6E2818),
          const Color(0xFFD45438), (t - 0.3) / 0.4)!;
    } else {
      digitColor = Color.lerp(const Color(0xFFD45438),
          const Color(0xFFFFE0A0), (t - 0.7) / 0.3)!;
    }

    // Subtle micro-shake at top tier
    var sx = 0.0, sy = 0.0;
    if (t > 0.5 && _popT < 1) {
      final amp = 4.0 * (1 - _popT) * t;
      sx = (_rng.nextDouble() * 2 - 1) * amp;
      sy = (_rng.nextDouble() * 2 - 1) * amp;
    }

    canvas.save();
    canvas.translate(60 + sx, 80 + sy);
    canvas.scale(pop, pop);

    // Drop shadow / smoke
    final shadowSize = 168.0 + 50 * t;
    final shadow = TextPainter(
      text: TextSpan(
        text: '$_displayedCombo',
        style: TextStyle(
          color: digitColor.withValues(alpha: 0.30 * (0.4 + 0.6 * t)),
          fontSize: shadowSize,
          fontWeight: FontWeight.w300,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    shadow.paint(canvas, Offset(-shadow.width / 2 + 4, -shadow.height / 2 + 8));

    // Main digit
    final digit = TextPainter(
      text: TextSpan(
        text: '$_displayedCombo',
        style: TextStyle(
          color: digitColor,
          fontSize: 168 + 36 * t,
          fontWeight: FontWeight.lerp(FontWeight.w300, FontWeight.w700, t),
          height: 1.0,
          shadows: [
            Shadow(
              color: const Color(0xFFA72920).withValues(alpha: 0.4 + 0.4 * t),
              blurRadius: 16 + 26 * t,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    digit.paint(canvas, Offset(-digit.width / 2, -digit.height / 2));

    canvas.restore();
    canvas.restore();
  }
}

class _Spark {
  _Spark({
    required this.angle,
    required this.speed,
    required this.size,
    required this.red,
  });
  final double angle, speed, size;
  final bool red;
  double t = 0;
}
