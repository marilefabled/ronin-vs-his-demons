import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// Sumi-e paper page with credits + tech stack + brief design pitch.
/// Opens from the title-screen toolbar.
class CreditsScreen extends Component
    with HasGameReference<FlamekutGame> {
  CreditsScreen() : super(priority: 1700);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_Backdrop());
    add(_Panel());
    add(_Close(
      position: Vector2(FlamekutGame.worldW * 0.5, FlamekutGame.worldH * 0.92),
    ));
  }
}

class _Backdrop extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _Backdrop()
      : super(
          size: Vector2(FlamekutGame.worldW, FlamekutGame.worldH),
          priority: -10,
        );

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    // Tap outside the panel closes.
    final px = event.localPosition.x;
    final py = event.localPosition.y;
    final pl = FlamekutGame.worldW * 0.08;
    final pr = FlamekutGame.worldW * 0.92;
    final pt = FlamekutGame.worldH * 0.10;
    final pb = FlamekutGame.worldH * 0.88;
    if (px < pl || px > pr || py < pt || py > pb) {
      game.closeCredits();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      Paint()..color = const Color.fromRGBO(20, 17, 14, 0.80),
    );
  }
}

class _Panel extends Component {
  _Panel() : super(priority: 0);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(
      FlamekutGame.worldW * 0.08,
      FlamekutGame.worldH * 0.10,
      FlamekutGame.worldW * 0.84,
      FlamekutGame.worldH * 0.78,
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

    // Title
    _paint(
      canvas,
      'ronin vs his demons',
      const TextStyle(
        color: Color(0xEE1A1612),
        fontSize: 56,
        fontWeight: FontWeight.w200,
        letterSpacing: 10,
      ),
      y: FlamekutGame.worldH * 0.135,
    );

    // Tagline
    _paint(
      canvas,
      'the weight of every blade',
      const TextStyle(
        color: Color(0xCCA72920),
        fontSize: 24,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        letterSpacing: 6,
      ),
      y: FlamekutGame.worldH * 0.135 + 78,
    );

    // Decorative ink rule
    final line = Paint()
      ..color = const Color.fromRGBO(167, 41, 32, 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final lp = Path()
      ..moveTo(FlamekutGame.worldW * 0.30, FlamekutGame.worldH * 0.235)
      ..quadraticBezierTo(
        FlamekutGame.worldW * 0.50,
        FlamekutGame.worldH * 0.235 + 6,
        FlamekutGame.worldW * 0.70,
        FlamekutGame.worldH * 0.235,
      );
    canvas.drawPath(lp, line);

    // Sections — design pitch, tech stack, credits
    const sectionGap = 36.0;
    var y = FlamekutGame.worldH * 0.27;

    y = _sectionHeader(canvas, 'the design', y) + 14;
    y = _body(canvas,
        'A ronin in purgatory.\nDraw the path. Slay the demons. Earn the gate.\nUntil you can let it all go.', y) + sectionGap;

    y = _sectionHeader(canvas, 'made with', y) + 14;
    y = _body(canvas,
        'Flutter · Flame · GLSL fragment shaders\nbuilt from a 2022 Construct 3 prototype', y) + sectionGap;

    y = _sectionHeader(canvas, 'voice', y) + 14;
    y = _body(canvas, 'Akira (recorded during covid, 2020)', y) + sectionGap;

    y = _sectionHeader(canvas, 'music', y) + 14;
    y = _body(canvas, 'yoitrax · the loyalist · lament', y) + sectionGap;

    y = _sectionHeader(canvas, 'design + code', y) + 14;
    y = _body(canvas, 'Omar · with Claude', y);
  }

  void _paint(Canvas canvas, String text, TextStyle style, {required double y}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(FlamekutGame.worldW / 2 - tp.width / 2, y));
  }

  double _sectionHeader(Canvas canvas, String text, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xCC8A5A50),
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 6,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(FlamekutGame.worldW / 2 - tp.width / 2, y));

    // Tiny dot decoration
    final dot = Paint()..color = const Color.fromRGBO(167, 41, 32, 0.65);
    canvas.drawCircle(
      Offset(FlamekutGame.worldW / 2 - tp.width / 2 - 16, y + tp.height / 2),
      2.5,
      dot,
    );
    canvas.drawCircle(
      Offset(FlamekutGame.worldW / 2 + tp.width / 2 + 16, y + tp.height / 2),
      2.5,
      dot,
    );

    return y + tp.height;
  }

  double _body(Canvas canvas, String text, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xEE1A1612),
          fontSize: 24,
          fontWeight: FontWeight.w400,
          letterSpacing: 3,
          height: 1.45,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: FlamekutGame.worldW * 0.74);
    tp.paint(canvas, Offset(FlamekutGame.worldW / 2 - tp.width / 2, y));
    return y + tp.height;
  }
}

class _Close extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _Close({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(220, 64),
          priority: 5,
        );

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    game.closeCredits();
  }

  @override
  void render(Canvas canvas) {
    final pulse = math.sin(_t * 2) * 0.5 + 0.5;
    final tp = TextPainter(
      text: TextSpan(
        text: 'close',
        style: TextStyle(
          color: Color.fromRGBO(239, 231, 214, 0.7 + 0.3 * pulse),
          fontSize: 28,
          fontWeight: FontWeight.w400,
          letterSpacing: 8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        size.x / 2 - tp.width / 2,
        size.y / 2 - tp.height / 2,
      ),
    );
  }
}
