import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// Accessible from the title — and shown automatically on first launch.
/// A few brushstroke pages explaining the rules.
class HowToPlay extends Component
    with HasGameReference<FlamekutGame> {
  HowToPlay() : super(priority: 1700);

  int _page = 0;
  late _Backdrop _backdrop;

  static const _pages = <_Page>[
    _Page(
      title: 'draw your path',
      lines: [
        'drag from the samurai',
        'to lay an ink trail',
        'tap the gate to begin the run',
      ],
    ),
    _Page(
      title: 'cuts make number',
      lines: [
        'each demon you slay raises your number',
        'numbered demons need that many cuts',
        'before they can be passed',
      ],
    ),
    _Page(
      title: 'avoid · do not slay',
      lines: [
        'cyan flames and stones are hazards',
        'one touch ends the run',
        'plan around them',
      ],
    ),
    _Page(
      title: 'three power-ups',
      lines: [
        'red — invulnerable for a moment',
        'cyan — slow the world',
        'purple — pass through walls',
      ],
    ),
    _Page(
      title: 'the gate is the end',
      lines: [
        'reach it with all demons slain',
        'earn stars by clearing fast',
        'one day · the gate may open',
      ],
    ),
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _backdrop = _Backdrop(onTap: _next);
    add(_backdrop);
    add(_PageBody(pageProvider: () => _pages[_page]));
    add(_PageDots(provider: () => (_page, _pages.length)));
    add(_CloseHint());
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      _dismiss();
    } else {
      _page++;
    }
  }

  void _dismiss() {
    removeFromParent();
    game.afterHowToPlay();
  }
}

class _Page {
  const _Page({required this.title, required this.lines});
  final String title;
  final List<String> lines;
}

class _Backdrop extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _Backdrop({required this.onTap})
      : super(
          size: Vector2(FlamekutGame.worldW, FlamekutGame.worldH),
          priority: -10,
        );

  final VoidCallback onTap;

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= size.x &&
      point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    onTap();
  }

  @override
  void render(Canvas canvas) {
    final dim = Paint()
      ..color = const Color.fromRGBO(20, 17, 14, 0.78);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      dim,
    );
    final rect = Rect.fromLTWH(
      FlamekutGame.worldW * 0.10,
      FlamekutGame.worldH * 0.16,
      FlamekutGame.worldW * 0.80,
      FlamekutGame.worldH * 0.72,
    );
    final paper = Paint()
      ..color = const Color.fromRGBO(243, 236, 219, 0.96);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      paper,
    );
    final border = Paint()
      ..color = const Color.fromRGBO(40, 30, 24, 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      border,
    );
  }
}

class _PageBody extends Component {
  _PageBody({required this.pageProvider}) : super(priority: 0);
  final _Page Function() pageProvider;
  double _t = 0;
  _Page? _shown;

  @override
  void update(double dt) {
    super.update(dt);
    final next = pageProvider();
    if (!identical(next, _shown)) {
      _shown = next;
      _t = 0;
    }
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final p = _shown ?? pageProvider();
    final fade = (_t / 0.35).clamp(0.0, 1.0);

    // Title
    final tp = TextPainter(
      text: TextSpan(
        text: p.title,
        style: TextStyle(
          color: Color.fromRGBO(26, 22, 18, 0.95 * fade),
          fontSize: 56,
          fontWeight: FontWeight.w300,
          letterSpacing: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tp.width / 2,
        FlamekutGame.worldH * 0.24,
      ),
    );

    // Brushstroke under title
    final line = Paint()
      ..color = Color.fromRGBO(167, 41, 32, 0.8 * fade)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final lp = Path()
      ..moveTo(FlamekutGame.worldW * 0.30, FlamekutGame.worldH * 0.30)
      ..quadraticBezierTo(
        FlamekutGame.worldW * 0.50,
        FlamekutGame.worldH * 0.30 + 6,
        FlamekutGame.worldW * 0.70,
        FlamekutGame.worldH * 0.30,
      );
    canvas.drawPath(lp, line);

    // Lines
    const lineSpacing = 76.0;
    final firstY = FlamekutGame.worldH * 0.42;
    for (var i = 0; i < p.lines.length; i++) {
      final lineDelay = 0.10 + i * 0.10;
      final lineFade = ((_t - lineDelay) / 0.45).clamp(0.0, 1.0);
      final body = TextPainter(
        text: TextSpan(
          text: p.lines[i],
          style: TextStyle(
            color: Color.fromRGBO(26, 22, 18, 0.85 * lineFade),
            fontSize: 34,
            fontWeight: FontWeight.w400,
            letterSpacing: 3,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      body.paint(
        canvas,
        Offset(
          FlamekutGame.worldW / 2 - body.width / 2,
          firstY + i * lineSpacing,
        ),
      );
    }
  }
}

class _PageDots extends Component {
  _PageDots({required this.provider}) : super(priority: 0);
  final (int, int) Function() provider;

  @override
  void render(Canvas canvas) {
    final (i, n) = provider();
    const gap = 24.0;
    final totalW = (n - 1) * gap;
    final startX = FlamekutGame.worldW / 2 - totalW / 2;
    final y = FlamekutGame.worldH * 0.78;
    for (var k = 0; k < n; k++) {
      final filled = k == i;
      final paint = Paint()
        ..color = filled
            ? const Color(0xFFA72920)
            : const Color.fromRGBO(40, 30, 24, 0.30);
      canvas.drawCircle(Offset(startX + k * gap, y), filled ? 6 : 4, paint);
    }
  }
}

class _CloseHint extends Component {
  _CloseHint() : super(priority: 0);
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final pulse = math.sin(_t * 2.2) * 0.5 + 0.5;
    final tp = TextPainter(
      text: TextSpan(
        text: 'tap to advance · last page closes',
        style: TextStyle(
          color: Color.fromRGBO(26, 22, 18, 0.30 + 0.30 * pulse),
          fontSize: 20,
          fontWeight: FontWeight.w400,
          letterSpacing: 3,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tp.width / 2,
        FlamekutGame.worldH * 0.84,
      ),
    );
  }
}
