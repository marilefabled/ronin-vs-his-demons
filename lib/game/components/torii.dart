import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../flamekut_game.dart';

class Torii extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  Torii({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(260, 320),
          priority: 6,
        );

  double _t = 0;
  double _committed = 0;
  double _approach = 0;

  // Procedural wood grain — fixed seed so it doesn't shimmer.
  final math.Random _grainRng = math.Random(91);
  late final List<_Grain> _leftGrain = _genGrain(-78, 18, 200);
  late final List<_Grain> _rightGrain = _genGrain(60, 18, 200);
  late final List<_Grain> _topGrain = _genGrain(-100, 200, 22);

  List<_Grain> _genGrain(double x, double w, double h) {
    final list = <_Grain>[];
    final n = (w * h / 90).round();
    for (var i = 0; i < n; i++) {
      list.add(_Grain(
        x: x + _grainRng.nextDouble() * w,
        y: -100 + _grainRng.nextDouble() * h,
        len: 4 + _grainRng.nextDouble() * 14,
        a: 0.12 + _grainRng.nextDouble() * 0.18,
      ));
    }
    return list;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (game.phase != GamePhase.plan) {
      _committed = (_committed + dt * 1.5).clamp(0.0, 1.0);
    } else {
      _committed = (_committed - dt * 1.5).clamp(0.0, 1.0);
    }
    final dist = (game.samurai.position - position).length;
    final tgt = (1 - (dist / 1100).clamp(0.0, 1.0)).toDouble();
    _approach += (tgt - _approach) * dt * 2.2;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    game.commitAndRun();
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final pulse = math.sin(_t * 1.6) * 0.5 + 0.5;
    final dim = 1.0 - _committed * 0.4;
    final base = Color.fromRGBO(167, 41, 32, 0.92 * dim);

    // Gate halo — pulses in plan phase, brightens with proximity in run
    final haloA = (game.phase == GamePhase.plan ? 0.16 + 0.10 * pulse : 0.10) +
        _approach * 0.18;
    final halo = Paint()
      ..color = Color.fromRGBO(238, 142, 70, haloA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(const Offset(0, -10), 150, halo);

    // Stone foundation under each post
    _drawStone(canvas, const Offset(-69, 88));
    _drawStone(canvas, const Offset(69, 88));

    // Posts
    final post = Paint()..color = base;
    canvas.drawRect(const Rect.fromLTWH(-78, -100, 18, 200), post);
    canvas.drawRect(const Rect.fromLTWH(60, -100, 18, 200), post);

    // Wood grain on posts — a darker wash
    final grain = Paint()
      ..color = Color.fromRGBO(70, 18, 14, 1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (final g in _leftGrain) {
      grain.color = Color.fromRGBO(70, 18, 14, g.a * dim);
      canvas.drawLine(Offset(g.x, g.y), Offset(g.x, g.y + g.len), grain);
    }
    for (final g in _rightGrain) {
      grain.color = Color.fromRGBO(70, 18, 14, g.a * dim);
      canvas.drawLine(Offset(g.x, g.y), Offset(g.x, g.y + g.len), grain);
    }

    // Top beam (kasagi)
    final beamPath = Path()
      ..moveTo(-104, -100)
      ..quadraticBezierTo(0, -136, 104, -100)
      ..lineTo(104, -76)
      ..quadraticBezierTo(0, -110, -104, -76)
      ..close();
    canvas.drawPath(beamPath, post);

    // Beam grain (horizontal)
    for (final g in _topGrain) {
      grain.color = Color.fromRGBO(70, 18, 14, g.a * 0.7 * dim);
      canvas.drawLine(Offset(g.x, g.y), Offset(g.x + g.len, g.y), grain);
    }

    // Brushstroke kanji-style mark on the kasagi (white ink)
    _drawKasagiMark(canvas, dim);

    // Second beam (nuki)
    canvas.drawRect(const Rect.fromLTWH(-86, -60, 172, 14), post);

    // Shimenawa rope — paper streamers (shide)
    _drawShimenawa(canvas, dim);

    // Stairs — three descending strokes underneath
    final stair = Paint()..color = Color.fromRGBO(20, 17, 14, 0.85 * dim);
    canvas.drawRect(const Rect.fromLTWH(-94, 96, 188, 8), stair);
    canvas.drawRect(const Rect.fromLTWH(-108, 114, 216, 8), stair);
    canvas.drawRect(const Rect.fromLTWH(-124, 132, 248, 8), stair);
    canvas.drawRect(const Rect.fromLTWH(-142, 152, 284, 8), stair);

    // Distant mist behind torii (fades the world above)
    final mist = Paint()
      ..color = Color.fromRGBO(245, 240, 225, 0.18 + _approach * 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -50), width: 380, height: 130),
      mist,
    );
  }

  void _drawStone(Canvas canvas, Offset c) {
    final stone = Paint()..color = const Color(0xFF55473A);
    canvas.drawOval(Rect.fromCenter(center: c, width: 44, height: 18), stone);
    final hi = Paint()..color = Color.fromRGBO(120, 100, 80, 0.6);
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -3), width: 28, height: 8),
      hi,
    );
  }

  void _drawShimenawa(Canvas canvas, double dim) {
    final rope = Paint()
      ..color = Color.fromRGBO(245, 240, 225, 0.92 * dim)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-60, -86), const Offset(60, -86), rope);

    // Twist marks
    final twist = Paint()
      ..color = Color.fromRGBO(190, 165, 110, 0.6 * dim)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = -5; i <= 5; i++) {
      final x = i * 11.0;
      canvas.drawLine(Offset(x - 3, -88), Offset(x + 3, -84), twist);
    }

    // Shide (paper streamers)
    final shide = Paint()..color = Color.fromRGBO(245, 240, 225, 0.96 * dim);
    for (final cx in [-32.0, 0.0, 32.0]) {
      final p = Path()
        ..moveTo(cx - 5, -82)
        ..lineTo(cx + 5, -82)
        ..lineTo(cx + 8, -68)
        ..lineTo(cx - 2, -75)
        ..lineTo(cx - 8, -68)
        ..close();
      canvas.drawPath(p, shide);
    }
  }

  void _drawKasagiMark(Canvas canvas, double dim) {
    final mark = Paint()
      ..color = Color.fromRGBO(245, 240, 225, 0.88 * dim)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // A stylized brush kanji — vertical down-stroke + two crossings + a hook
    canvas.drawLine(const Offset(0, -126), const Offset(0, -90), mark);
    canvas.drawLine(const Offset(-12, -116), const Offset(12, -116), mark);
    canvas.drawLine(const Offset(-9, -103), const Offset(9, -103), mark);

    // Tail flick
    final hook = Path()
      ..moveTo(-2, -92)
      ..quadraticBezierTo(2, -88, 6, -92);
    canvas.drawPath(hook, mark);
  }
}

class _Grain {
  _Grain({required this.x, required this.y, required this.len, required this.a});
  final double x, y, len, a;
}
