import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// Boot-screen overlay. Big brand mark + "tap to begin" prompt + small
/// settings icon. Tap anywhere (except settings icon) to enter level select.
class TitleScreen extends Component
    with HasGameReference<FlamekutGame> {
  TitleScreen() : super(priority: 1500);

  late final _TitleBackdrop _backdrop;
  late final _TitleBrand _brand;
  late final _TitleTapHint _tapHint;
  late final _SettingsButton _settingsBtn;
  late final _HelpButton _helpBtn;
  late final _CreditsButton _creditsBtn;
  late final _TapToBegin _tapBegin;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _backdrop = _TitleBackdrop();
    add(_backdrop);
    _brand = _TitleBrand();
    add(_brand);
    _tapHint = _TitleTapHint();
    add(_tapHint);
    _settingsBtn = _SettingsButton();
    add(_settingsBtn);
    _helpBtn = _HelpButton();
    add(_helpBtn);
    _creditsBtn = _CreditsButton();
    add(_creditsBtn);
    _tapBegin = _TapToBegin();
    add(_tapBegin);
  }
}

class _TitleBackdrop extends Component
    with HasGameReference<FlamekutGame> {
  _TitleBackdrop() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    // Soft overlay so the gameplay scenery is dimmed without obliterating
    final paint = Paint()
      ..color = const Color.fromRGBO(239, 231, 214, 0.55);
    canvas.drawRect(
      const Rect.fromLTWH(
          0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      paint,
    );
  }
}

class _TitleBrand extends Component {
  _TitleBrand() : super(priority: 5);

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final pulse = math.sin(_t * 0.9) * 0.04 + 1.0;

    // Big brushstroke title
    final tp = TextPainter(
      text: TextSpan(
        text: 'RONIN',
        style: TextStyle(
          color: const Color(0xEE1A1612),
          fontSize: 196 * pulse,
          fontWeight: FontWeight.w200,
          letterSpacing: 36,
          shadows: [
            const Shadow(
                color: Color(0x55A72920),
                blurRadius: 32,
                offset: Offset(0, 12)),
            const Shadow(
                color: Color(0x99A72920), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tp.width / 2,
        FlamekutGame.worldH * 0.18,
      ),
    );

    // Subtitle — "vs his demons" in red
    final sub = TextPainter(
      text: const TextSpan(
        text: 'vs his demons',
        style: TextStyle(
          color: Color(0xDDA72920),
          fontSize: 48,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
          letterSpacing: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - sub.width / 2,
        FlamekutGame.worldH * 0.18 + 224,
      ),
    );

    // Tagline
    final tag = TextPainter(
      text: const TextSpan(
        text: 'the weight of every blade',
        style: TextStyle(
          color: Color(0xAA1A1612),
          fontSize: 28,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
          letterSpacing: 5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tag.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tag.width / 2,
        FlamekutGame.worldH * 0.18 + 300,
      ),
    );

    // Long brushstroke ink line under the title
    final line = Paint()
      ..color = Color.fromRGBO(20, 17, 14, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final p = Path()
      ..moveTo(FlamekutGame.worldW * 0.20, FlamekutGame.worldH * 0.40)
      ..quadraticBezierTo(
        FlamekutGame.worldW * 0.50,
        FlamekutGame.worldH * 0.40 + 16,
        FlamekutGame.worldW * 0.80,
        FlamekutGame.worldH * 0.40,
      );
    canvas.drawPath(p, line);
  }
}

class _TitleTapHint extends Component {
  _TitleTapHint() : super(priority: 5);

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    // Pulsing hint
    final pulse = math.sin(_t * 2.2) * 0.5 + 0.5;
    final tp = TextPainter(
      text: TextSpan(
        text: 'tap to begin',
        style: TextStyle(
          color: Color.fromRGBO(26, 22, 18, 0.55 + 0.30 * pulse),
          fontSize: 38,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
          letterSpacing: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tp.width / 2,
        FlamekutGame.worldH * 0.78,
      ),
    );
  }
}

/// Full-screen invisible tap zone behind the brand. Brings up level select.
class _TapToBegin extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _TapToBegin()
      : super(
          size: Vector2(FlamekutGame.worldW, FlamekutGame.worldH),
          priority: -5,
        );

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= size.x &&
      point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    // First user gesture — kick BGM in case browser autoplay blocked it.
    game.bgm.ensureStarted();
    game.enterLevelSelect();
  }
}

class _CreditsButton extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _CreditsButton()
      : super(
          position: Vector2(80, 80 + 78),
          anchor: Anchor.center,
          size: Vector2.all(64),
          priority: 10,
        );

  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - size.x / 2;
    final dy = point.y - size.y / 2;
    return dx * dx + dy * dy < 30 * 30;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    game.openCredits();
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final bg = Paint()
      ..color = const Color.fromRGBO(243, 236, 219, 0.85);
    canvas.drawCircle(Offset.zero, 30, bg);
    final rim = Paint()
      ..color = const Color.fromRGBO(40, 30, 24, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, 30, rim);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'i',
        style: TextStyle(
          color: Color(0xEE1A1612),
          fontSize: 32,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

class _HelpButton extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _HelpButton()
      : super(
          position: Vector2(80, 80),
          anchor: Anchor.center,
          size: Vector2.all(64),
          priority: 10,
        );

  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - size.x / 2;
    final dy = point.y - size.y / 2;
    return dx * dx + dy * dy < 30 * 30;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    game.openHowToPlay();
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final bg = Paint()
      ..color = const Color.fromRGBO(243, 236, 219, 0.85);
    canvas.drawCircle(Offset.zero, 30, bg);
    final rim = Paint()
      ..color = const Color.fromRGBO(40, 30, 24, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, 30, rim);
    final tp = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Color(0xEE1A1612),
          fontSize: 36,
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

class _SettingsButton extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _SettingsButton()
      : super(
          position:
              Vector2(FlamekutGame.worldW - 80, 80),
          anchor: Anchor.center,
          size: Vector2.all(64),
          priority: 10,
        );

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    game.openSettings();
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final spin = _t * 0.4;

    // Faint disc background
    final bg = Paint()
      ..color = const Color.fromRGBO(243, 236, 219, 0.85);
    canvas.drawCircle(Offset.zero, 30, bg);
    final rim = Paint()
      ..color = const Color.fromRGBO(40, 30, 24, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, 30, rim);

    // Gear teeth
    canvas.save();
    canvas.rotate(spin);
    final tooth = Paint()
      ..color = const Color.fromRGBO(40, 30, 24, 0.85);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final c = Offset(math.cos(a) * 22, math.sin(a) * 22);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 12),
        tooth,
      );
      canvas.restore();
    }
    canvas.restore();
    final inner = Paint()
      ..color = const Color.fromRGBO(40, 30, 24, 0.85);
    canvas.drawCircle(Offset.zero, 14, inner);
    final hole = Paint()
      ..color = const Color.fromRGBO(243, 236, 219, 0.95);
    canvas.drawCircle(Offset.zero, 6, hole);
  }
}
