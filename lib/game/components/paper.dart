import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient, RadialGradient;

import '../flamekut_game.dart';

/// Sumi-e paper background. Renders via fragment shader when available
/// (animated noise + drifting wash veins + vignette). Falls back to a
/// procedural Canvas rendering of stains otherwise.
class PaperBackground extends Component
    with HasGameReference<FlamekutGame> {
  PaperBackground({required this.size}) : super(priority: -1000);

  final Vector2 size;
  double _t = 0;
  ui.FragmentShader? _shader;

  // Fallback static stains
  final math.Random _rng = math.Random(7);
  late final List<_Stain> _stains = _genStains();

  List<_Stain> _genStains() {
    final out = <_Stain>[];
    for (var i = 0; i < 220; i++) {
      out.add(_Stain(
        x: _rng.nextDouble() * size.x,
        y: _rng.nextDouble() * size.y,
        r: 6 + _rng.nextDouble() * 22,
        a: 0.012 + _rng.nextDouble() * 0.025,
      ));
    }
    for (var i = 0; i < 9; i++) {
      out.add(_Stain(
        x: _rng.nextDouble() * size.x,
        y: _rng.nextDouble() * size.y,
        r: 80 + _rng.nextDouble() * 240,
        a: 0.018 + _rng.nextDouble() * 0.018,
      ));
    }
    return out;
  }

  @override
  Future<void> onMount() async {
    super.onMount();
    final program = game.shaders.paper;
    _shader = program?.fragmentShader();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final shader = _shader;
    if (shader != null) {
      shader
        ..setFloat(0, size.x)
        ..setFloat(1, size.y)
        ..setFloat(2, _t);
      final paint = Paint()..shader = shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
      return;
    }
    _renderFallback(canvas);
  }

  void _renderFallback(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF3ECDB), Color(0xFFE7DEC8)],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final washPaint = Paint();
    for (final s in _stains) {
      washPaint.color = Color.fromRGBO(138, 122, 82, s.a);
      canvas.drawCircle(Offset(s.x, s.y), s.r, washPaint);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          const Color(0x00000000),
          const Color(0x331A1612),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }
}

class _Stain {
  final double x, y, r, a;
  _Stain({required this.x, required this.y, required this.r, required this.a});
}
