import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'editor_state.dart';

const double kWorldW = 1080;
const double kWorldH = 1920;

/// Center canvas — paper play field with grid + entities. Drag to move
/// selected, click to select/place.
class LevelCanvas extends StatefulWidget {
  const LevelCanvas({
    super.key,
    required this.doc,
    required this.placement,
  });

  final LevelDoc doc;
  final PlacementMode placement;

  @override
  State<LevelCanvas> createState() => _LevelCanvasState();
}

class _LevelCanvasState extends State<LevelCanvas> {
  EditorEntity? _dragging;
  Offset _hoverLocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.doc.addListener(_onDocChange);
    widget.placement.addListener(_onPlacementChange);
  }

  @override
  void didUpdateWidget(LevelCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc != widget.doc) {
      oldWidget.doc.removeListener(_onDocChange);
      widget.doc.addListener(_onDocChange);
    }
    if (oldWidget.placement != widget.placement) {
      oldWidget.placement.removeListener(_onPlacementChange);
      widget.placement.addListener(_onPlacementChange);
    }
  }

  @override
  void dispose() {
    widget.doc.removeListener(_onDocChange);
    widget.placement.removeListener(_onPlacementChange);
    super.dispose();
  }

  void _onDocChange() => setState(() {});
  void _onPlacementChange() => setState(() {});

  /// Returns the layout for the canvas: scale + offset to center the world
  /// rect inside the box.
  ({double scale, Offset offset}) _layout(Size box) {
    final scale = math.min(box.width / kWorldW, box.height / kWorldH);
    final ox = (box.width - kWorldW * scale) / 2;
    final oy = (box.height - kWorldH * scale) / 2;
    return (scale: scale, offset: Offset(ox, oy));
  }

  Offset _localToWorld(Offset local, Size box) {
    final l = _layout(box);
    return Offset(
      (local.dx - l.offset.dx) / l.scale,
      (local.dy - l.offset.dy) / l.scale,
    );
  }

  Offset _localToFrac(Offset local, Size box) {
    final w = _localToWorld(local, box);
    return Offset(w.dx / kWorldW, w.dy / kWorldH);
  }

  EditorEntity? _hitTestEntity(Offset world) {
    // Walk in reverse so topmost selected
    for (var i = widget.doc.entities.length - 1; i >= 0; i--) {
      final e = widget.doc.entities[i];
      final ex = e.x * kWorldW;
      final ey = e.y * kWorldH;
      final dx = world.dx - ex;
      final dy = world.dy - ey;
      final r = _entityHitRadius(e);
      if (dx * dx + dy * dy < r * r) return e;
    }
    return null;
  }

  double _entityHitRadius(EditorEntity e) {
    if (e.category == 'hazard' && (e.kind == 'wall' || e.kind == 'spikeField')) {
      // rough rect → radius
      final hw = (e.props['halfW'] as num).toDouble();
      final hh = (e.props['halfH'] as num).toDouble();
      return math.max(hw, hh);
    }
    return 56.0;
  }

  void _onTapDown(TapDownDetails d, Size box) {
    final localBox = box;
    final world = _localToWorld(d.localPosition, localBox);
    final frac = _localToFrac(d.localPosition, localBox);

    // Placement mode: drop a new entity
    if (widget.placement.active) {
      widget.doc.addEntity(
        category: widget.placement.category!,
        kind: widget.placement.kind!,
        x: frac.dx.clamp(0.04, 0.96),
        y: frac.dy.clamp(0.04, 0.96),
      );
      // Hold mode for chain-placing — clear with Esc / selection toggle.
      return;
    }

    final hit = _hitTestEntity(world);
    widget.doc.select(hit);
  }

  void _onPanStart(DragStartDetails d, Size box) {
    final world = _localToWorld(d.localPosition, box);
    final hit = _hitTestEntity(world);
    if (hit != null && !widget.placement.active) {
      widget.doc.select(hit);
      _dragging = hit;
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Size box) {
    final dragging = _dragging;
    if (dragging == null) return;
    final frac = _localToFrac(d.localPosition, box);
    dragging.x = frac.dx.clamp(0.04, 0.96);
    dragging.y = frac.dy.clamp(0.04, 0.96);
    widget.doc.bump();
  }

  void _onPanEnd(DragEndDetails d) {
    _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final box = Size(constraints.maxWidth, constraints.maxHeight);
      return MouseRegion(
        cursor: widget.placement.active
            ? SystemMouseCursors.precise
            : SystemMouseCursors.basic,
        onHover: (e) {
          setState(() {
            _hoverLocal = e.localPosition;
          });
        },
        child: GestureDetector(
          onTapDown: (d) => _onTapDown(d, box),
          onPanStart: (d) => _onPanStart(d, box),
          onPanUpdate: (d) => _onPanUpdate(d, box),
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            size: box,
            painter: _LevelPainter(
              doc: widget.doc,
              placement: widget.placement,
              hoverLocal: _hoverLocal,
              layout: _layout(box),
            ),
          ),
        ),
      );
    });
  }
}

class _LevelPainter extends CustomPainter {
  _LevelPainter({
    required this.doc,
    required this.placement,
    required this.hoverLocal,
    required this.layout,
  });

  final LevelDoc doc;
  final PlacementMode placement;
  final Offset hoverLocal;
  final ({double scale, Offset offset}) layout;

  @override
  void paint(Canvas canvas, Size size) {
    // Backdrop fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1A1612),
    );

    canvas.save();
    canvas.translate(layout.offset.dx, layout.offset.dy);
    canvas.scale(layout.scale, layout.scale);

    // Paper rect
    final paper = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF3ECDB), Color(0xFFE7DEC8)],
      ).createShader(const Rect.fromLTWH(0, 0, kWorldW, kWorldH));
    canvas.drawRect(const Rect.fromLTWH(0, 0, kWorldW, kWorldH), paper);

    // Spawn marker (samurai start)
    _drawSpawnMarker(canvas);
    // Torii marker (gate)
    _drawToriiMarker(canvas);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final x = kWorldW * (i / 10);
      canvas.drawLine(Offset(x, 0), Offset(x, kWorldH), gridPaint);
    }
    for (var i = 1; i < 10; i++) {
      final y = kWorldH * (i / 10);
      canvas.drawLine(Offset(0, y), Offset(kWorldW, y), gridPaint);
    }

    // Edge inset (where path-drawing is clamped)
    final inset = Paint()
      ..color = const Color(0x33A72920)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      const Rect.fromLTWH(36, 36, kWorldW - 72, kWorldH - 72),
      inset,
    );

    // Entities
    for (final e in doc.entities) {
      _drawEntity(canvas, e, e == doc.selected);
    }

    // Placement preview at hover
    if (placement.active) {
      final worldHover = Offset(
        (hoverLocal.dx - layout.offset.dx) / layout.scale,
        (hoverLocal.dy - layout.offset.dy) / layout.scale,
      );
      _drawPlacementPreview(canvas, worldHover);
    }

    canvas.restore();
  }

  void _drawSpawnMarker(Canvas canvas) {
    const sx = kWorldW * 0.5;
    const sy = kWorldH * 0.84;
    final ring = Paint()
      ..color = const Color(0x66A72920)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(sx, sy), 50, ring);
    final inner = Paint()..color = const Color(0xCC1A1612);
    canvas.drawCircle(const Offset(sx, sy), 12, inner);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'spawn',
        style: TextStyle(
          color: Color(0x991A1612),
          fontSize: 14,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(sx - 25, sy + 18));
  }

  void _drawToriiMarker(Canvas canvas) {
    const tx = kWorldW * 0.5;
    const ty = kWorldH * 0.14;
    final post = Paint()..color = const Color(0xCCA72920);
    canvas.drawRect(Rect.fromLTWH(tx - 70, ty - 60, 14, 120), post);
    canvas.drawRect(Rect.fromLTWH(tx + 56, ty - 60, 14, 120), post);
    canvas.drawRect(Rect.fromLTWH(tx - 84, ty - 60, 168, 14), post);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'gate',
        style: TextStyle(
          color: Color(0x991A1612),
          fontSize: 14,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(tx - 18, ty + 70));
  }

  void _drawEntity(Canvas canvas, EditorEntity e, bool selected) {
    final wx = e.x * kWorldW;
    final wy = e.y * kWorldH;
    canvas.save();
    canvas.translate(wx, wy);

    if (selected) {
      final halo = Paint()
        ..color = const Color(0x55F5A050)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset.zero, 60, halo);
      final ring = Paint()
        ..color = const Color(0xFFF5A050)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset.zero, 56, ring);
    }

    switch (e.category) {
      case 'demon':
        _drawDemonIcon(canvas, e);
        break;
      case 'hazard':
        _drawHazardIcon(canvas, e);
        break;
      case 'item':
        _drawItemIcon(canvas, e);
        break;
    }

    canvas.restore();

    // Patrol/orbital paths drawn after the icon so they overlay clearly.
    canvas.save();
    if (e.category == 'demon' && e.kind == 'patrol') {
      final ex = (e.props['endX'] as num).toDouble() * kWorldW;
      final ey = (e.props['endY'] as num).toDouble() * kWorldH;
      _drawDashedLine(canvas, Offset(wx, wy), Offset(ex, ey),
          const Color(0x66A72920));
      canvas.drawCircle(Offset(ex, ey), 8,
          Paint()..color = const Color(0x99A72920));
    }
    if (e.category == 'hazard' && e.kind == 'wispPatrol') {
      final ex = (e.props['endX'] as num).toDouble() * kWorldW;
      final ey = (e.props['endY'] as num).toDouble() * kWorldH;
      _drawDashedLine(canvas, Offset(wx, wy), Offset(ex, ey),
          const Color(0x6682D8C8));
      canvas.drawCircle(Offset(ex, ey), 8,
          Paint()..color = const Color(0x9982D8C8));
    }
    if (e.category == 'demon' && e.kind == 'orbital') {
      final cx = (e.props['centerX'] as num).toDouble() * kWorldW;
      final cy = (e.props['centerY'] as num).toDouble() * kWorldH;
      final r = (e.props['radius'] as num).toDouble();
      final orbit = Paint()
        ..color = const Color(0x661A1612)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), r, orbit);
      canvas.drawCircle(Offset(cx, cy), 5,
          Paint()..color = const Color(0xCC1A1612));
    }
    canvas.restore();
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color c) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final delta = b - a;
    final len = delta.distance;
    final n = (len / 16).floor();
    for (var i = 0; i < n; i += 2) {
      final t1 = i / n;
      final t2 = (i + 1) / n;
      canvas.drawLine(a + delta * t1, a + delta * t2, paint);
    }
  }

  void _drawDemonIcon(Canvas canvas, EditorEntity e) {
    final body = Paint()..color = const Color(0xFF1A1612);
    canvas.drawCircle(Offset.zero, 36, body);

    if (e.kind == 'turret') {
      final barrel = Paint()..color = const Color(0xFF1A1612);
      canvas.drawRect(const Rect.fromLTWH(36 - 2, -7, 30, 14), barrel);
    }

    // Red eyes
    final eye = Paint()..color = const Color(0xFFE5392B);
    canvas.drawCircle(const Offset(-8, -5), 3.4, eye);
    canvas.drawCircle(const Offset(8, -5), 3.4, eye);

    // Required number badge
    final req = (e.props['requiredNumber'] as num?)?.toInt() ?? 0;
    if (req > 0) {
      final disc = Paint()..color = const Color(0xCCE5392B);
      canvas.drawCircle(const Offset(0, -8), 22, disc);
      final tp = TextPainter(
        text: TextSpan(
          text: '$req',
          style: const TextStyle(
            color: Color(0xFFEFE7D6),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -8 - tp.height / 2));
    }

    // Kind label
    final lbl = TextPainter(
      text: TextSpan(
        text: e.kind,
        style: const TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 13,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lbl.paint(canvas, Offset(-lbl.width / 2, 42));
  }

  void _drawHazardIcon(Canvas canvas, EditorEntity e) {
    if (e.kind == 'wall' || e.kind == 'spikeField') {
      final hw = (e.props['halfW'] as num).toDouble();
      final hh = (e.props['halfH'] as num).toDouble();
      final body = Paint()
        ..color = e.kind == 'wall'
            ? const Color(0xFF302418)
            : const Color(0xCC5A2A1A);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: hw * 2, height: hh * 2),
        body,
      );
      final border = Paint()
        ..color = e.kind == 'wall'
            ? const Color(0xFF1A1612)
            : const Color(0xFFE5392B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: hw * 2, height: hh * 2),
        border,
      );
      if (e.kind == 'spikeField') {
        // Spike indicator
        final sp = Paint()..color = const Color(0xFF1A1612);
        for (var i = -2; i <= 2; i++) {
          final cx = i * 18.0;
          final p = Path()
            ..moveTo(cx, hh - 4)
            ..lineTo(cx + 4, -hh + 4)
            ..lineTo(cx - 4, -hh + 4)
            ..close();
          canvas.drawPath(p, sp);
        }
      }
    } else {
      // Wisp circle
      final glow = Paint()
        ..color = const Color(0x6682D8C8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset.zero, 30, glow);
      final body = Paint()..color = const Color(0xFF82D8C8);
      canvas.drawCircle(Offset.zero, 18, body);
      final core = Paint()..color = const Color(0xFFEFE7D6);
      canvas.drawCircle(Offset.zero, 7, core);
    }

    final lbl = TextPainter(
      text: TextSpan(
        text: e.kind,
        style: const TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 13,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lbl.paint(canvas, Offset(-lbl.width / 2, 50));
  }

  void _drawItemIcon(Canvas canvas, EditorEntity e) {
    Color c;
    String letter;
    switch (e.kind) {
      case 'dragon':
        c = const Color(0xFFD45438);
        letter = 'D';
        break;
      case 'slow':
        c = const Color(0xFF5BA8C8);
        letter = 'S';
        break;
      case 'ghost':
      default:
        c = const Color(0xFFA48ABE);
        letter = 'G';
        break;
    }
    final glow = Paint()
      ..color = c.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset.zero, 30, glow);
    final disc = Paint()..color = c;
    canvas.drawCircle(Offset.zero, 22, disc);
    final inner = Paint()..color = const Color(0xCCEFE7D6);
    canvas.drawCircle(Offset.zero, 16, inner);
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: c,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

    final lbl = TextPainter(
      text: TextSpan(
        text: e.kind,
        style: const TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 13,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lbl.paint(canvas, Offset(-lbl.width / 2, 42));
  }

  void _drawPlacementPreview(Canvas canvas, Offset world) {
    final paint = Paint()
      ..color = const Color(0x80F5A050)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(world, 40, paint);
    final cross = Paint()
      ..color = const Color(0xCCF5A050)
      ..strokeWidth = 1.5;
    canvas.drawLine(world.translate(-12, 0), world.translate(12, 0), cross);
    canvas.drawLine(world.translate(0, -12), world.translate(0, 12), cross);
  }

  @override
  bool shouldRepaint(covariant _LevelPainter oldDelegate) =>
      oldDelegate.doc != doc ||
      oldDelegate.placement != placement ||
      oldDelegate.hoverLocal != hoverLocal ||
      oldDelegate.layout != layout;
}
