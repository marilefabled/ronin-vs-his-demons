import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

/// Additive radial bloom rendered via fragment shader. Drops the
/// MaskFilter.blur faked-bloom approach for a real GPU pass.
class ShaderGlow extends Component
    with HasGameReference<FlamekutGame> {
  ShaderGlow({
    required this.position,
    required this.color,
    this.radius = 220,
    this.peak = 1.0,
    this.duration = 0.42,
    this.hotCore = 0.5,
  }) : super(priority: 36);

  final Vector2 position;
  final Color color;
  final double radius;
  final double peak;
  final double duration;
  final double hotCore;

  ui.FragmentShader? _shader;
  double _t = 0;

  @override
  Future<void> onMount() async {
    super.onMount();
    _shader = game.shaders.glow?.fragmentShader();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final shader = _shader;
    final p = (_t / duration).clamp(0.0, 1.0);
    // Fast in, slow out
    final intensity = peak * (p < 0.18 ? p / 0.18 : 1 - (p - 0.18) / 0.82);
    if (intensity <= 0.005) return;

    final r = radius;
    final rect = Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: r * 2,
      height: r * 2,
    );

    if (shader != null) {
      shader
        ..setFloat(0, r * 2) // uSize.x
        ..setFloat(1, r * 2) // uSize.y
        ..setFloat(2, intensity)
        ..setFloat(3, hotCore)
        ..setFloat(4, color.r)
        ..setFloat(5, color.g)
        ..setFloat(6, color.b);
      final paint = Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus;
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.drawRect(Rect.fromLTWH(0, 0, r * 2, r * 2), paint);
      canvas.restore();
      return;
    }

    // Fallback: layered translucent circles with blur
    final outer = Paint()
      ..color = color.withValues(alpha: 0.30 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(position.x, position.y), r * 0.85, outer);
    final core = Paint()
      ..color = color.withValues(alpha: 0.70 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(position.x, position.y), r * 0.30, core);
  }
}

/// Full-screen chromatic aberration overlay — RGB-split rim that fires on
/// high-combo hits.
class ChromaticBurst extends Component
    with HasGameReference<FlamekutGame> {
  ChromaticBurst({this.intensity = 0.7, this.duration = 0.35})
      : super(priority: 240);

  final double intensity;
  final double duration;
  ui.FragmentShader? _shader;
  double _t = 0;

  @override
  Future<void> onMount() async {
    super.onMount();
    _shader = game.shaders.chromatic?.fragmentShader();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final shader = _shader;
    if (shader == null) return; // no fallback — purely an extra
    final p = (_t / duration).clamp(0.0, 1.0);
    final fade = 1 - p;
    final amp = intensity * fade;
    if (amp <= 0.01) return;

    shader
      ..setFloat(0, FlamekutGame.worldW)
      ..setFloat(1, FlamekutGame.worldH)
      ..setFloat(2, amp)
      ..setFloat(3, _t);
    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      paint,
    );
  }
}
