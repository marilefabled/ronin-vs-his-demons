import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// Pause overlay during gameplay. Tap "resume" to continue, tap
/// "exit to level select" to leave the run. Backdrop tap = resume.
class PauseScreen extends Component
    with HasGameReference<FlamekutGame> {
  PauseScreen() : super(priority: 1800);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_Backdrop());
    add(_Panel());
    add(_ResumeButton(
        position: Vector2(FlamekutGame.worldW * 0.5, FlamekutGame.worldH * 0.46)));
    add(_HelpBtn(
        position: Vector2(FlamekutGame.worldW * 0.5, FlamekutGame.worldH * 0.55)));
    add(_SettingsBtn(
        position: Vector2(FlamekutGame.worldW * 0.5, FlamekutGame.worldH * 0.64)));
    add(_ExitButton(
        position: Vector2(FlamekutGame.worldW * 0.5, FlamekutGame.worldH * 0.73)));
  }
}

class _Backdrop extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _Backdrop()
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
    final px = event.localPosition.x;
    final py = event.localPosition.y;
    final pl = FlamekutGame.worldW * 0.18;
    final pr = FlamekutGame.worldW * 0.82;
    final pt = FlamekutGame.worldH * 0.30;
    final pb = FlamekutGame.worldH * 0.70;
    if (px < pl || px > pr || py < pt || py > pb) {
      game.resumeGameplay();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      Paint()..color = const Color.fromRGBO(20, 17, 14, 0.65),
    );
  }
}

class _Panel extends Component {
  _Panel() : super(priority: 0);
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(
      FlamekutGame.worldW * 0.18,
      FlamekutGame.worldH * 0.30,
      FlamekutGame.worldW * 0.64,
      FlamekutGame.worldH * 0.40,
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

    final pulse = math.sin(_t * 0.9) * 0.06 + 1.0;
    final tp = TextPainter(
      text: TextSpan(
        text: 'paused',
        style: TextStyle(
          color: const Color(0xEE1A1612),
          fontSize: 64 * pulse,
          fontWeight: FontWeight.w300,
          letterSpacing: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - tp.width / 2,
        FlamekutGame.worldH * 0.36,
      ),
    );
  }
}

class _MenuButton extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _MenuButton({
    required Vector2 position,
    required this.label,
    required this.onPressed,
    this.primary = false,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(FlamekutGame.worldW * 0.50, 80),
          priority: 5,
        );

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= size.x &&
      point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    onPressed();
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final fill = Paint()
      ..color = primary
          ? const Color(0xFFA72920)
          : const Color.fromRGBO(40, 30, 24, 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      fill,
    );
    final border = Paint()
      ..color = primary
          ? const Color(0xFFD45438)
          : const Color.fromRGBO(40, 30, 24, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      border,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: primary
              ? const Color(0xFFEFE7D6)
              : const Color(0xCC1A1612),
          fontSize: 26,
          fontWeight: FontWeight.w400,
          letterSpacing: 4,
          fontStyle: FontStyle.italic,
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

class _ResumeButton extends _MenuButton {
  _ResumeButton({required super.position})
      : super(
          label: 'resume',
          primary: true,
          onPressed: () {},
        );

  @override
  void onTapDown(TapDownEvent event) {
    game.resumeGameplay();
  }
}

class _HelpBtn extends _MenuButton {
  _HelpBtn({required super.position})
      : super(
          label: 'how to play',
          onPressed: () {},
        );

  @override
  void onTapDown(TapDownEvent event) {
    game.openHowToPlay();
  }
}

class _SettingsBtn extends _MenuButton {
  _SettingsBtn({required super.position})
      : super(
          label: 'settings',
          onPressed: () {},
        );

  @override
  void onTapDown(TapDownEvent event) {
    game.openSettings();
  }
}

class _ExitButton extends _MenuButton {
  _ExitButton({required super.position})
      : super(
          label: 'exit to level select',
          onPressed: () {},
        );

  @override
  void onTapDown(TapDownEvent event) {
    game.exitToLevelSelect();
  }
}

/// Tiny pause button rendered in the top-right corner during gameplay.
class PauseButton extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  PauseButton()
      : super(
          position: Vector2(FlamekutGame.worldW - 80, 80),
          anchor: Anchor.center,
          size: Vector2.all(56),
          priority: 1100,
        );

  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - size.x / 2;
    final dy = point.y - size.y / 2;
    return dx * dx + dy * dy < 28 * 28;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (game.scene == AppScene.gameplay) {
      game.pauseGameplay();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);
    final bg = Paint()..color = const Color.fromRGBO(40, 30, 24, 0.65);
    canvas.drawCircle(Offset.zero, 24, bg);
    final rim = Paint()
      ..color = const Color.fromRGBO(245, 240, 225, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset.zero, 24, rim);
    // Two pause bars
    final bar = Paint()..color = const Color(0xFFEFE7D6);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(-6, 0), width: 5, height: 18),
      bar,
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(6, 0), width: 5, height: 18),
      bar,
    );
  }
}
