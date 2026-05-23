import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// Full-screen ink-paper wipe that fades from opaque to transparent over
/// [duration]s. Used at scene boundaries for premium-feeling transitions.
class SceneFader extends Component {
  SceneFader({this.duration = 0.32, this.color = const Color(0xFF1A1612)})
      : super(priority: 3000);

  final double duration;
  final Color color;
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
    // Two-phase: hold full ~10%, then ease out ~90%.
    final fade = p < 0.10 ? 1.0 : 1.0 - ((p - 0.10) / 0.90);
    final alpha = (fade.clamp(0.0, 1.0) * 0.92).clamp(0.0, 1.0);
    if (alpha <= 0.001) return;
    final paint = Paint()..color = color.withValues(alpha: alpha);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      paint,
    );
  }
}
