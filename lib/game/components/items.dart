import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

enum PowerUp { dragon, slow, ghost }

/// Pickup item — walking through it during run grants a power-up.
class ItemPickup extends PositionComponent
    with HasGameReference<FlamekutGame> {
  ItemPickup({required Vector2 position, required this.kind})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(120),
          priority: 5,
        );

  final PowerUp kind;
  bool _consumed = false;
  double _t = 0;
  late final double _bobPhase = math.Random().nextDouble() * math.pi * 2;
  late final Vector2 _anchor = position.clone();

  Color get _primary {
    switch (kind) {
      case PowerUp.dragon:
        return const Color(0xFFD45438);
      case PowerUp.slow:
        return const Color(0xFF5BA8C8);
      case PowerUp.ghost:
        return const Color(0xFFA48ABE);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_consumed) return;
    final scaled = dt * game.worldTimeScale;
    _t += scaled;
    // Hover bob in place
    position
      ..x = _anchor.x + math.cos(_t * 1.4 + _bobPhase) * 4
      ..y = _anchor.y + math.sin(_t * 1.6 + _bobPhase) * 6;

    // Pickup detection during run
    if (game.phase == GamePhase.running) {
      final dist = position.distanceToSquared(game.samurai.position);
      const r = 50.0;
      if (dist < r * r) {
        _consumed = true;
        game.onItemPickup(this);
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final t = _t;
    final pulse = math.sin(t * 3.5 + _bobPhase) * 0.12 + 1.0;
    final c = _primary;

    // Outer glow
    final glow = Paint()
      ..color = c.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset.zero, 38 * pulse, glow);

    // Mid layer
    final mid = Paint()
      ..color = c.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, 22 * pulse, mid);

    // Disc body
    final disc = Paint()..color = c.withValues(alpha: 0.92);
    canvas.drawCircle(Offset.zero, 18, disc);

    // Pale inner
    final inner = Paint()..color = const Color(0xCCEFE7D6);
    canvas.drawCircle(Offset.zero, 13, inner);

    // Kanji-style brushstroke mark unique to power-up
    final mark = Paint()
      ..color = c.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;

    switch (kind) {
      case PowerUp.dragon:
        // 龍-like — vertical with wave hooks
        canvas.drawLine(const Offset(0, -10), const Offset(0, 9), mark);
        canvas.drawLine(const Offset(-8, -6), const Offset(8, -6), mark);
        final w = Path()
          ..moveTo(-7, 5)
          ..quadraticBezierTo(0, 2, 7, 5);
        canvas.drawPath(w, mark);
        break;
      case PowerUp.slow:
        // 静-like — concentric arcs (still water)
        mark.style = PaintingStyle.stroke;
        mark.strokeWidth = 2.3;
        canvas.drawArc(
            Rect.fromCenter(center: Offset.zero, width: 14, height: 10),
            -math.pi * 0.9,
            math.pi * 0.8,
            false,
            mark);
        canvas.drawArc(
            Rect.fromCenter(center: Offset.zero, width: 22, height: 16),
            -math.pi * 0.85,
            math.pi * 0.7,
            false,
            mark);
        // Center dot
        final dot = Paint()..color = c.withValues(alpha: 0.95);
        canvas.drawCircle(Offset.zero, 2.2, dot);
        break;
      case PowerUp.ghost:
        // 影-like — vertical with diagonal hooks
        canvas.drawLine(const Offset(-4, -10), const Offset(-4, 9), mark);
        canvas.drawLine(const Offset(4, -10), const Offset(4, 9), mark);
        canvas.drawLine(const Offset(-8, -6), const Offset(8, -6), mark);
        canvas.drawLine(const Offset(-3, 7), const Offset(-7, 11), mark);
        canvas.drawLine(const Offset(3, 7), const Offset(7, 11), mark);
        break;
    }
  }
}
