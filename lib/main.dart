import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/flamekut_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const FlamekutApp());
}

class FlamekutApp extends StatelessWidget {
  const FlamekutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ronin Vs His Demons',
      debugShowCheckedModeBanner: false,
      home: GameWidget<FlamekutGame>.controlled(
        gameFactory: FlamekutGame.new,
        loadingBuilder: (_) => const ColoredBox(
          color: Color(0xFFEFE7D6),
          child: Center(
            child: Text(
              '...',
              style: TextStyle(
                color: Color(0xFF1A1612),
                fontSize: 32,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
