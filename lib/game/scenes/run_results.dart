import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';

/// End-of-run screen for Endless / Speedrun. Shows total levels cleared,
/// total time, "new best" badge if improved, and a tap-to-continue.
class RunResultsScreen extends Component
    with HasGameReference<FlamekutGame> {
  RunResultsScreen({
    required this.runTitle,
    required this.runId,
    required this.elapsedSec,
    required this.levelsCompleted,
    required this.completed,
    required this.improved,
    required this.onDismiss,
  }) : super(priority: 2300);

  final String runTitle;
  final String runId;
  final double elapsedSec;
  final int levelsCompleted;
  final bool completed;
  final bool improved;
  final VoidCallback onDismiss;

  bool _dismissed = false;
  double _t = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_ResultsBackdrop());
    add(_ResultsBody(
      runTitle: runTitle,
      elapsedSec: elapsedSec,
      levelsCompleted: levelsCompleted,
      completed: completed,
      improved: improved,
      bestTime: game.runRecords.get(runId).bestTimeSec,
      bestLevels: game.runRecords.get(runId).bestLevels,
      tProvider: () => _t,
    ));
    add(_ResultsTap(onTap: _maybeDismiss));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  void _maybeDismiss() {
    if (_dismissed) return;
    if (_t < 0.6) return;
    _dismissed = true;
    removeFromParent();
    onDismiss();
  }
}

class _ResultsBackdrop extends Component {
  _ResultsBackdrop() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      Paint()..color = const Color.fromRGBO(20, 17, 14, 0.85),
    );
  }
}

class _ResultsTap extends PositionComponent with TapCallbacks {
  _ResultsTap({required this.onTap})
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

class _ResultsBody extends Component {
  _ResultsBody({
    required this.runTitle,
    required this.elapsedSec,
    required this.levelsCompleted,
    required this.completed,
    required this.improved,
    required this.bestTime,
    required this.bestLevels,
    required this.tProvider,
  }) : super(priority: 0);

  final String runTitle;
  final double elapsedSec;
  final int levelsCompleted;
  final bool completed;
  final bool improved;
  final double bestTime;
  final int bestLevels;
  final double Function() tProvider;

  String _fmtTime(double s) {
    final m = (s ~/ 60);
    final r = s - m * 60;
    if (m > 0) return '${m}m ${r.toStringAsFixed(2)}s';
    return '${s.toStringAsFixed(2)}s';
  }

  @override
  void render(Canvas canvas) {
    final t = tProvider();

    // Headline
    final fadeIn = (t / 0.5).clamp(0.0, 1.0);
    final headline = completed ? 'run complete' : 'run ended';
    final tp = TextPainter(
      text: TextSpan(
        text: headline,
        style: TextStyle(
          color: Color.fromRGBO(245, 240, 225, 0.95 * fadeIn),
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: 12,
          shadows: [
            Shadow(
              color: Color.fromRGBO(167, 41, 32, 0.55 * fadeIn),
              blurRadius: 20,
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
        FlamekutGame.worldH * 0.18,
      ),
    );

    // Subtitle (run title)
    final subTp = TextPainter(
      text: TextSpan(
        text: runTitle,
        style: TextStyle(
          color: Color.fromRGBO(220, 200, 170, 0.7 * fadeIn),
          fontSize: 28,
          fontStyle: FontStyle.italic,
          letterSpacing: 5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - subTp.width / 2,
        FlamekutGame.worldH * 0.18 + 80,
      ),
    );

    // Big stat: total time
    final timeIn = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
    final scale = 0.92 + 0.08 * timeIn;
    final timeTp = TextPainter(
      text: TextSpan(
        text: _fmtTime(elapsedSec),
        style: TextStyle(
          color: Color.fromRGBO(245, 240, 225, 0.98 * timeIn),
          fontSize: 124 * scale,
          fontWeight: FontWeight.w300,
          letterSpacing: 4,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    timeTp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - timeTp.width / 2,
        FlamekutGame.worldH * 0.36,
      ),
    );

    // Levels cleared
    final levelsIn = ((t - 0.7) / 0.6).clamp(0.0, 1.0);
    final levelsTp = TextPainter(
      text: TextSpan(
        text: '$levelsCompleted level${levelsCompleted == 1 ? '' : 's'} cleared',
        style: TextStyle(
          color: Color.fromRGBO(220, 200, 170, 0.85 * levelsIn),
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: 4,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    levelsTp.paint(
      canvas,
      Offset(
        FlamekutGame.worldW / 2 - levelsTp.width / 2,
        FlamekutGame.worldH * 0.50,
      ),
    );

    // Best comparison row
    final bestIn = ((t - 1.1) / 0.6).clamp(0.0, 1.0);
    if (bestTime.isFinite || bestLevels > 0) {
      final bestText = bestTime.isFinite
          ? 'best · ${_fmtTime(bestTime)} ($bestLevels)'
          : 'best · $bestLevels levels';
      final bestTp = TextPainter(
        text: TextSpan(
          text: bestText,
          style: TextStyle(
            color: Color.fromRGBO(167, 130, 90, 0.85 * bestIn),
            fontSize: 22,
            fontWeight: FontWeight.w400,
            letterSpacing: 3,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      bestTp.paint(
        canvas,
        Offset(
          FlamekutGame.worldW / 2 - bestTp.width / 2,
          FlamekutGame.worldH * 0.58,
        ),
      );
    }

    // "new best!" badge
    if (improved) {
      final badgeIn = ((t - 1.3) / 0.5).clamp(0.0, 1.0);
      final badgePulse = math.sin(t * 4) * 0.5 + 0.5;
      final badgeTp = TextPainter(
        text: TextSpan(
          text: '· new best ·',
          style: TextStyle(
            color: Color.fromRGBO(
              245,
              168,
              96,
              (0.7 + 0.3 * badgePulse) * badgeIn,
            ),
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 6,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      badgeTp.paint(
        canvas,
        Offset(
          FlamekutGame.worldW / 2 - badgeTp.width / 2,
          FlamekutGame.worldH * 0.65,
        ),
      );
    }

    // Tap-to-continue hint
    if (t > 1.4) {
      final pulse = math.sin(t * 2.0) * 0.5 + 0.5;
      final hintAlpha = ((t - 1.4) / 0.5).clamp(0.0, 1.0);
      final hint = TextPainter(
        text: TextSpan(
          text: 'tap to return',
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
}
