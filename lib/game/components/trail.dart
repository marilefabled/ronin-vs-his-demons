import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

class PathTrail extends Component {
  PathTrail() : super(priority: 5);

  List<Vector2> _points = [];
  final List<double> _segLen = [];
  final List<_Bleed> _bleeds = [];
  double _opacity = 1.0;
  double _fadeRate = 0;
  double _t = 0;
  final math.Random _rng = math.Random();

  void setPoints(List<Vector2> pts) {
    final next = pts.map((p) => p.clone()).toList();
    // Spawn bleed dabs for newly-added points only.
    if (next.length > _points.length && _points.isNotEmpty) {
      for (var i = _points.length; i < next.length; i++) {
        _spawnBleeds(next[i]);
      }
    } else if (_points.isEmpty && next.isNotEmpty) {
      for (final p in next) {
        _spawnBleeds(p);
      }
    }
    _points = next;
    _segLen.clear();
    for (var i = 0; i < _points.length - 1; i++) {
      _segLen.add((_points[i + 1] - _points[i]).length);
    }
    _opacity = 1.0;
    _fadeRate = 0;
  }

  void _spawnBleeds(Vector2 origin) {
    final n = 2 + _rng.nextInt(3);
    for (var i = 0; i < n; i++) {
      final ang = _rng.nextDouble() * math.pi * 2;
      final dist = 10 + _rng.nextDouble() * 14;
      _bleeds.add(_Bleed(
        x: origin.x + math.cos(ang) * dist,
        y: origin.y + math.sin(ang) * dist,
        r: 1.4 + _rng.nextDouble() * 2.6,
        a: 0.22 + _rng.nextDouble() * 0.22,
        born: _t,
      ));
    }
  }

  void clear() {
    _points = [];
    _segLen.clear();
    _bleeds.clear();
  }

  void fade() {
    _fadeRate = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_fadeRate > 0) {
      _opacity = (_opacity - _fadeRate * dt).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_opacity <= 0 || _points.isEmpty) return;

    if (_points.length >= 2) {
      // Build smoothed path — quadratic Bezier midpoints.
      final path = Path()..moveTo(_points.first.x, _points.first.y);
      for (var i = 1; i < _points.length - 1; i++) {
        final mid = (_points[i] + _points[i + 1]) / 2;
        path.quadraticBezierTo(_points[i].x, _points[i].y, mid.x, mid.y);
      }
      path.lineTo(_points.last.x, _points.last.y);

      // Soft outer wash (uniform width, blurred — gives sumi-e bleed)
      final wash = Paint()
        ..color = Color.fromRGBO(26, 22, 18, 0.18 * _opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..blendMode = BlendMode.multiply;
      canvas.drawPath(path, wash);

      // Mid stroke — multiply darkens richly where strokes overlap
      final mid = Paint()
        ..color = Color.fromRGBO(26, 22, 18, 0.65 * _opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.multiply;
      canvas.drawPath(path, mid);

      // Variable-width inner
      final inner = Paint()
        ..color = Color.fromRGBO(20, 17, 14, 0.95 * _opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.multiply;
      for (var i = 0; i < _segLen.length; i++) {
        final segL = _segLen[i];
        // Map: short (~16px) → 7.5, long (~80px) → 3.5
        final w = (8.5 - (segL - 16) / 22).clamp(3.0, 8.5);
        inner.strokeWidth = w;
        canvas.drawLine(
          Offset(_points[i].x, _points[i].y),
          Offset(_points[i + 1].x, _points[i + 1].y),
          inner,
        );
      }

      // Sample-point ink dots
      final dot = Paint()..color = Color.fromRGBO(20, 17, 14, 0.55 * _opacity);
      for (final p in _points) {
        canvas.drawCircle(Offset(p.x, p.y), 1.6, dot);
      }

      // Pooled drop at the head (where the samurai is during plan)
      final head = _points.last;
      final pool = Paint()
        ..color = Color.fromRGBO(20, 17, 14, 0.55 * _opacity);
      canvas.drawCircle(Offset(head.x, head.y), 7, pool);
      final poolWash = Paint()
        ..color = Color.fromRGBO(20, 17, 14, 0.18 * _opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(head.x, head.y), 13, poolWash);
    }

    // Ink bleed dabs (jittered around sample points)
    final bleed = Paint();
    for (final b in _bleeds) {
      final age = _t - b.born;
      final fade = (1 - age / 1.4).clamp(0.0, 1.0);
      bleed.color = Color.fromRGBO(20, 17, 14, b.a * _opacity * fade);
      canvas.drawCircle(Offset(b.x, b.y), b.r, bleed);
    }
  }
}

class _Bleed {
  _Bleed({
    required this.x,
    required this.y,
    required this.r,
    required this.a,
    required this.born,
  });
  final double x, y, r, a, born;
}
