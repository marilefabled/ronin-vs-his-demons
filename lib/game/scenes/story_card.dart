import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';
import '../story.dart';

/// Full-screen narrative beat. Brushstroke text fades in line-by-line
/// over a dimmed paper backdrop, optional voice line plays, animated ink
/// rule draws beneath. Tap (after a short grace) or auto-advance after
/// `lingerSec` dismisses.
class StoryCard extends Component
    with HasGameReference<FlamekutGame> {
  StoryCard({required this.beat, required this.onDismiss})
      : super(priority: 2200);

  final StoryBeat beat;
  final void Function() onDismiss;

  late final _Backdrop _backdrop;
  late final _Body _body;
  late final _TapZone _tapZone;
  bool _dismissed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _backdrop = _Backdrop();
    add(_backdrop);
    _body = _Body(beat: beat);
    add(_body);
    _tapZone = _TapZone(onTap: _maybeDismiss);
    add(_tapZone);
    if (beat.voice != null) {
      // Slight delay so the visual lands first.
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        game.voice.play(beat.voice!);
      });
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_body._t >= beat.lingerSec) _maybeDismiss();
  }

  void _maybeDismiss() {
    if (_dismissed) return;
    if (_body._t < 0.6) return; // grace against accidental skip
    _dismissed = true;
    removeFromParent();
    onDismiss();
  }
}

class _TapZone extends PositionComponent with TapCallbacks {
  _TapZone({required this.onTap})
      : super(
          size: Vector2(FlamekutGame.worldW, FlamekutGame.worldH),
          priority: 5,
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
}

class _Backdrop extends Component {
  _Backdrop() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      Paint()..color = const Color.fromRGBO(20, 17, 14, 0.78),
    );
  }
}

class _Body extends Component {
  _Body({required this.beat}) : super(priority: 0);

  final StoryBeat beat;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final t = _t;
    final lines = beat.lines;
    final lineCount = lines.length;
    const lineSpacing = 96.0;
    final centerY = FlamekutGame.worldH * 0.46;
    final firstY = centerY - ((lineCount - 1) * lineSpacing) / 2;

    // Decorative top + bottom ink rules
    _drawInkRule(canvas, FlamekutGame.worldH * 0.30, t, leadDelay: 0.0);
    _drawInkRule(canvas, FlamekutGame.worldH * 0.62, t, leadDelay: 0.4);

    for (var i = 0; i < lineCount; i++) {
      final lineDelay = 0.55 + i * 0.55;
      final fadeIn = ((t - lineDelay) / 0.7).clamp(0.0, 1.0);
      // Final fade-out near the end
      final tail = beat.lingerSec - 0.6;
      final fadeOut = t < tail ? 1.0 : 1 - ((t - tail) / 0.6).clamp(0.0, 1.0);
      final alpha = fadeIn * fadeOut;
      if (alpha <= 0.001) continue;

      final scale = 0.96 + 0.04 * fadeIn;
      final offsetY = (1 - fadeIn) * 12;

      final tp = TextPainter(
        text: TextSpan(
          text: lines[i],
          style: TextStyle(
            color: Color.fromRGBO(245, 240, 225, 0.95 * alpha),
            fontSize: 56 * scale,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
            fontStyle: FontStyle.italic,
            height: 1.0,
            shadows: [
              Shadow(
                color: Color.fromRGBO(167, 41, 32, 0.45 * alpha),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          FlamekutGame.worldW / 2 - tp.width / 2,
          firstY + i * lineSpacing - tp.height / 2 + offsetY,
        ),
      );
    }

    // Tap-to-continue hint after a moment
    if (t > 1.8) {
      final pulse = math.sin(t * 2.3) * 0.5 + 0.5;
      final hintAlpha = ((t - 1.8) / 0.5).clamp(0.0, 1.0);
      final hint = TextPainter(
        text: TextSpan(
          text: 'tap to continue',
          style: TextStyle(
            color: Color.fromRGBO(
                239, 231, 214, (0.30 + 0.30 * pulse) * hintAlpha),
            fontSize: 22,
            fontStyle: FontStyle.italic,
            letterSpacing: 5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hint.paint(
        canvas,
        Offset(
          FlamekutGame.worldW / 2 - hint.width / 2,
          FlamekutGame.worldH * 0.84,
        ),
      );
    }
  }

  /// Animated ink rule that draws progressively from center outward.
  void _drawInkRule(Canvas canvas, double y, double t, {required double leadDelay}) {
    final p = ((t - leadDelay) / 1.4).clamp(0.0, 1.0);
    if (p <= 0) return;

    final w = FlamekutGame.worldW;
    final centerX = w / 2;
    final extent = (w * 0.36) * p;

    final paint = Paint()
      ..color = Color.fromRGBO(167, 41, 32, 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(centerX - extent, y)
      ..quadraticBezierTo(centerX, y + 4, centerX + extent, y);
    canvas.drawPath(path, paint);

    // Ink dots at the endpoints
    final dot = Paint()..color = Color.fromRGBO(167, 41, 32, 0.9);
    canvas.drawCircle(Offset(centerX - extent, y), 3, dot);
    canvas.drawCircle(Offset(centerX + extent, y), 3, dot);
  }
}
