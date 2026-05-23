import 'package:flutter/material.dart';

import 'editor/editor_app.dart';

void main() {
  runApp(const FlamekutEditor());
}

class FlamekutEditor extends StatelessWidget {
  const FlamekutEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ronin Vs His Demons · Level Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14110D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA72920),
          secondary: Color(0xFFD45438),
          surface: Color(0xFF1F1A14),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFFFFFFFF),
          onSurface: Color(0xFFEDE2CE),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFEDE2CE)),
          bodySmall: TextStyle(color: Color(0xFFB8A78A)),
        ),
      ),
      home: const EditorApp(),
    );
  }
}
