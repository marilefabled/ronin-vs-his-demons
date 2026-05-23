import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

class Lantern extends PositionComponent with HasGameReference<FlamekutGame> {
  Lantern({required Vector2 position, this.phase = 0})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(110, 170),
          priority: 5,
        );

  final double phase;
  double _t = 0;
  double _proximity = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    // Closer the samurai gets, the brighter the lantern shimmers.
    final dist = (game.samurai.position - position).length;
    final target = (1 - (dist / 700).clamp(0.0, 1.0)).toDouble();
    _proximity += (target - _proximity) * dt * 2.5;
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final flicker = 0.85 + math.sin(_t * 4 + phase) * 0.08 + math.sin(_t * 11 + phase) * 0.04;
    final intensity = (0.55 + _proximity * 0.45) * flicker;

    // Outer halo — additive bloom
    final halo = Paint()
      ..color = Color.fromRGBO(238, 142, 70, 0.32 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset.zero, 130, halo);

    final mid = Paint()
      ..color = Color.fromRGBO(245, 168, 96, 0.42 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset.zero, 70, mid);

    // Top bracket
    final bracket = Paint()..color = const Color(0xCC1A1612);
    canvas.drawRect(const Rect.fromLTWH(-6, -84, 12, 18), bracket);
    canvas.drawRect(const Rect.fromLTWH(-26, -68, 52, 4), bracket);

    // Lantern body (chōchin) — vertical oval, ribbed
    final body = Paint()..color = Color.fromRGBO(220, 88, 60, 0.95);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 56, height: 92),
      body,
    );

    // Ribs
    final rib = Paint()
      ..color = Color.fromRGBO(70, 24, 18, 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (var i = -3; i <= 3; i++) {
      final y = i * 12.0;
      final w = 56 * math.sqrt(1 - (y / 46) * (y / 46));
      canvas.drawLine(Offset(-w / 2, y), Offset(w / 2, y), rib);
    }

    // Inner glow / kanji-like brush mark
    final inner = Paint()
      ..color = Color.fromRGBO(255, 220, 160, 0.45 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 60),
      inner,
    );

    final mark = Paint()
      ..color = Color.fromRGBO(40, 16, 10, 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Single stylized brush mark — vertical with two horizontal accents
    canvas.drawLine(const Offset(0, -22), const Offset(0, 24), mark);
    canvas.drawLine(const Offset(-9, -10), const Offset(9, -10), mark);
    canvas.drawLine(const Offset(-7, 12), const Offset(7, 12), mark);

    // Base cap
    final cap = Paint()..color = const Color(0xCC1A1612);
    canvas.drawRect(const Rect.fromLTWH(-22, 46, 44, 8), cap);

    // Small tassel
    final tassel = Paint()
      ..color = Color.fromRGBO(220, 88, 60, 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final swing = math.sin(_t * 1.2 + phase) * 3;
    canvas.drawLine(Offset(swing, 56), Offset(swing * 1.3, 74), tassel);
  }
}
