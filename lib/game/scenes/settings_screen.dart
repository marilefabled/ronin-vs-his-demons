import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// Settings overlay — BGM volume slider, Voice volume slider, Reset Progress
/// button, Close button.
class SettingsScreen extends Component
    with HasGameReference<FlamekutGame> {
  SettingsScreen() : super(priority: 1900);

  late final _Backdrop _backdrop;
  late final _Panel _panel;
  late final _Slider _bgmSlider;
  late final _Slider _voiceSlider;
  late final _Slider _sfxSlider;
  late final _Toggle _reducedMotionToggle;
  late final _Toggle _colorblindToggle;
  late final _ResetButton _resetBtn;
  late final _CloseButton _closeBtn;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _backdrop = _Backdrop();
    add(_backdrop);
    _panel = _Panel();
    add(_panel);

    final cx = FlamekutGame.worldW / 2;
    var y = FlamekutGame.worldH * 0.30;

    _bgmSlider = _Slider(
      label: 'music',
      position: Vector2(cx, y),
      get: () => game.settings.bgmVolume,
      set: (v) {
        game.settings.bgmVolume = v;
        game.bgm.setVolume(v);
        game.settings.save();
      },
    );
    add(_bgmSlider);
    y += 130;

    _voiceSlider = _Slider(
      label: 'voice',
      position: Vector2(cx, y),
      get: () => game.settings.voiceVolume,
      set: (v) {
        game.settings.voiceVolume = v;
        game.voice.voiceVolume = v;
        game.settings.save();
      },
    );
    add(_voiceSlider);
    y += 130;

    _sfxSlider = _Slider(
      label: 'sfx',
      position: Vector2(cx, y),
      get: () => game.settings.sfxVolume,
      set: (v) {
        game.settings.sfxVolume = v;
        game.sfx.sfxVolume = v;
        game.settings.save();
      },
    );
    add(_sfxSlider);
    y += 140;

    _reducedMotionToggle = _Toggle(
      label: 'reduced motion',
      position: Vector2(cx, y),
      get: () => game.settings.reducedMotion,
      set: (v) {
        game.settings.reducedMotion = v;
        game.settings.save();
      },
    );
    add(_reducedMotionToggle);
    y += 90;

    _colorblindToggle = _Toggle(
      label: 'colorblind shapes',
      position: Vector2(cx, y),
      get: () => game.settings.colorblindShapes,
      set: (v) {
        game.settings.colorblindShapes = v;
        game.settings.save();
      },
    );
    add(_colorblindToggle);
    y += 110;

    _resetBtn = _ResetButton(position: Vector2(cx, y));
    add(_resetBtn);

    _closeBtn = _CloseButton(
        position: Vector2(FlamekutGame.worldW * 0.5, FlamekutGame.worldH * 0.90));
    add(_closeBtn);
  }
}

class _Toggle extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _Toggle({
    required this.label,
    required Vector2 position,
    required this.get,
    required this.set,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(FlamekutGame.worldW * 0.66, 70),
          priority: 5,
        );

  final String label;
  final bool Function() get;
  final void Function(bool) set;

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= size.x &&
      point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    set(!get());
  }

  @override
  void render(Canvas canvas) {
    final on = get();
    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 28,
          fontWeight: FontWeight.w400,
          letterSpacing: 4,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(8, size.y / 2 - tp.height / 2));

    // Toggle pill
    final pillW = 84.0;
    final pillH = 36.0;
    final pillX = size.x - pillW - 12;
    final pillY = size.y / 2 - pillH / 2;
    final pillRect = Rect.fromLTWH(pillX, pillY, pillW, pillH);
    final pillFill = Paint()
      ..color = on
          ? const Color(0xFFA72920)
          : const Color.fromRGBO(40, 30, 24, 0.30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(18)),
      pillFill,
    );
    // Knob
    final knobX = on ? pillX + pillW - 18 : pillX + 18;
    final knobY = pillY + pillH / 2;
    final knob = Paint()..color = const Color(0xFFEFE7D6);
    canvas.drawCircle(Offset(knobX, knobY), 14, knob);
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
    // Tap outside the panel closes settings.
    final px = event.localPosition.x;
    final py = event.localPosition.y;
    final panelLeft = FlamekutGame.worldW * 0.10;
    final panelRight = FlamekutGame.worldW * 0.90;
    final panelTop = FlamekutGame.worldH * 0.18;
    final panelBottom = FlamekutGame.worldH * 0.92;
    if (px < panelLeft ||
        px > panelRight ||
        py < panelTop ||
        py > panelBottom) {
      game.closeSettings();
    }
  }

  @override
  void render(Canvas canvas) {
    final dim = Paint()
      ..color = const Color.fromRGBO(20, 17, 14, 0.55);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      dim,
    );
  }
}

class _Panel extends Component {
  _Panel() : super(priority: 0);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(
      FlamekutGame.worldW * 0.10,
      FlamekutGame.worldH * 0.18,
      FlamekutGame.worldW * 0.80,
      FlamekutGame.worldH * 0.74,
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
    final tp = TextPainter(
      text: const TextSpan(
        text: 'settings',
        style: TextStyle(
          color: Color(0xEE1A1612),
          fontSize: 64,
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
        FlamekutGame.worldH * 0.22,
      ),
    );

    // Decorative brushstroke under title
    final line = Paint()
      ..color = const Color.fromRGBO(167, 41, 32, 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final p = Path()
      ..moveTo(FlamekutGame.worldW * 0.35, FlamekutGame.worldH * 0.265)
      ..quadraticBezierTo(
        FlamekutGame.worldW * 0.50,
        FlamekutGame.worldH * 0.265 + 6,
        FlamekutGame.worldW * 0.65,
        FlamekutGame.worldH * 0.265,
      );
    canvas.drawPath(p, line);
  }
}

class _Slider extends PositionComponent
    with DragCallbacks, HasGameReference<FlamekutGame> {
  _Slider({
    required this.label,
    required Vector2 position,
    required this.get,
    required this.set,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(FlamekutGame.worldW * 0.66, 96),
          priority: 5,
        );

  final String label;
  final double Function() get;
  final void Function(double) set;

  void _setFromX(double localX) {
    final t = ((localX - 12) / (size.x - 24)).clamp(0.0, 1.0);
    set(t.toDouble());
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= size.x &&
      point.y <= size.y;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _setFromX(event.localPosition.x);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _setFromX(event.localEndPosition.x);
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(0, 0);

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xCC1A1612),
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: 5,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(8, -50));

    // Track
    final v = get();
    final trackY = 24.0;
    final track = Paint()
      ..color = const Color.fromRGBO(40, 30, 24, 0.30)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas.drawLine(
      Offset(12, trackY),
      Offset(size.x - 12, trackY),
      track,
    );

    // Filled portion
    final fillX = 12 + (size.x - 24) * v;
    final fill = Paint()
      ..color = const Color.fromRGBO(167, 41, 32, 0.85)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas.drawLine(
      Offset(12, trackY),
      Offset(fillX, trackY),
      fill,
    );

    // Knob
    final knob = Paint()..color = const Color(0xFFA72920);
    canvas.drawCircle(Offset(fillX, trackY), 14, knob);
    final knobInner = Paint()..color = const Color(0xFFEFE7D6);
    canvas.drawCircle(Offset(fillX, trackY), 5, knobInner);

    // Value text
    final valTp = TextPainter(
      text: TextSpan(
        text: '${(v * 100).round()}',
        style: const TextStyle(
          color: Color(0xEE1A1612),
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    valTp.paint(canvas, Offset(size.x - valTp.width - 8, -42));
  }
}

class _ResetButton extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _ResetButton({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(FlamekutGame.worldW * 0.55, 86),
          priority: 5,
        );

  double _confirmT = 0;
  bool _armed = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_armed) {
      _confirmT += dt;
      if (_confirmT > 2.5) {
        _armed = false;
        _confirmT = 0;
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= size.x &&
      point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (_armed) {
      game.resetAllProgress();
      _armed = false;
      _confirmT = 0;
    } else {
      _armed = true;
      _confirmT = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final pulse = _armed
        ? (math.sin(_confirmT * 8) * 0.15 + 1.0)
        : 1.0;
    final fill = Paint()
      ..color = _armed
          ? Color.fromRGBO(
              167, 41, 32, 0.85 * pulse)
          : const Color.fromRGBO(40, 30, 24, 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      fill,
    );
    final border = Paint()
      ..color = _armed
          ? const Color.fromRGBO(245, 100, 70, 0.95)
          : const Color.fromRGBO(40, 30, 24, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      border,
    );

    final label = _armed ? 'tap again to confirm' : 'reset progress';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: _armed
              ? const Color(0xFFEFE7D6)
              : const Color(0xCC1A1612),
          fontSize: 28,
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

class _CloseButton extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  _CloseButton({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2(220, 64),
          priority: 5,
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
    game.closeSettings();
  }

  @override
  void render(Canvas canvas) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'close',
        style: TextStyle(
          color: Color(0xEE1A1612),
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: 6,
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
