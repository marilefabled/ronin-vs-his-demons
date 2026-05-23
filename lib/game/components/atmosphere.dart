import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

/// Drifting sakura petals + ambient ink dust + slow wash veins under paper.
/// Lives between the paper and gameplay so it adds depth without obscuring.
/// Accelerates with combo for hype-time vibes.
class Atmosphere extends Component
    with HasGameReference<FlamekutGame> {
  Atmosphere({required this.worldSize}) : super(priority: -900);

  final Vector2 worldSize;
  final math.Random _rng = math.Random(13);

  late final List<_Petal> _petals = List.generate(22, (_) => _spawnPetal(initial: true));
  late final List<_Dust> _dust = List.generate(80, (_) => _spawnDust());
  late final List<_Vein> _veins = List.generate(7, (_) => _spawnVein());

  double _t = 0;

  _Petal _spawnPetal({bool initial = false}) {
    return _Petal(
      x: _rng.nextDouble() * worldSize.x,
      y: initial ? _rng.nextDouble() * worldSize.y : -40 - _rng.nextDouble() * 200,
      size: 9 + _rng.nextDouble() * 12,
      vy: 18 + _rng.nextDouble() * 26,
      drift: 18 + _rng.nextDouble() * 30,
      driftPhase: _rng.nextDouble() * math.pi * 2,
      spin: (_rng.nextDouble() - 0.5) * 1.4,
      rot: _rng.nextDouble() * math.pi * 2,
      depth: 0.5 + _rng.nextDouble() * 0.5,
    );
  }

  _Dust _spawnDust() {
    return _Dust(
      x: _rng.nextDouble() * worldSize.x,
      y: _rng.nextDouble() * worldSize.y,
      r: 0.8 + _rng.nextDouble() * 1.6,
      vy: 6 + _rng.nextDouble() * 12,
      a: 0.05 + _rng.nextDouble() * 0.1,
    );
  }

  _Vein _spawnVein() {
    final cx = _rng.nextDouble() * worldSize.x;
    final cy = _rng.nextDouble() * worldSize.y;
    final pts = <Offset>[];
    var ang = _rng.nextDouble() * math.pi * 2;
    var x = cx, y = cy;
    final segs = 6 + _rng.nextInt(5);
    for (var i = 0; i < segs; i++) {
      pts.add(Offset(x, y));
      ang += (_rng.nextDouble() - 0.5) * 1.1;
      final step = 80 + _rng.nextDouble() * 110;
      x += math.cos(ang) * step;
      y += math.sin(ang) * step;
    }
    return _Vein(
      points: pts,
      width: 14 + _rng.nextDouble() * 22,
      alpha: 0.025 + _rng.nextDouble() * 0.025,
      driftPhase: _rng.nextDouble() * math.pi * 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    // Hype factor speeds up ambient motion as combo climbs (1× → 2.4×).
    final tier = (game.combo / 10.0).clamp(0.0, 1.0).toDouble();
    final hype = 1.0 + tier * 1.4;
    for (var i = 0; i < _petals.length; i++) {
      final p = _petals[i];
      p.y += p.vy * dt * p.depth * hype;
      p.x += math.sin(_t * 0.7 + p.driftPhase) * p.drift * dt * hype;
      p.rot += p.spin * dt * hype;
      if (p.y > worldSize.y + 40) {
        _petals[i] = _spawnPetal();
      }
    }
    for (var i = 0; i < _dust.length; i++) {
      final d = _dust[i];
      d.y += d.vy * dt * hype;
      if (d.y > worldSize.y + 5) {
        d.x = _rng.nextDouble() * worldSize.x;
        d.y = -5;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Slow, subtle ink veins drifting beneath everything.
    for (final v in _veins) {
      final shift = math.sin(_t * 0.3 + v.driftPhase) * 4;
      final path = Path();
      if (v.points.isNotEmpty) {
        path.moveTo(v.points.first.dx + shift, v.points.first.dy);
        for (var i = 1; i < v.points.length - 1; i++) {
          final mid = Offset(
            (v.points[i].dx + v.points[i + 1].dx) / 2 + shift,
            (v.points[i].dy + v.points[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(
            v.points[i].dx + shift,
            v.points[i].dy,
            mid.dx,
            mid.dy,
          );
        }
        path.lineTo(v.points.last.dx + shift, v.points.last.dy);
      }
      final paint = Paint()
        ..color = Color.fromRGBO(98, 80, 56, v.alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = v.width
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawPath(path, paint);
    }

    // Ambient dust specks
    final dustPaint = Paint();
    for (final d in _dust) {
      dustPaint.color = Color.fromRGBO(60, 48, 36, d.a);
      canvas.drawCircle(Offset(d.x, d.y), d.r, dustPaint);
    }

    // Sakura petals — small ink-and-blush brushstrokes.
    for (final p in _petals) {
      _drawPetal(canvas, p);
    }
  }

  void _drawPetal(Canvas canvas, _Petal p) {
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.rot);
    final s = p.size;

    // Soft body
    final body = Paint()
      ..color = Color.fromRGBO(196, 102, 110, 0.32 * p.depth);
    final path = Path()
      ..moveTo(0, -s * 0.5)
      ..quadraticBezierTo(s * 0.55, -s * 0.05, 0, s * 0.5)
      ..quadraticBezierTo(-s * 0.55, -s * 0.05, 0, -s * 0.5)
      ..close();
    canvas.drawPath(path, body);

    // Notch at the bottom (sakura split)
    final notch = Paint()
      ..color = const Color(0xFFEFE7D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, s * 0.5), Offset(0, s * 0.2), notch);

    // Spine — a darker brush mark
    final spine = Paint()
      ..color = Color.fromRGBO(120, 60, 60, 0.28 * p.depth)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -s * 0.4), Offset(0, s * 0.35), spine);

    canvas.restore();
  }
}

class _Petal {
  _Petal({
    required this.x,
    required this.y,
    required this.size,
    required this.vy,
    required this.drift,
    required this.driftPhase,
    required this.spin,
    required this.rot,
    required this.depth,
  });

  double x, y, rot;
  final double size, vy, drift, driftPhase, spin, depth;
}

class _Dust {
  _Dust({
    required this.x,
    required this.y,
    required this.r,
    required this.vy,
    required this.a,
  });
  double x, y;
  final double r, vy, a;
}

class _Vein {
  _Vein({
    required this.points,
    required this.width,
    required this.alpha,
    required this.driftPhase,
  });
  final List<Offset> points;
  final double width, alpha, driftPhase;
}
