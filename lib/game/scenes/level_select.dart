import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';
import '../levels.dart';
import '../runs/endless_run.dart';
import '../runs/speedrun_run.dart';

/// Overlay shown over the world while in menu scene. Has a title, a grid of
/// level tiles, and listens for tile taps to start play.
class LevelSelect extends Component
    with HasGameReference<FlamekutGame> {
  LevelSelect() : super(priority: 1500);

  final List<LevelTile> _tiles = [];
  late final Component _title;
  late final Component _backdrop;
  double _appearT = 0;
  int _page = 0;
  static const int _perPage = 12; // 3 cols × 4 rows
  late int _pageCount;
  late _PageNav _pageNav;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _backdrop = _Backdrop();
    add(_backdrop);

    _title = _Title();
    add(_title);

    // Top-right utility bar — home / help / settings.
    add(_UtilityIcon(
      kind: 'home',
      position: Vector2(FlamekutGame.worldW - 80, 80),
    ));
    add(_UtilityIcon(
      kind: 'help',
      position: Vector2(FlamekutGame.worldW - 80 - 78, 80),
    ));
    add(_UtilityIcon(
      kind: 'settings',
      position: Vector2(FlamekutGame.worldW - 80 - 78 * 2, 80),
    ));

    // "modes" section header
    add(_SectionLabel(
      text: 'modes',
      position: Vector2(FlamekutGame.worldW / 2, FlamekutGame.worldH * 0.205),
    ));

    // Mode bar — bigger tiles, clearly button-shaped.
    final modes = <_ModeSpec>[
      _ModeSpec(label: 'forms', kind: 'kits', icon: '形'),
      _ModeSpec(label: 'endless', kind: 'endless', icon: '∞'),
      _ModeSpec(label: 'sprint', kind: 'sr_short', icon: '5'),
      _ModeSpec(label: 'mid', kind: 'sr_medium', icon: '10'),
      _ModeSpec(label: 'marathon', kind: 'sr_long', icon: '15'),
    ];
    const modeW = 188.0;
    const modeH = 88.0;
    const modeGap = 14.0;
    final modeBarW = modes.length * modeW + (modes.length - 1) * modeGap;
    final modeStartX =
        FlamekutGame.worldW / 2 - modeBarW / 2 + modeW / 2;
    final modeY = FlamekutGame.worldH * 0.255;
    for (var i = 0; i < modes.length; i++) {
      final m = modes[i];
      add(ModeTile(
        spec: m,
        size: Vector2(modeW, modeH),
        spawnPosition: Vector2(modeStartX + i * (modeW + modeGap), modeY),
      ));
    }

    // "levels" section header above the grid
    add(_SectionLabel(
      text: 'levels',
      position: Vector2(FlamekutGame.worldW / 2, FlamekutGame.worldH * 0.325),
    ));

    final levels = game.allLevels;
    _pageCount = math.max(1, (levels.length / _perPage).ceil());

    // Pagination nav (only mounted if multiple pages exist)
    _pageNav = _PageNav(
      provider: () => (_page, _pageCount),
      onPrev: () {
        if (_page > 0) {
          _page--;
          _rebuildPage();
        }
      },
      onNext: () {
        if (_page < _pageCount - 1) {
          _page++;
          _rebuildPage();
        }
      },
    );
    add(_pageNav);

    _rebuildPage();
  }

  void _rebuildPage() {
    // Tear down existing tiles
    for (final t in _tiles) {
      t.removeFromParent();
    }
    _tiles.clear();

    final levels = game.allLevels;
    const cols = 3;
    const tileW = 220.0;
    const tileH = 220.0;
    const gapX = 38.0;
    const gapY = 38.0;
    final gridW = cols * tileW + (cols - 1) * gapX;
    final startX = FlamekutGame.worldW / 2 - gridW / 2 + tileW / 2;
    final startY = FlamekutGame.worldH * 0.36;

    final firstIdx = _page * _perPage;
    final lastIdx = math.min(firstIdx + _perPage, levels.length);
    for (var i = firstIdx; i < lastIdx; i++) {
      final pageRel = i - firstIdx;
      final col = pageRel % cols;
      final row = pageRel ~/ cols;
      final x = startX + col * (tileW + gapX);
      final y = startY + row * (tileH + gapY);
      final tile = LevelTile(
        index: i,
        level: levels[i],
        size: Vector2(tileW, tileH),
        spawnPosition: Vector2(x, y),
      );
      _tiles.add(tile);
      add(tile);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _appearT = math.min(_appearT + dt * 1.6, 1.0);
  }

  double get appearAlpha => _easeOutCubic(_appearT);
}

double _easeOutCubic(double t) {
  final p = 1 - t;
  return 1 - p * p * p;
}

class _Backdrop extends Component
    with HasGameReference<FlamekutGame> {
  _Backdrop() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    final scene = parent as LevelSelect;
    final a = scene.appearAlpha;
    final paint = Paint()
      ..color = Color.fromRGBO(239, 231, 214, 0.85 * a);
    canvas.drawRect(
      const Rect.fromLTWH(
          0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      paint,
    );
  }
}

class _Title extends Component {
  _Title() : super(priority: 10);

  @override
  void render(Canvas canvas) {
    // Big title kanji-style brushstroke
    final tp = TextPainter(
      text: const TextSpan(
        text: 'F L A M E K U T',
        style: TextStyle(
          color: Color(0xEE1A1612),
          fontSize: 96,
          fontWeight: FontWeight.w300,
          letterSpacing: 18,
          shadows: [
            Shadow(color: Color(0x33A72920), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tp.width / 2,
        FlamekutGame.worldH * 0.10,
      ),
    );

    // Subtitle
    final sub = TextPainter(
      text: const TextSpan(
        text: 'choose a path',
        style: TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 30,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - sub.width / 2,
        FlamekutGame.worldH * 0.10 + 110,
      ),
    );
  }
}

class _ModeSpec {
  const _ModeSpec({
    required this.label,
    required this.kind,
    required this.icon,
  });
  final String label;
  final String kind; // 'kits' | 'endless' | 'sr_short' | 'sr_medium' | 'sr_long'
  final String icon;
}

/// Bottom-of-screen pagination nav: ← n / m →
class _PageNav extends Component
    with HasGameReference<FlamekutGame> {
  _PageNav({
    required this.provider,
    required this.onPrev,
    required this.onNext,
  }) : super(priority: 5) {
    _prev = _ArrowBtn(
      label: '←',
      onTap: onPrev,
      position: Vector2(FlamekutGame.worldW * 0.30, FlamekutGame.worldH * 0.93),
    );
    _next = _ArrowBtn(
      label: '→',
      onTap: onNext,
      position: Vector2(FlamekutGame.worldW * 0.70, FlamekutGame.worldH * 0.93),
    );
  }

  final (int, int) Function() provider;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  late final _ArrowBtn _prev;
  late final _ArrowBtn _next;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_prev);
    add(_next);
  }

  @override
  void render(Canvas canvas) {
    final (page, count) = provider();
    if (count <= 1) return;
    final tp = TextPainter(
      text: TextSpan(
        text: '${page + 1} · $count',
        style: const TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 22,
          fontWeight: FontWeight.w400,
          letterSpacing: 6,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tp.width / 2,
        FlamekutGame.worldH * 0.93 - tp.height / 2,
      ),
    );
  }
}

class _ArrowBtn extends PositionComponent with TapCallbacks {
  _ArrowBtn({
    required this.label,
    required this.onTap,
    required Vector2 position,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(72),
          priority: 1,
        );

  final String label;
  final VoidCallback onTap;

  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - size.x / 2;
    final dy = point.y - size.y / 2;
    return dx * dx + dy * dy < 32 * 32;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    onTap();
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final bg = Paint()..color = const Color.fromRGBO(40, 30, 24, 0.55);
    canvas.drawCircle(Offset.zero, 30, bg);
    final rim = Paint()
      ..color = const Color.fromRGBO(167, 41, 32, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, 30, rim);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFEDE2CE),
          fontSize: 28,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(-tp.width / 2, -tp.height / 2),
    );
  }
}

class _SectionLabel extends Component {
  _SectionLabel({required this.text, required this.position}) : super(priority: 1);
  final String text;
  final Vector2 position;

  @override
  void render(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xCCB8A78A),
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: 8,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(position.x - tp.width / 2, position.y));

    // Decorative ink lines flanking the label
    final line = Paint()
      ..color = const Color.fromRGBO(167, 41, 32, 0.45)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    final ly = position.y + 12;
    canvas.drawLine(
      Offset(position.x - tp.width / 2 - 80, ly),
      Offset(position.x - tp.width / 2 - 16, ly),
      line,
    );
    canvas.drawLine(
      Offset(position.x + tp.width / 2 + 16, ly),
      Offset(position.x + tp.width / 2 + 80, ly),
      line,
    );
  }
}

class _UtilityIcon extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _UtilityIcon({required this.kind, required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(64),
          priority: 10,
        );

  final String kind; // 'home' | 'help' | 'settings'

  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - size.x / 2;
    final dy = point.y - size.y / 2;
    return dx * dx + dy * dy < 30 * 30;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    switch (kind) {
      case 'home':
        unawaited(game.enterTitleScreen());
        break;
      case 'help':
        unawaited(game.openHowToPlay());
        break;
      case 'settings':
        unawaited(game.openSettings());
        break;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final bg = Paint()..color = const Color.fromRGBO(40, 30, 24, 0.55);
    canvas.drawCircle(Offset.zero, 28, bg);
    final rim = Paint()
      ..color = const Color.fromRGBO(167, 41, 32, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, 28, rim);

    final glyph = switch (kind) {
      'home' => '⌂',
      'help' => '?',
      'settings' => '⚙',
      _ => '·',
    };
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: const TextStyle(
          color: Color(0xFFEDE2CE),
          fontSize: 30,
          fontWeight: FontWeight.w300,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(-tp.width / 2, -tp.height / 2),
    );
  }
}

class ModeTile extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  ModeTile({
    required this.spec,
    required Vector2 size,
    required Vector2 spawnPosition,
  }) : super(
          position: spawnPosition,
          size: size,
          anchor: Anchor.center,
          priority: 5,
        );

  final _ModeSpec spec;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    switch (spec.kind) {
      case 'kits':
        unawaited(game.openKitSelect());
        break;
      case 'endless':
        final seed = DateTime.now().millisecondsSinceEpoch;
        unawaited(game.startRun(EndlessRun(seed: seed)));
        break;
      case 'sr_short':
        _launchSpeedrun('short');
        break;
      case 'sr_medium':
        _launchSpeedrun('medium');
        break;
      case 'sr_long':
        _launchSpeedrun('long');
        break;
    }
  }

  Future<void> _launchSpeedrun(String setId) async {
    final s = kSpeedrunSets[setId]!;
    final run = SpeedrunRun(set: s);
    await run.preload();
    await game.startRun(run);
  }

  String _runId() {
    switch (spec.kind) {
      case 'endless':
        return 'endless';
      case 'sr_short':
        return 'speedrun_short';
      case 'sr_medium':
        return 'speedrun_medium';
      case 'sr_long':
        return 'speedrun_long';
    }
    return spec.kind;
  }

  String _fmtTime(double s) {
    if (!s.isFinite) return '—';
    final m = (s ~/ 60);
    final r = s - m * 60;
    if (m > 0) return '${m}m ${r.toStringAsFixed(2)}s';
    return '${s.toStringAsFixed(2)}s';
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final bg = Paint()..color = const Color.fromRGBO(40, 30, 24, 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      bg,
    );
    // subtle gradient for raised look
    final hi = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x33EDE2CE),
          Color(0x00000000),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      hi,
    );
    final border = Paint()
      ..color = const Color.fromRGBO(167, 41, 32, 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      border,
    );

    // Icon (left)
    final iconTp = TextPainter(
      text: TextSpan(
        text: spec.icon,
        style: const TextStyle(
          color: Color(0xFFA72920),
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconTp.paint(
      canvas,
      Offset(-size.x / 2 + 18, -iconTp.height / 2),
    );

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: spec.label,
        style: const TextStyle(
          color: Color(0xFFEFE7D6),
          fontSize: 24,
          fontWeight: FontWeight.w500,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(-size.x / 2 + 64, -size.y / 2 + 14),
    );

    // Best time / levels readout below the label
    final rec = game.runRecords.get(_runId());
    if (rec.bestLevels > 0) {
      final s = rec.bestTimeSec.isFinite
          ? '${rec.bestLevels} · ${_fmtTime(rec.bestTimeSec)}'
          : '${rec.bestLevels} cleared';
      final small = TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(
            color: Color(0xCCB8A78A),
            fontSize: 13,
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      small.paint(canvas, Offset(-size.x / 2 + 64, size.y / 2 - small.height - 14));
    }
  }
}

class LevelTile extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  LevelTile({
    required this.index,
    required this.level,
    required Vector2 size,
    required Vector2 spawnPosition,
  }) : super(
          position: spawnPosition,
          size: size,
          anchor: Anchor.center,
          priority: 5,
        );

  final int index;
  final LevelData level;

  bool get _unlocked =>
      game.statsStore.isUnlocked(game.allLevels.map((l) => l.id).toList(), index);

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!_unlocked) return;
    game.startLevel(index);
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final unlocked = _unlocked;
    final record = game.statsStore.recordFor(level.id);

    // Card background
    final bgA = unlocked ? 1.0 : 0.4;
    final bg = Paint()
      ..color = Color.fromRGBO(243, 236, 219, bgA);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      const Radius.circular(18),
    );
    canvas.drawRRect(rrect, bg);

    // Border (deeper for completed)
    final border = Paint()
      ..color = record.completed
          ? Color.fromRGBO(167, 41, 32, 0.8 * bgA)
          : Color.fromRGBO(40, 30, 24, 0.6 * bgA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = record.completed ? 3.5 : 2.0;
    canvas.drawRRect(rrect, border);

    // Corner ink dabs for character
    final dab = Paint()..color = Color.fromRGBO(40, 30, 24, 0.5 * bgA);
    canvas.drawCircle(
        Offset(-size.x / 2 + 14, -size.y / 2 + 14), 5, dab);
    canvas.drawCircle(
        Offset(size.x / 2 - 14, -size.y / 2 + 14), 4, dab);

    // Big level number
    final numTp = TextPainter(
      text: TextSpan(
        text: '${index + 1}',
        style: TextStyle(
          color: Color.fromRGBO(40, 30, 24, 0.92 * bgA),
          fontSize: 88,
          fontWeight: FontWeight.w300,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    numTp.paint(
      canvas,
      Offset(-numTp.width / 2, -size.y / 2 + 18),
    );

    // Name
    final nameTp = TextPainter(
      text: TextSpan(
        text: level.name,
        style: TextStyle(
          color: Color.fromRGBO(40, 30, 24, 0.85 * bgA),
          fontSize: 22,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x - 24);
    nameTp.paint(
      canvas,
      Offset(-nameTp.width / 2, 8),
    );

    // Best time
    if (record.completed && record.bestTime.isFinite) {
      final timeTp = TextPainter(
        text: TextSpan(
          text: '${record.bestTime.toStringAsFixed(2)}s',
          style: const TextStyle(
            color: Color(0xCC1A1612),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      timeTp.paint(canvas, Offset(-timeTp.width / 2, 38));
    }

    // Stars
    _drawStars(canvas, record.stars, bgA);

    // Lock icon if locked
    if (!unlocked) {
      final lock = Paint()
        ..color = Color.fromRGBO(40, 30, 24, 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, -8), width: 30, height: 36),
        -math.pi,
        math.pi,
        false,
        lock,
      );
      canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, 14), width: 36, height: 28),
        Paint()..color = Color.fromRGBO(40, 30, 24, 0.85),
      );
    }
  }

  void _drawStars(Canvas canvas, int filled, double alphaScale) {
    const total = 3;
    const gap = 28.0;
    final yOff = size.y / 2 - 30;
    for (var i = 0; i < total; i++) {
      final x = (i - 1) * gap;
      _drawStar(
        canvas,
        Offset(x, yOff),
        12,
        i < filled,
        alphaScale,
      );
    }
  }

  void _drawStar(
      Canvas canvas, Offset center, double r, bool filled, double alphaScale) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    if (filled) {
      final fill = Paint()
        ..color = Color.fromRGBO(220, 88, 60, 0.95 * alphaScale);
      canvas.drawPath(path, fill);
      final glow = Paint()
        ..color = Color.fromRGBO(245, 168, 96, 0.55 * alphaScale)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, r + 2, glow);
    } else {
      final outline = Paint()
        ..color = Color.fromRGBO(40, 30, 24, 0.45 * alphaScale)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawPath(path, outline);
    }
  }
}
