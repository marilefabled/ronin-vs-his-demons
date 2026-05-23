import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/flamekut_game.dart';

/// Hosts the actual FlamekutGame inside the editor process, fed an
/// in-memory level JSON. Back arrow returns to the editor.
class TestPlayPage extends StatelessWidget {
  const TestPlayPage({super.key, required this.levelJson});

  final String levelJson;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14110D),
      body: Stack(
        children: [
          GameWidget<FlamekutGame>.controlled(
            gameFactory: () =>
                FlamekutGame(overrideLevelJson: levelJson),
            loadingBuilder: (_) => const ColoredBox(
              color: Color(0xFFEFE7D6),
              child: Center(
                child: Text(
                  '...',
                  style: TextStyle(
                    color: Color(0xFF1A1612),
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Material(
              color: const Color(0xCC1F1A14),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'back to editor',
                icon: const Icon(Icons.arrow_back,
                    color: Color(0xFFEDE2CE)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          const Positioned(
            top: 24,
            right: 20,
            child: Text(
              'test play',
              style: TextStyle(
                color: Color(0x88EDE2CE),
                fontSize: 14,
                letterSpacing: 4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
