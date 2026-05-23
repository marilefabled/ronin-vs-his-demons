import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../flamekut_game.dart';

/// Pure hazard — can't be killed, doesn't tally to kill count, instant
/// defeat on contact during run.
abstract class Hazard extends PositionComponent
    with HasGameReference<FlamekutGame> {
  Hazard({required super.position, double diameter = 80})
      : super(
          anchor: Anchor.center,
          size: Vector2.all(diameter),
          priority: 4,
        );

  /// Returns true if a circle of radius [pointRadius] at [point] overlaps
  /// this hazard.
  bool collidesWithPoint(Vector2 point, double pointRadius);
}

/// Kitsune-bi (fox-fire) — ghost flame. Drifts. Cyan/green palette so the
/// player reads "avoid" not "kill."
class Wisp extends Hazard {
  Wisp({required super.position}) : super(diameter: 100);

  double bodyRadius = 22;

  double _t = math.Random().nextDouble() * math.pi * 2;
  Vector2? _anchorPos;

  @override
  bool collidesWithPoint(Vector2 point, double pointRadius) {
    final r = bodyRadius + pointRadius;
    return position.distanceToSquared(point) < r * r;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt * game.worldTimeScale;
    motion(dt * game.worldTimeScale);
  }

  /// Default motion: slow drift around spawn anchor. Subclasses override.
  void motion(double dt) {
    _anchorPos ??= position.clone();
    final r = 14.0;
    position
      ..x = _anchorPos!.x + math.cos(_t * 0.9) * r
      ..y = _anchorPos!.y + math.sin(_t * 1.15) * (r * 0.7);
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final t = _t;
    final pulse = math.sin(t * 5) * 0.12 + 1.0;

    // Colorblind-shape mode: warning triangle floats above for distinction.
    if (game.settings.colorblindShapes) {
      _drawWarningTriangle(canvas);
    }

    // Outer aura — broad ghost glow
    final aura = Paint()
      ..color = Color.fromRGBO(80, 200, 200, 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawCircle(Offset.zero, 42 * pulse, aura);

    // Mid layer
    final mid = Paint()
      ..color = Color.fromRGBO(120, 220, 210, 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, 22 * pulse, mid);

    // Flame body
    final body = Paint()..color = Color.fromRGBO(160, 240, 230, 0.85);
    canvas.drawCircle(Offset.zero, 14, body);

    // White-hot core
    final core = Paint()..color = Color.fromRGBO(245, 255, 250, 0.95);
    canvas.drawCircle(Offset.zero, 6, core);

    // Wispy tendrils
    final tendril = Paint()
      ..color = Color.fromRGBO(120, 230, 220, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + t * 0.8;
      final r1 = 12 + math.sin(t * 4 + i) * 3;
      final r2 = 26 + math.sin(t * 5 + i * 1.4) * 8;
      canvas.drawLine(
        Offset(math.cos(a) * r1, math.sin(a) * r1),
        Offset(math.cos(a) * r2, math.sin(a) * r2),
        tendril,
      );
    }

    // Trailing sparks
    final spark = Paint()..color = Color.fromRGBO(180, 250, 240, 0.7);
    for (var i = 0; i < 4; i++) {
      final a = t * 1.5 + i * 1.6;
      final r = 28 + math.sin(t * 2 + i) * 6;
      canvas.drawCircle(
        Offset(math.cos(a) * r, math.sin(a) * r),
        1.8,
        spark,
      );
    }
  }

  void _drawWarningTriangle(Canvas canvas) {
    // Yellow triangle with a black "!" inside, hovering above the hazard.
    const c = Offset(0, -50);
    final tri = Path()
      ..moveTo(c.dx, c.dy - 14)
      ..lineTo(c.dx + 13, c.dy + 10)
      ..lineTo(c.dx - 13, c.dy + 10)
      ..close();
    final fill = Paint()..color = const Color(0xFFFFC640);
    canvas.drawPath(tri, fill);
    final stroke = Paint()
      ..color = const Color(0xFF1A1612)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(tri, stroke);
    final bar = Paint()..color = const Color(0xFF1A1612);
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(0, -1), width: 2.5, height: 8),
      bar,
    );
    canvas.drawCircle(c.translate(0, 6), 1.5, bar);
  }
}

/// Wisp that travels between two points with a sinuous wobble perpendicular
/// to its direction.
class WispPatrol extends Wisp {
  WispPatrol({
    required Vector2 position,
    required Vector2 endPoint,
    this.speed = 100,
  })  : _endPoint = endPoint.clone(),
        _startPoint = position.clone(),
        super(position: position);

  final Vector2 _startPoint;
  final Vector2 _endPoint;
  final double speed;
  late final double _segLen = (_endPoint - _startPoint).length;
  late final double _cycleDur = _segLen == 0 ? 1.0 : (_segLen / speed) * 2;
  late final double _patrolOffset = math.Random().nextDouble() * _cycleDur;

  @override
  void motion(double dt) {
    final tt = ((_t + _patrolOffset) % _cycleDur) / _cycleDur;
    final fwd = tt < 0.5 ? tt * 2 : (1 - tt) * 2;
    final eased = fwd * fwd * (3 - 2 * fwd);
    final delta = _endPoint - _startPoint;
    final perp = delta.length == 0
        ? Vector2.zero()
        : Vector2(-delta.y, delta.x) / delta.length;
    final wobble = math.sin(_t * 2.4) * 18;
    position
      ..x = _startPoint.x + delta.x * eased + perp.x * wobble
      ..y = _startPoint.y + delta.y * eased + perp.y * wobble;
  }
}

/// Static stone wall / boulder — barrier hazard. Can't be killed, can't be
/// passed through during run. Rectangular hitbox.
class Wall extends Hazard {
  Wall({
    required super.position,
    required this.halfExtents,
  }) : super(diameter: math.max(halfExtents.x, halfExtents.y) * 2.4) {
    size = halfExtents * 2;
  }

  final Vector2 halfExtents;
  final math.Random _rng = math.Random(7);
  late final List<_RockBlob> _blobs = _genBlobs();

  List<_RockBlob> _genBlobs() {
    final out = <_RockBlob>[];
    final n = ((halfExtents.x * halfExtents.y) / 700).round().clamp(5, 18);
    for (var i = 0; i < n; i++) {
      out.add(_RockBlob(
        x: (_rng.nextDouble() * 2 - 1) * halfExtents.x * 0.92,
        y: (_rng.nextDouble() * 2 - 1) * halfExtents.y * 0.92,
        rx: 14 + _rng.nextDouble() * 22,
        ry: 14 + _rng.nextDouble() * 18,
        rot: _rng.nextDouble() * math.pi,
        shade: 14 + _rng.nextInt(28),
      ));
    }
    return out;
  }

  @override
  bool collidesWithPoint(Vector2 point, double pointRadius) {
    final dx = (point.x - position.x).abs() - halfExtents.x;
    final dy = (point.y - position.y).abs() - halfExtents.y;
    if (dx <= 0 && dy <= 0) return true;
    final cx = math.max(0.0, dx);
    final cy = math.max(0.0, dy);
    return cx * cx + cy * cy < pointRadius * pointRadius;
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);

    // Soft shadow under
    final shadow = Paint()
      ..color = Color.fromRGBO(20, 17, 14, 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 6),
        width: halfExtents.x * 2.0,
        height: halfExtents.y * 1.6,
      ),
      shadow,
    );

    // Body wash
    final wash = Paint()
      ..color = Color.fromRGBO(48, 38, 30, 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: halfExtents.x * 2.0,
        height: halfExtents.y * 1.85,
      ),
      wash,
    );

    // Stacked dark ink blobs forming the rocky silhouette
    for (final b in _blobs) {
      canvas.save();
      canvas.translate(b.x, b.y);
      canvas.rotate(b.rot);
      final p = Paint()..color = Color.fromRGBO(b.shade, b.shade - 2, b.shade - 4, 0.96);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: b.rx * 2, height: b.ry * 2),
        p,
      );
      canvas.restore();
    }

    // A few lighter highlights to read as 3D
    final hi = Paint()..color = Color.fromRGBO(110, 95, 78, 0.45);
    for (var i = 0; i < (_blobs.length / 2).floor(); i++) {
      final b = _blobs[i];
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(b.x - b.rx * 0.25, b.y - b.ry * 0.45),
          width: b.rx * 0.7,
          height: b.ry * 0.35,
        ),
        hi,
      );
    }

    // Jagged edge spurs — small ink dabs along the perimeter (deterministic)
    final spur = Paint()..color = const Color(0xFF1A1612);
    for (var i = 0; i < 14; i++) {
      final a = i * (math.pi * 2 / 14);
      final ex = halfExtents.x * 0.95 * math.cos(a);
      final ey = halfExtents.y * 0.95 * math.sin(a);
      final r = 3 + math.sin(i * 1.7) * 1.4;
      canvas.drawCircle(Offset(ex, ey), r, spur);
    }
  }
}

class _RockBlob {
  _RockBlob({
    required this.x,
    required this.y,
    required this.rx,
    required this.ry,
    required this.rot,
    required this.shade,
  });
  final double x, y, rx, ry, rot;
  final int shade;
}

/// Spike trap — extends/retracts on a cycle. Lethal only while extended.
class SpikeField extends Hazard {
  SpikeField({
    required Vector2 position,
    required this.halfExtents,
    this.cycleDur = 2.8,
    this.deadlyFraction = 0.55,
    this.startPhase = 0,
  }) : super(position: position, diameter: math.max(halfExtents.x, halfExtents.y) * 2.4) {
    size = halfExtents * 2;
  }

  final Vector2 halfExtents;
  final double cycleDur;
  final double deadlyFraction;
  final double startPhase;
  double _t = 0;

  /// 0..1 within the lethal window; 0 outside it.
  double get extension {
    final p = ((_t + startPhase) % cycleDur) / cycleDur;
    if (p > deadlyFraction) return 0.0;
    final inner = p / deadlyFraction;
    return math.sin(inner * math.pi).clamp(0.0, 1.0);
  }

  /// 0..1 in the lead-up to the next extension cycle.
  double get warning {
    final p = ((_t + startPhase) % cycleDur) / cycleDur;
    if (p < deadlyFraction) return 0.0;
    final w = (p - deadlyFraction) / (1 - deadlyFraction);
    // ramp up faster toward the end
    return w * w;
  }

  bool get isLethal => extension > 0.05;

  @override
  bool collidesWithPoint(Vector2 point, double pointRadius) {
    if (!isLethal) return false;
    final dx = (point.x - position.x).abs() - halfExtents.x;
    final dy = (point.y - position.y).abs() - halfExtents.y;
    if (dx <= 0 && dy <= 0) return true;
    final cx = math.max(0.0, dx);
    final cy = math.max(0.0, dy);
    return cx * cx + cy * cy < pointRadius * pointRadius;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt * game.worldTimeScale;
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);

    // Ground rect — dark inked patch
    final base = Paint()..color = const Color(0xFF302418);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset.zero,
          width: halfExtents.x * 2,
          height: halfExtents.y * 2),
      base,
    );

    // Border — darker outline
    final border = Paint()
      ..color = const Color(0xFF1A1612)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset.zero,
          width: halfExtents.x * 2,
          height: halfExtents.y * 2),
      border,
    );

    // Warning red wash — ramps up before extension
    final w = warning;
    if (w > 0) {
      final warn = Paint()
        ..color = Color.fromRGBO(229, 57, 43, 0.32 * w);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero,
            width: halfExtents.x * 2,
            height: halfExtents.y * 2),
        warn,
      );
    }

    // Spikes — triangular ink shapes that grow during extension
    final ext = extension;
    if (ext > 0) {
      final spike = Paint()..color = const Color(0xFF1A1612);
      final spikeRim = Paint()
        ..color = const Color(0xFFEFE7D6).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      const spikeStep = 22.0;
      final cols = ((halfExtents.x * 2) / spikeStep).floor();
      final rows = ((halfExtents.y * 2) / spikeStep).floor();
      for (var i = 0; i < cols; i++) {
        for (var j = 0; j < rows; j++) {
          // stagger every other row
          final off = (j % 2) * (spikeStep / 2);
          final cx = -halfExtents.x + spikeStep * 0.5 + i * spikeStep + off;
          final cy = -halfExtents.y + spikeStep * 0.5 + j * spikeStep;
          if (cx.abs() > halfExtents.x - 4 || cy.abs() > halfExtents.y - 4) {
            continue;
          }
          final h = 16 * ext;
          final p = Path()
            ..moveTo(cx, cy - h * 0.5 - 2)
            ..lineTo(cx + 5, cy + h * 0.5 - 2)
            ..lineTo(cx - 5, cy + h * 0.5 - 2)
            ..close();
          canvas.drawPath(p, spike);
          if (ext > 0.6) {
            canvas.drawPath(p, spikeRim);
          }
        }
      }
    }
  }
}
