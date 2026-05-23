import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/camera.dart' show Viewfinder;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show Alignment, RadialGradient, TextPainter, TextSpan, TextDirection,
        TextStyle, FontStyle, FontWeight, Shadow;

import '../flamekut_game.dart';

enum SwordStyle {
  horizontalSlash,
  verticalChop,
  thrust,
  diagonalSlash,
  reverseSlash,
  spinCut,
}

class SwordSlash extends Component {
  SwordSlash({
    required this.position,
    required this.angle,
    required this.style,
    this.tint = const Color(0xFFF5F0E1),
  }) : super(priority: 30);

  final Vector2 position;
  final double angle;
  final SwordStyle style;
  final Color tint;

  static const double _dur = 0.32;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _dur).clamp(0.0, 1.0);
    final fade = 1 - p;

    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(angle);

    // Blend kit accent with bright white for the slash so it still POPs.
    final slashColor = Color.lerp(const Color(0xFFF5F0E1), tint, 0.4)!;
    final paint = Paint()
      ..color = slashColor.withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (style) {
      case SwordStyle.horizontalSlash:
        paint.strokeWidth = (1 - p) * 16 + 3;
        final start = -math.pi * 0.65 + p * 0.4;
        final sweep = math.pi * 1.2 - p * 0.3;
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset.zero, width: 170 + p * 80, height: 120 + p * 50),
          start,
          sweep,
          false,
          paint,
        );
        if (p > 0.1) {
          paint.strokeWidth = (1 - p) * 6 + 1;
          paint.color = slashColor.withValues(alpha: fade * 0.6);
          canvas.drawArc(
            Rect.fromCenter(
                center: Offset.zero, width: 130 + p * 50, height: 90 + p * 30),
            start + 0.2,
            sweep - 0.4,
            false,
            paint,
          );
        }
        break;

      case SwordStyle.verticalChop:
        paint.strokeWidth = (1 - p) * 18 + 5;
        final len = 130 + p * 80;
        canvas.drawLine(Offset(0, -len * 0.2), Offset(0, -len), paint);
        paint.strokeWidth = (1 - p) * 7 + 1;
        canvas.drawLine(
          Offset(-32 - p * 12, -len * 0.62),
          Offset(32 + p * 12, -len * 0.62),
          paint,
        );
        break;

      case SwordStyle.thrust:
        paint.strokeWidth = (1 - p) * 10 + 3;
        final len = 110 + p * 220;
        canvas.drawLine(Offset(0, -10), Offset(0, -len), paint);
        final halo = Paint()
          ..color = slashColor.withValues(alpha: fade * 0.5);
        canvas.drawCircle(Offset(0, -len), 12 + p * 22, halo);
        final spark = Paint()
          ..color = slashColor.withValues(alpha: fade * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5;
        for (var i = -2; i <= 2; i++) {
          final a = i * 0.18;
          canvas.drawLine(
            Offset(math.sin(a) * len * 0.7, -math.cos(a) * len * 0.7),
            Offset(math.sin(a) * (len + 30), -math.cos(a) * (len + 30)),
            spark,
          );
        }
        break;

      case SwordStyle.diagonalSlash:
        // upper-left → lower-right diagonal sweep
        paint.strokeWidth = (1 - p) * 16 + 4;
        final off = p * 30;
        canvas.drawLine(
          Offset(-70 - off, -90 + off * 0.2),
          Offset(80 + off, 30 + off * 0.4),
          paint,
        );
        // Trailing whisper line
        if (p > 0.08) {
          paint.strokeWidth = (1 - p) * 5 + 1;
          paint.color = slashColor.withValues(alpha: fade * 0.55);
          canvas.drawLine(
            Offset(-50 - off, -70 + off * 0.3),
            Offset(60 + off, 20 + off * 0.5),
            paint,
          );
        }
        // Tip flick
        final flick = Paint()
          ..color = slashColor.withValues(alpha: fade * 0.85);
        canvas.drawCircle(Offset(80 + off, 30 + off * 0.4), 4 + p * 4, flick);
        break;

      case SwordStyle.reverseSlash:
        // upper-right → lower-left
        paint.strokeWidth = (1 - p) * 16 + 4;
        final off = p * 30;
        canvas.drawLine(
          Offset(70 + off, -90 + off * 0.2),
          Offset(-80 - off, 30 + off * 0.4),
          paint,
        );
        if (p > 0.08) {
          paint.strokeWidth = (1 - p) * 5 + 1;
          paint.color = slashColor.withValues(alpha: fade * 0.55);
          canvas.drawLine(
            Offset(50 + off, -70 + off * 0.3),
            Offset(-60 - off, 20 + off * 0.5),
            paint,
          );
        }
        final flick = Paint()
          ..color = slashColor.withValues(alpha: fade * 0.85);
        canvas.drawCircle(Offset(-80 - off, 30 + off * 0.4), 4 + p * 4, flick);
        break;

      case SwordStyle.spinCut:
        // 360° expanding ring — full rotation cut
        paint.strokeWidth = (1 - p) * 22 + 4;
        canvas.drawCircle(Offset.zero, 60 + p * 90, paint);
        paint.strokeWidth = (1 - p) * 10 + 2;
        paint.color = slashColor.withValues(alpha: fade * 0.7);
        canvas.drawCircle(Offset.zero, 40 + p * 70, paint);
        // Radial petals
        final petal = Paint()
          ..color = slashColor.withValues(alpha: fade * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (1 - p) * 4 + 1;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4 + p * 1.4;
          final r1 = 50 + p * 60;
          final r2 = 80 + p * 100;
          canvas.drawLine(
            Offset(math.cos(a) * r1, math.sin(a) * r1),
            Offset(math.cos(a) * r2, math.sin(a) * r2),
            petal,
          );
        }
        break;
    }

    canvas.restore();
  }
}

/// Stylized red brush-stroke kanji-mark that flashes briefly on hit.
class KanjiMark extends Component {
  KanjiMark({
    required this.position,
    required this.style,
  }) : super(priority: 31);

  final Vector2 position;
  final SwordStyle style;
  static const double _dur = 0.55;
  double _t = 0;
  late final double _scale = 0.95 + math.Random().nextDouble() * 0.2;
  late final double _rot = (math.Random().nextDouble() - 0.5) * 0.15;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _dur).clamp(0.0, 1.0);
    final pop = p < 0.18 ? p / 0.18 : 1.0;
    final fade = p < 0.18 ? 1.0 : 1 - (p - 0.18) / 0.82;
    final alpha = pop * fade;

    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(_rot);
    final s = _scale * (0.85 + 0.25 * pop);
    canvas.scale(s, s);

    final ink = Paint()
      ..color = Color.fromRGBO(167, 41, 32, 0.92 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final halo = Paint()
      ..color = Color.fromRGBO(167, 41, 32, 0.18 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset.zero, 38, halo);

    switch (style) {
      case SwordStyle.horizontalSlash:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), ink);
        ink.strokeWidth = 4;
        canvas.drawLine(const Offset(-22, -14), const Offset(-18, -4), ink);
        canvas.drawLine(const Offset(18, -14), const Offset(22, -4), ink);
        final tail = Path()
          ..moveTo(28, 0)
          ..quadraticBezierTo(36, 4, 38, 12);
        canvas.drawPath(tail, ink);
        break;

      case SwordStyle.verticalChop:
        ink.strokeWidth = 7;
        canvas.drawLine(const Offset(0, -28), const Offset(0, 28), ink);
        canvas.drawLine(const Offset(-26, -2), const Offset(26, -2), ink);
        final hook = Path()
          ..moveTo(0, 24)
          ..quadraticBezierTo(-6, 28, -10, 30);
        canvas.drawPath(hook, ink);
        break;

      case SwordStyle.thrust:
        ink.strokeWidth = 7;
        canvas.drawLine(const Offset(-22, -20), const Offset(22, -20), ink);
        canvas.drawLine(const Offset(0, -16), const Offset(0, 22), ink);
        final hook = Path()
          ..moveTo(0, 22)
          ..quadraticBezierTo(-8, 20, -14, 16);
        canvas.drawPath(hook, ink);
        final dot = Paint()
          ..color = Color.fromRGBO(167, 41, 32, 0.92 * alpha);
        canvas.drawCircle(const Offset(22, -28), 2.4, dot);
        break;

      case SwordStyle.diagonalSlash:
        // 丿-style — single diagonal brushstroke + small dot
        ink.strokeWidth = 8;
        final p1 = Path()
          ..moveTo(-22, -22)
          ..quadraticBezierTo(0, -2, 24, 26);
        canvas.drawPath(p1, ink);
        ink.strokeWidth = 5;
        canvas.drawLine(const Offset(-26, -8), const Offset(-14, -18), ink);
        final dot = Paint()
          ..color = Color.fromRGBO(167, 41, 32, 0.92 * alpha);
        canvas.drawCircle(const Offset(28, 28), 3, dot);
        break;

      case SwordStyle.reverseSlash:
        // 乀-style — opposite diagonal
        ink.strokeWidth = 8;
        final p1 = Path()
          ..moveTo(22, -22)
          ..quadraticBezierTo(0, -2, -24, 26);
        canvas.drawPath(p1, ink);
        ink.strokeWidth = 5;
        canvas.drawLine(const Offset(26, -8), const Offset(14, -18), ink);
        final dot = Paint()
          ..color = Color.fromRGBO(167, 41, 32, 0.92 * alpha);
        canvas.drawCircle(const Offset(-28, 28), 3, dot);
        break;

      case SwordStyle.spinCut:
        // Concentric circular strokes — emphatic, used for combos
        ink.strokeWidth = 6;
        canvas.drawCircle(Offset.zero, 22, ink);
        ink.strokeWidth = 4;
        canvas.drawCircle(Offset.zero, 12, ink);
        // Cross flourish
        canvas.drawLine(const Offset(-8, -8), const Offset(8, 8), ink);
        canvas.drawLine(const Offset(-8, 8), const Offset(8, -8), ink);
        break;
    }

    canvas.restore();
  }
}

class InkSplash extends Component {
  InkSplash({required this.position}) : super(priority: 25) {
    final r = math.Random();
    _splats = List.generate(16, (i) {
      return _Splat(
        angle: r.nextDouble() * math.pi * 2,
        speed: 90 + r.nextDouble() * 240,
        size: 4 + r.nextDouble() * 11,
        red: i % 5 == 0,
      );
    });
  }

  final Vector2 position;
  static const double _dur = 0.6;
  double _t = 0;
  late final List<_Splat> _splats;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _dur).clamp(0.0, 1.0);
    final fade = 1 - p;

    canvas.save();
    canvas.translate(position.x, position.y);

    final ink = Paint()..color = Color.fromRGBO(20, 17, 14, 0.85 * fade);
    final red = Paint()..color = Color.fromRGBO(167, 41, 32, 0.7 * fade);
    for (final s in _splats) {
      final dist = s.speed * p;
      final dx = math.cos(s.angle) * dist;
      final dy = math.sin(s.angle) * dist;
      final r = s.size * (1 - p * 0.4);
      canvas.drawCircle(Offset(dx, dy), r, s.red ? red : ink);
    }
    final central = Paint()..color = Color.fromRGBO(20, 17, 14, 0.7 * fade);
    canvas.drawCircle(Offset.zero, 22 * (1 - p * 0.6), central);

    canvas.restore();
  }
}

class _Splat {
  _Splat({
    required this.angle,
    required this.speed,
    required this.size,
    required this.red,
  });
  final double angle, speed, size;
  final bool red;
}

/// Radial expanding ring on impact — quick punctuation for hits.
class ImpactFlash extends Component {
  ImpactFlash({required this.position, this.big = false}) : super(priority: 32);

  final Vector2 position;
  final bool big;
  double _t = 0;
  static const double _dur = 0.32;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _dur).clamp(0.0, 1.0);
    final fade = 1 - p;
    final scale = big ? 1.6 : 1.0;

    canvas.save();
    canvas.translate(position.x, position.y);

    // Outer red rim
    final rim = Paint()
      ..color = Color.fromRGBO(220, 60, 40, 0.65 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1 - p) * 12 + 2;
    canvas.drawCircle(Offset.zero, (40 + p * 140) * scale, rim);

    // Inner white core
    final core = Paint()
      ..color = Color.fromRGBO(255, 245, 225, 0.85 * fade);
    canvas.drawCircle(Offset.zero, (10 + p * 16) * scale, core);

    // Soft glow
    final glow = Paint()
      ..color = Color.fromRGBO(255, 220, 180, 0.4 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(Offset.zero, (50 + p * 80) * scale, glow);

    canvas.restore();
  }
}

/// Brief full-screen pulse — desaturated punch on hit.
class ScreenPulse extends Component {
  ScreenPulse({this.color = const Color(0xFFFFF5E0), this.peak = 0.18, this.dur = 0.18})
      : super(priority: 250);

  final Color color;
  final double peak;
  final double dur;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / dur).clamp(0.0, 1.0);
    // Fast in, slow out
    final a = p < 0.25 ? p / 0.25 : 1 - (p - 0.25) / 0.75;
    final paint = Paint()
      ..color = color.withValues(alpha: peak * a);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      paint,
    );
  }
}

class BlackMist extends Component {
  BlackMist({required this.position}) : super(priority: 60) {
    final r = math.Random();
    _puffs = List.generate(38, (i) {
      return _Mist(
        angle: r.nextDouble() * math.pi * 2,
        radius: 240 + r.nextDouble() * 280,
        size: 70 + r.nextDouble() * 110,
        phase: r.nextDouble() * math.pi * 2,
      );
    });
  }

  final Vector2 position;
  static const double _dur = 4.0;
  double _t = 0;
  late final List<_Mist> _puffs;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _dur).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(position.x, position.y);

    final inwardP = math.min(p * 2.2, 1.0);
    final outwardP = math.max(0.0, p * 1.5 - 0.55);
    final visualP = (inwardP - outwardP * 0.5).clamp(0.0, 1.0);

    for (final m in _puffs) {
      final spiral = m.angle + p * 1.5 + m.phase;
      final radius = m.radius * (1 - inwardP) + outwardP * 720;
      final x = math.cos(spiral) * radius;
      final y = math.sin(spiral) * radius;
      final paint = Paint()
        ..color = Color.fromRGBO(20, 17, 14, 0.5 * (1 - p * 0.55))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawCircle(Offset(x, y), m.size * (0.5 + visualP * 0.95), paint);
    }

    final central = Paint()
      ..color = Color.fromRGBO(20, 17, 14, 0.85 * (1 - p * 0.4))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset.zero, 70 + p * 90, central);

    canvas.restore();
  }
}

class _Mist {
  _Mist({
    required this.angle,
    required this.radius,
    required this.size,
    required this.phase,
  });
  final double angle, radius, size, phase;
}

class RedSun extends Component {
  RedSun({required this.position}) : super(priority: 8);

  final Vector2 position;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final fadeIn = (_t / 1.6).clamp(0.0, 1.0);
    final alpha = fadeIn * (1 - (_t > 4.0 ? (_t - 4.0) / 1.5 : 0).clamp(0.0, 1.0));

    canvas.save();
    canvas.translate(position.x, position.y);

    final outer = Paint()
      ..color = Color.fromRGBO(220, 88, 60, 0.22 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(Offset.zero, 360 + 40 * math.sin(_t * 0.6), outer);

    final mid = Paint()
      ..color = Color.fromRGBO(196, 56, 36, 0.45 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset.zero, 240, mid);

    final disc = Paint()..color = Color.fromRGBO(167, 41, 32, 0.72 * alpha);
    canvas.drawCircle(Offset.zero, 180, disc);

    final core = Paint()..color = Color.fromRGBO(220, 88, 60, 0.5 * alpha);
    canvas.drawCircle(Offset.zero, 110, core);

    canvas.restore();
  }
}

class RunTone extends Component {
  RunTone() : super(priority: 200);

  double _intensity = 0;
  double _target = 0;
  bool _victory = false;

  void setRunning(bool running) {
    _target = running ? 1.0 : 0.0;
    _victory = false;
  }

  void setVictory() {
    _victory = true;
    _target = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _intensity += (_target - _intensity) * dt * 3.5;
  }

  @override
  void render(Canvas canvas) {
    if (_intensity < 0.005) return;
    final w = FlamekutGame.worldW, h = FlamekutGame.worldH;
    final rect = Rect.fromLTWH(0, 0, w, h);

    final warm = Paint()
      ..color = Color.fromRGBO(120, 60, 30, 0.10 * _intensity);
    canvas.drawRect(rect, warm);

    if (_victory) {
      final sepia = Paint()
        ..color = Color.fromRGBO(160, 70, 20, 0.12 * _intensity);
      canvas.drawRect(rect, sepia);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          const Color(0x00000000),
          Color.fromRGBO(20, 17, 14, 0.35 * _intensity),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }
}

/// Cool blue tint + radial pulse during Slow Time. Reads as time dilation.
class SlowTone extends Component
    with HasGameReference<FlamekutGame> {
  SlowTone() : super(priority: 210);

  double _intensity = 0;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final target = game.samurai.isSlow ? 1.0 : 0.0;
    _intensity += (target - _intensity) * dt * 4.0;
  }

  @override
  void render(Canvas canvas) {
    if (_intensity < 0.005) return;
    final w = FlamekutGame.worldW, h = FlamekutGame.worldH;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // Cool wash
    final wash = Paint()
      ..color = Color.fromRGBO(60, 130, 180, 0.16 * _intensity);
    canvas.drawRect(rect, wash);

    // Radial concentric ripples
    final ripple = Paint()
      ..color = Color.fromRGBO(90, 200, 220, 0.18 * _intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    for (var i = 0; i < 4; i++) {
      final r = (i * 220 + _t * 110) % 1100;
      canvas.drawCircle(Offset(w / 2, h / 2), r, ripple);
    }

    // Vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          const Color(0x00000000),
          Color.fromRGBO(40, 60, 90, 0.25 * _intensity),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }
}

/// Persistent screen-edge red glow that intensifies with combo. Decays
/// gradually so glow lingers between kills.
class HypeAura extends Component
    with HasGameReference<FlamekutGame> {
  HypeAura() : super(priority: 220);

  double _intensity = 0;
  double _t = 0;
  double _flashT = 1.0; // 0 = full bump, 1 = settled

  /// Called when a kill lands — feeds an instant flash on top of the
  /// persistent glow.
  void bump() {
    _flashT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final tier = (game.combo / 10.0).clamp(0.0, 1.0).toDouble();
    _intensity += (tier - _intensity) * dt * 1.6;
    if (_flashT < 1) _flashT = math.min(1.0, _flashT + dt * 3.0);
  }

  @override
  void render(Canvas canvas) {
    final i = _intensity;
    if (i < 0.02 && _flashT >= 1) return;
    const w = FlamekutGame.worldW;
    const h = FlamekutGame.worldH;
    final rect = const Rect.fromLTWH(0, 0, w, h);

    // Persistent edge glow — color shifts ember → red-hot with intensity
    final edgeColor = Color.lerp(
      const Color(0xFFA72920),
      const Color(0xFFFFB86A),
      i,
    )!;
    final edge = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          const Color(0x00000000),
          edgeColor.withValues(alpha: 0.0),
          edgeColor.withValues(alpha: 0.35 * i),
        ],
        stops: const [0.55, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, edge);

    // Pulsing breath at higher tiers
    if (i > 0.3) {
      final breath = math.sin(_t * 4.5) * 0.5 + 0.5;
      final pulse = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            const Color(0x00000000),
            edgeColor.withValues(alpha: 0.18 * i * breath),
          ],
          stops: const [0.7, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, pulse);
    }

    // Instant flash on bump — full-screen warm wash that fades fast
    if (_flashT < 1) {
      final fade = 1 - _flashT;
      final flash = Paint()
        ..color = edgeColor.withValues(alpha: 0.18 * fade);
      canvas.drawRect(rect, flash);
    }
  }
}

/// Quick decaying random offset on the camera viewfinder.
class CameraShake extends Component {
  CameraShake({
    required this.vf,
    required this.intensity,
    required this.duration,
  });

  final Viewfinder vf;
  final double intensity;
  final double duration;
  late final Vector2 _basePos = vf.position.clone();
  double _t = 0;
  final math.Random _rng = math.Random();

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) {
      vf.position = _basePos;
      removeFromParent();
      return;
    }
    final p = (_t / duration).clamp(0.0, 1.0);
    final amp = intensity * (1 - p);
    vf.position = _basePos +
        Vector2(
          (_rng.nextDouble() * 2 - 1) * amp,
          (_rng.nextDouble() * 2 - 1) * amp,
        );
  }
}

/// Pulsing red ring + label that hovers around the entity that caused
/// the run to fail. Helps the player understand what to fix on retry.
class FailureMarker extends Component {
  FailureMarker({
    required this.position,
    required this.label,
    this.duration = 1.8,
  }) : super(priority: 70);

  final Vector2 position;
  final String label;
  final double duration;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    final fade = 1 - p;
    final pulse = math.sin(_t * 8) * 0.5 + 0.5;
    canvas.save();
    canvas.translate(position.x, position.y);

    final ring = Paint()
      ..color = Color.fromRGBO(229, 57, 43, (0.5 + 0.4 * pulse) * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 + pulse * 3;
    canvas.drawCircle(Offset.zero, 60 + pulse * 14, ring);

    final inner = Paint()
      ..color = Color.fromRGBO(229, 57, 43, 0.18 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset.zero, 80, inner);

    // Label above
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Color.fromRGBO(245, 240, 225, 0.95 * fade),
          fontSize: 26,
          fontWeight: FontWeight.w500,
          letterSpacing: 4,
          fontStyle: FontStyle.italic,
          shadows: [
            const Shadow(color: Color(0xFF1A1612), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -110));

    canvas.restore();
  }
}

/// "Hit punch" — combined zoom-in + shake + optional pan toward target.
/// Single component so the two effects don't fight each other.
/// Animates in real time (lives on game, not world) so it overlaps the
/// hitstop pause as a freeze-frame zoom.
class CameraImpact extends Component {
  CameraImpact({
    required this.vf,
    this.peakZoom = 1.18,
    this.shakeIntensity = 14,
    this.duration = 0.36,
    this.panToward,
    this.panAmount = 0.08,
  });

  final Viewfinder vf;
  final double peakZoom;
  final double shakeIntensity;
  final double duration;
  final Vector2? panToward;
  final double panAmount;

  late final double _baseZoom = vf.zoom;
  late final Vector2 _basePos = vf.position.clone();
  double _t = 0;
  final math.Random _rng = math.Random();

  @override
  void update(double dt) {
    _t += dt;
    final p = (_t / duration).clamp(0.0, 1.0);
    if (p >= 1.0) {
      vf.zoom = _baseZoom;
      vf.position = _basePos;
      removeFromParent();
      return;
    }

    // Zoom curve: snap-in (0..0.12), hold peak (0.12..0.30), ease out
    double zoom;
    if (p < 0.12) {
      final inP = p / 0.12;
      // ease-out cubic for snap
      zoom = _baseZoom + (peakZoom - _baseZoom) * (1 - math.pow(1 - inP, 3).toDouble());
    } else if (p < 0.30) {
      zoom = peakZoom;
    } else {
      final outP = (p - 0.30) / 0.70;
      zoom = peakZoom -
          (peakZoom - _baseZoom) * (1 - math.pow(1 - outP, 3).toDouble());
    }
    vf.zoom = zoom;

    // Pan slightly toward the impact point during the punch (0..0.40 phase)
    Vector2 pan = Vector2.zero();
    if (panToward != null && p < 0.40) {
      final panP = (p / 0.40).clamp(0.0, 1.0);
      final delta = panToward! - _basePos;
      pan = delta * panAmount * (1 - math.pow(1 - panP, 2).toDouble());
    }

    // Shake — strongest during zoom-in, decays through hold + ease-out
    final shakeFalloff = math.max(0.0, 1 - p * 1.4);
    final amp = shakeIntensity * shakeFalloff;
    final shake = Vector2(
      (_rng.nextDouble() * 2 - 1) * amp,
      (_rng.nextDouble() * 2 - 1) * amp,
    );

    vf.position = _basePos + pan + shake;
  }
}

class MotionTrail extends Component {
  MotionTrail() : super(priority: 9);

  final List<_Ghost> _ghosts = [];
  static const double _spawnInterval = 0.06;
  double _spawnT = 0;

  void push(Vector2 pos, double angle) {
    _spawnT -= 1 / 60.0;
    if (_spawnT > 0) return;
    _spawnT = _spawnInterval;
    _ghosts.add(_Ghost(pos: pos.clone(), angle: angle, age: 0));
    if (_ghosts.length > 12) _ghosts.removeAt(0);
  }

  void clear() {
    _ghosts.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final g in _ghosts) {
      g.age += dt;
    }
    _ghosts.removeWhere((g) => g.age > 0.55);
  }

  @override
  void render(Canvas canvas) {
    for (final g in _ghosts) {
      final p = (g.age / 0.55).clamp(0.0, 1.0);
      final alpha = (1 - p) * 0.18;
      if (alpha < 0.01) continue;
      canvas.save();
      canvas.translate(g.pos.x, g.pos.y);
      canvas.rotate(g.angle);
      final paint = Paint()..color = Color.fromRGBO(20, 17, 14, alpha);
      canvas.drawCircle(Offset.zero, 36 - p * 6, paint);
      final sword = Paint()
        ..color = Color.fromRGBO(20, 17, 14, alpha * 0.7)
        ..strokeWidth = 8 - p * 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-3, -16), const Offset(-3, -78), sword);
      canvas.restore();
    }
  }
}

class _Ghost {
  _Ghost({required this.pos, required this.angle, required this.age});
  final Vector2 pos;
  final double angle;
  double age;
}
