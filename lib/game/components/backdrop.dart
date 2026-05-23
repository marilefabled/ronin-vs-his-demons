import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

/// Distant scenery that sits between the paper background and the gameplay
/// layer. Mountains horizon, bamboo grove edges, faint sun. All very low
/// opacity so it never competes with playable elements.
class Backdrop extends Component
    with HasGameReference<FlamekutGame> {
  Backdrop() : super(priority: -800);

  double _t = 0;
  late final List<_BambooStalk> _leftBamboo = _genBamboo(side: -1);
  late final List<_BambooStalk> _rightBamboo = _genBamboo(side: 1);

  List<_BambooStalk> _genBamboo({required int side}) {
    final r = math.Random(side == -1 ? 91 : 97);
    final list = <_BambooStalk>[];
    final count = 4 + r.nextInt(3);
    for (var i = 0; i < count; i++) {
      list.add(_BambooStalk(
        x: side == -1
            ? 18.0 + r.nextDouble() * 80
            : FlamekutGame.worldW - 18 - r.nextDouble() * 80,
        bottom: FlamekutGame.worldH * (0.35 + r.nextDouble() * 0.55),
        top: FlamekutGame.worldH * (-0.05 + r.nextDouble() * 0.05),
        width: 6 + r.nextDouble() * 6,
        sway: r.nextDouble() * math.pi * 2,
        alpha: 0.10 + r.nextDouble() * 0.07,
      ));
    }
    return list;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    _drawSun(canvas);
    _drawMountains(canvas);
    _drawBamboo(canvas, _leftBamboo);
    _drawBamboo(canvas, _rightBamboo);
  }

  void _drawSun(Canvas canvas) {
    // Faint red disc behind the torii. Brightens slightly during gameplay.
    final sceneAlpha = game.scene == AppScene.gameplay ? 0.22 : 0.30;
    final cx = FlamekutGame.worldW / 2;
    final cy = FlamekutGame.worldH * 0.16;

    final outer = Paint()
      ..color = Color.fromRGBO(220, 88, 60, 0.18 * sceneAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(cx, cy), 240, outer);

    final mid = Paint()
      ..color = Color.fromRGBO(196, 56, 36, 0.30 * sceneAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset(cx, cy), 140, mid);

    final disc = Paint()
      ..color = Color.fromRGBO(167, 41, 32, 0.55 * sceneAlpha);
    canvas.drawCircle(Offset(cx, cy), 90, disc);
  }

  void _drawMountains(Canvas canvas) {
    final w = FlamekutGame.worldW;
    final base = FlamekutGame.worldH * 0.30;

    // Far range — most distant, lowest contrast
    final far = Paint()
      ..color = Color.fromRGBO(58, 50, 40, 0.18)
      ..blendMode = BlendMode.multiply;
    final farPath = Path()..moveTo(-30, base);
    farPath.quadraticBezierTo(w * 0.10, base - 60, w * 0.20, base - 30);
    farPath.quadraticBezierTo(w * 0.30, base - 95, w * 0.42, base - 50);
    farPath.quadraticBezierTo(w * 0.55, base - 120, w * 0.66, base - 60);
    farPath.quadraticBezierTo(w * 0.78, base - 110, w * 0.88, base - 50);
    farPath.quadraticBezierTo(w * 0.96, base - 80, w + 30, base - 20);
    farPath.lineTo(w + 30, base + 80);
    farPath.lineTo(-30, base + 80);
    farPath.close();
    canvas.drawPath(farPath, far);

    // Near range — slightly lower, more contrast
    final near = Paint()
      ..color = Color.fromRGBO(38, 32, 26, 0.30)
      ..blendMode = BlendMode.multiply;
    final nearBase = FlamekutGame.worldH * 0.36;
    final nearPath = Path()..moveTo(-30, nearBase);
    nearPath.quadraticBezierTo(w * 0.06, nearBase - 30, w * 0.14, nearBase);
    nearPath.quadraticBezierTo(w * 0.22, nearBase - 60, w * 0.34, nearBase - 20);
    nearPath.quadraticBezierTo(w * 0.46, nearBase - 70, w * 0.55, nearBase - 30);
    nearPath.quadraticBezierTo(w * 0.66, nearBase - 90, w * 0.78, nearBase - 30);
    nearPath.quadraticBezierTo(w * 0.88, nearBase - 50, w * 0.96, nearBase);
    nearPath.lineTo(w + 30, nearBase + 80);
    nearPath.lineTo(-30, nearBase + 80);
    nearPath.close();
    canvas.drawPath(nearPath, near);

    // Snow caps (subtle white touches on the highest peaks)
    final cap = Paint()..color = Color.fromRGBO(245, 240, 225, 0.22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.55, base - 110),
        width: 28,
        height: 6,
      ),
      cap,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.30, base - 85),
        width: 20,
        height: 4,
      ),
      cap,
    );
  }

  void _drawBamboo(Canvas canvas, List<_BambooStalk> stalks) {
    final stalkPaint = Paint()..blendMode = BlendMode.multiply;
    for (final s in stalks) {
      final swayOff = math.sin(_t * 0.45 + s.sway) * 4;
      stalkPaint.color = Color.fromRGBO(40, 50, 40, s.alpha);

      // Main stalk
      final stalkPath = Path()
        ..moveTo(s.x - s.width / 2 + swayOff * 0.3, s.bottom)
        ..lineTo(s.x + s.width / 2 + swayOff * 0.3, s.bottom)
        ..lineTo(s.x + s.width / 2 + swayOff, s.top)
        ..lineTo(s.x - s.width / 2 + swayOff, s.top)
        ..close();
      canvas.drawPath(stalkPath, stalkPaint);

      // Joint nodes (visible breaks every ~120px)
      final joint = Paint()
        ..color = Color.fromRGBO(30, 38, 28, s.alpha * 1.4)
        ..blendMode = BlendMode.multiply;
      final segCount = ((s.bottom - s.top) / 130).floor();
      for (var i = 1; i < segCount; i++) {
        final y = s.bottom - i * 130;
        final swayHere = math.sin(_t * 0.45 + s.sway) *
            (4 * (s.bottom - y) / (s.bottom - s.top));
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(s.x + swayHere, y),
            width: s.width + 2,
            height: 2.5,
          ),
          joint,
        );
      }

      // Occasional leaves (small pointed shapes)
      if (s.alpha > 0.13) {
        final leaf = Paint()
          ..color = Color.fromRGBO(45, 60, 42, s.alpha * 1.2)
          ..blendMode = BlendMode.multiply;
        final lx = s.x + (s.width / 2 + 6) * (s.x < FlamekutGame.worldW / 2 ? 1 : -1);
        final ly = s.bottom - (s.bottom - s.top) * 0.4;
        final leafPath = Path()
          ..moveTo(lx, ly)
          ..quadraticBezierTo(lx + 24, ly - 4, lx + 36, ly + 8)
          ..quadraticBezierTo(lx + 22, ly + 6, lx, ly + 4)
          ..close();
        canvas.drawPath(leafPath, leaf);
      }
    }
  }
}

class _BambooStalk {
  _BambooStalk({
    required this.x,
    required this.top,
    required this.bottom,
    required this.width,
    required this.sway,
    required this.alpha,
  });
  final double x, top, bottom, width, sway, alpha;
}
