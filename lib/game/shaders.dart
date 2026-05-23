import 'dart:ui' as ui;

/// Loaded fragment-shader programs. Loaded once at boot. If any fail
/// (e.g. on a platform that doesn't support custom shaders), the value
/// stays null and components fall back to Canvas-based rendering.
class Shaders {
  ui.FragmentProgram? paper;
  ui.FragmentProgram? glow;
  ui.FragmentProgram? chromatic;

  bool get ready => paper != null && glow != null && chromatic != null;

  Future<void> load() async {
    paper = await _safeLoad('shaders/paper.frag');
    glow = await _safeLoad('shaders/glow.frag');
    chromatic = await _safeLoad('shaders/chromatic.frag');
  }

  Future<ui.FragmentProgram?> _safeLoad(String path) async {
    try {
      return await ui.FragmentProgram.fromAsset(path);
    } catch (_) {
      return null;
    }
  }
}
