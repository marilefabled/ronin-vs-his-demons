import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

class Projectile extends PositionComponent
    with HasGameReference<FlamekutGame> {
  Projectile({required Vector2 position, required this.velocity})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(40),
          priority: 8,
        );

  final Vector2 velocity;
  double _t = 0;
  static const double _life = 4.5;
  bool _consumed = false;

  @override
  void update(double dt) {
    super.update(dt);
    final ts = game.worldTimeScale;
    _t += dt * ts;
    position.x += velocity.x * dt * ts;
    position.y += velocity.y * dt * ts;

    // Off-screen cull
    if (position.x < -60 ||
        position.x > FlamekutGame.worldW + 60 ||
        position.y < -60 ||
        position.y > FlamekutGame.worldH + 60 ||
        _t > _life) {
      removeFromParent();
      return;
    }

    // Hit samurai (only during run phase, only once)
    if (!_consumed && game.phase == GamePhase.running) {
      final samurai = game.samurai;
      const r = 30.0;
      if (position.distanceToSquared(samurai.position) < r * r) {
        _consumed = true;
        game.onProjectileHitsSamurai(this);
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);

    // Trail
    final dir = velocity.normalized();
    final trail = Paint()
      ..color = Color.fromRGBO(229, 57, 43, 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-dir.x * 28, -dir.y * 28),
      Offset.zero,
      trail,
    );

    // Outer glow
    final pulse = math.sin(_t * 18) * 0.15 + 1.0;
    final glow = Paint()
      ..color = Color.fromRGBO(229, 57, 43, 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, 14 * pulse, glow);

    // Red ring
    final ring = Paint()
      ..color = const Color(0xFFE5392B);
    canvas.drawCircle(Offset.zero, 9, ring);

    // White core
    final core = Paint()..color = const Color(0xFFFFEEE0);
    canvas.drawCircle(Offset.zero, 4.5, core);
  }
}
