import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../flamekut_game.dart';
import '../kits.dart';

/// Browse + equip samurai variants. Shows lock state and stats.
class KitSelect extends Component
    with HasGameReference<FlamekutGame> {
  KitSelect() : super(priority: 1700);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_Backdrop());
    add(_Title());

    final tiles = kAllKits;
    const tileW = 760.0;
    const tileH = 170.0;
    const gapY = 18.0;
    final startY = FlamekutGame.worldH * 0.22;
    for (var i = 0; i < tiles.length; i++) {
      final y = startY + i * (tileH + gapY);
      add(KitCard(
        kit: tiles[i],
        size: Vector2(tileW, tileH),
        spawnPosition: Vector2(FlamekutGame.worldW / 2, y + tileH / 2),
      ));
    }

    add(_Close(
      position: Vector2(FlamekutGame.worldW * 0.5, FlamekutGame.worldH * 0.94),
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
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, FlamekutGame.worldW, FlamekutGame.worldH),
      Paint()..color = const Color.fromRGBO(20, 17, 14, 0.85),
    );
  }
}

class _Title extends Component
    with HasGameReference<FlamekutGame> {
  _Title() : super(priority: 0);

  @override
  void render(Canvas canvas) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'forms',
        style: TextStyle(
          color: Color(0xEEEFE7D6),
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: 16,
          shadows: [
            Shadow(color: Color(0x55A72920), blurRadius: 16),
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

    // Total stars readout
    final stars = game.totalStars;
    final sub = TextPainter(
      text: TextSpan(
        text: '$stars ★ collected',
        style: const TextStyle(
          color: Color(0xCCB8A78A),
          fontSize: 22,
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
        FlamekutGame.worldH * 0.10 + 80,
      ),
    );
  }
}

class KitCard extends PositionComponent
    with TapCallbacks, HasGameReference<FlamekutGame> {
  KitCard({
    required this.kit,
    required Vector2 size,
    required Vector2 spawnPosition,
  }) : super(
          position: spawnPosition,
          size: size,
          anchor: Anchor.center,
          priority: 5,
        );

  final SamuraiKit kit;
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
    if (!_unlocked) return;
    game.kitStore.select(kit.id);
  }

  bool get _unlocked => game.kitStore.isUnlocked(kit, game.totalStars);
  bool get _selected => game.kitStore.selectedId == kit.id;

  @override
  void render(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);

    // Card background
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final bgA = _unlocked ? 0.95 : 0.45;
    final fill = Paint()
      ..color = Color.fromRGBO(243, 236, 219, bgA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      fill,
    );
    final border = Paint()
      ..color = _selected
          ? const Color(0xFFA72920)
          : const Color.fromRGBO(40, 30, 24, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _selected ? 4 : 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      border,
    );

    // Sigil (preview): kasa + sash + accent in kit colors
    final sigilCx = -size.x / 2 + 80;
    canvas.save();
    canvas.translate(sigilCx, 0);
    if (!_unlocked) {
      // Lock badge instead of sigil
      final lock = Paint()
        ..color = const Color.fromRGBO(40, 30, 24, 0.55)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5;
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, -8), width: 32, height: 38),
        -math.pi,
        math.pi,
        false,
        lock,
      );
      canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, 16), width: 38, height: 30),
        Paint()..color = const Color.fromRGBO(40, 30, 24, 0.85),
      );
    } else {
      // Hat
      final hat = Paint()..color = kit.kasaColor.withValues(alpha: 0.96);
      canvas.drawCircle(const Offset(0, -2), 36, hat);
      // Hat creases
      final crease = Paint()
        ..color = Color.lerp(kit.kasaColor, const Color(0xFFFFFFFF), 0.18)!
            .withValues(alpha: 0.55)
        ..strokeWidth = 0.7;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(
          const Offset(0, -2),
          Offset(math.cos(a) * 32, -2 + math.sin(a) * 32),
          crease,
        );
      }
      // Sash
      final sash = Paint()..color = kit.sashColor.withValues(alpha: 0.95);
      canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, -2), width: 56, height: 5),
        sash,
      );
      // Accent face mark
      final accent = Paint()..color = kit.accentColor.withValues(alpha: 0.92);
      canvas.drawCircle(const Offset(0, -8), 4, accent);
    }
    canvas.restore();

    // Name
    final nameTp = TextPainter(
      text: TextSpan(
        text: kit.name,
        style: TextStyle(
          color: Color.fromRGBO(26, 22, 18, 0.95 * bgA),
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nameTp.paint(canvas, Offset(-size.x / 2 + 160, -size.y / 2 + 24));

    // Tagline
    final tagTp = TextPainter(
      text: TextSpan(
        text: kit.tagline,
        style: TextStyle(
          color: Color.fromRGBO(26, 22, 18, 0.65 * bgA),
          fontSize: 18,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x - 200);
    tagTp.paint(canvas, Offset(-size.x / 2 + 160, -size.y / 2 + 70));

    // Stats row
    final statsTp = TextPainter(
      text: TextSpan(
        children: [
          _statSpan('spd', kit.speed.toStringAsFixed(0), bgA),
          _spacer(),
          _statSpan('mom', '+${kit.momentumGain.toStringAsFixed(0)}', bgA),
          _spacer(),
          _statSpan('reach', kit.reach.toStringAsFixed(0), bgA),
        ],
        style: TextStyle(
          color: Color.fromRGBO(26, 22, 18, 0.75 * bgA),
          fontSize: 16,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    statsTp.paint(
      canvas,
      Offset(-size.x / 2 + 160, size.y / 2 - 36),
    );

    // Lock requirement (right-aligned) or "equipped" badge
    if (_selected) {
      final pulse = math.sin(_t * 2.4) * 0.5 + 0.5;
      final eqTp = TextPainter(
        text: TextSpan(
          text: '· equipped ·',
          style: TextStyle(
            color: Color.fromRGBO(167, 41, 32, 0.7 + 0.30 * pulse),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      eqTp.paint(
        canvas,
        Offset(size.x / 2 - eqTp.width - 20, -size.y / 2 + 30),
      );
    } else if (!_unlocked) {
      final reqTp = TextPainter(
        text: TextSpan(
          text: '${kit.unlockStars} ★',
          style: const TextStyle(
            color: Color(0xCC1A1612),
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      reqTp.paint(
        canvas,
        Offset(size.x / 2 - reqTp.width - 20, -size.y / 2 + 30),
      );
    }
  }

  TextSpan _statSpan(String label, String value, double bgA) {
    return TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: TextStyle(
            color: Color.fromRGBO(26, 22, 18, 0.45 * bgA),
            fontSize: 14,
          ),
        ),
        TextSpan(
          text: value,
          style: TextStyle(
            color: Color.fromRGBO(26, 22, 18, 0.85 * bgA),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  TextSpan _spacer() => const TextSpan(
        text: '   ',
        style: TextStyle(fontSize: 14),
      );
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

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    game.closeKitSelect();
  }

  @override
  void render(Canvas canvas) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'close',
        style: TextStyle(
          color: Color(0xEEEFE7D6),
          fontSize: 28,
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
