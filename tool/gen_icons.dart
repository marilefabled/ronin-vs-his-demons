// Generates the app's icon set and an Open Graph share image without
// needing the Flutter engine — pure-Dart via package:image.
//
// Run from project root:
//   dart run tool/gen_icons.dart
//
// Output:
//   web/favicon.png                  (32×32)
//   web/icons/Icon-192.png           (192×192)
//   web/icons/Icon-512.png           (512×512)
//   web/icons/Icon-maskable-192.png  (192×192 padded)
//   web/icons/Icon-maskable-512.png  (512×512 padded)
//   web/og-image.png                 (1200×630 social share card)

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final outRoot = Directory.current.path;
  print('writing into: $outRoot');

  // ─── App icons (square, edge-bleed) ────────────────────────────────
  _writeIcon('${outRoot}/web/favicon.png', 64, padding: 0.10);
  _writeIcon('${outRoot}/web/icons/Icon-192.png', 192, padding: 0.10);
  _writeIcon('${outRoot}/web/icons/Icon-512.png', 512, padding: 0.10);

  // Maskable variants need extra safe-zone padding (Android trims edges).
  _writeIcon('${outRoot}/web/icons/Icon-maskable-192.png', 192,
      padding: 0.20);
  _writeIcon('${outRoot}/web/icons/Icon-maskable-512.png', 512,
      padding: 0.20);

  // ─── OG share image (1200×630) ────────────────────────────────────
  _writeOgImage('${outRoot}/web/og-image.png');

  print('done.');
}

// ────────────────────────────────────────────────────────────────────
// Drawing primitives
// ────────────────────────────────────────────────────────────────────

const _paperTop = [0xF3, 0xEC, 0xDB];
const _paperBot = [0xE7, 0xDE, 0xC8];
const _ink = [0x1A, 0x16, 0x10];
const _red = [0xA7, 0x29, 0x20];
const _redBright = [0xC8, 0x40, 0x32];

img.Image _newPaperImage(int w, int h) {
  final im = img.Image(width: w, height: h);
  // Vertical paper gradient.
  for (var y = 0; y < h; y++) {
    final t = y / h;
    final r = ((_paperTop[0] * (1 - t)) + (_paperBot[0] * t)).round();
    final g = ((_paperTop[1] * (1 - t)) + (_paperBot[1] * t)).round();
    final b = ((_paperTop[2] * (1 - t)) + (_paperBot[2] * t)).round();
    final c = img.ColorRgb8(r, g, b);
    for (var x = 0; x < w; x++) {
      im.setPixel(x, y, c);
    }
  }
  return im;
}

// Add subtle paper grain (light noise) for texture.
void _grain(img.Image im, {double amp = 6}) {
  final rng = math.Random(7);
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final n = (rng.nextDouble() - 0.5) * amp;
      final p = im.getPixel(x, y);
      final r = (p.r + n).clamp(0, 255).toInt();
      final g = (p.g + n).clamp(0, 255).toInt();
      final b = (p.b + n).clamp(0, 255).toInt();
      im.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }
}

void _fillCircle(img.Image im, double cx, double cy, double radius,
    List<int> color,
    {double opacity = 1.0}) {
  final r2 = radius * radius;
  final minX = (cx - radius).floor().clamp(0, im.width - 1);
  final maxX = (cx + radius).ceil().clamp(0, im.width - 1);
  final minY = (cy - radius).floor().clamp(0, im.height - 1);
  final maxY = (cy + radius).ceil().clamp(0, im.height - 1);
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) continue;
      // Soft anti-aliased edge.
      final d = math.sqrt(d2);
      final edge = (radius - d).clamp(0, 1.5) / 1.5;
      final a = opacity * edge;
      _blend(im, x, y, color, a);
    }
  }
}

void _fillRect(img.Image im, int x0, int y0, int x1, int y1, List<int> color,
    {double opacity = 1.0}) {
  for (var y = y0; y <= y1; y++) {
    if (y < 0 || y >= im.height) continue;
    for (var x = x0; x <= x1; x++) {
      if (x < 0 || x >= im.width) continue;
      _blend(im, x, y, color, opacity);
    }
  }
}

void _blend(img.Image im, int x, int y, List<int> color, double alpha) {
  if (alpha <= 0) return;
  if (alpha >= 1) {
    im.setPixel(x, y, img.ColorRgb8(color[0], color[1], color[2]));
    return;
  }
  final p = im.getPixel(x, y);
  final r = ((color[0] * alpha) + (p.r * (1 - alpha))).round();
  final g = ((color[1] * alpha) + (p.g * (1 - alpha))).round();
  final b = ((color[2] * alpha) + (p.b * (1 - alpha))).round();
  im.setPixel(x, y, img.ColorRgb8(r, g, b));
}

// Soft circular blur via multiple translucent overlays.
void _glow(img.Image im, double cx, double cy, double radius, List<int> color,
    {double opacity = 0.5}) {
  for (var i = 0; i < 6; i++) {
    final r = radius * (1.0 + i * 0.20);
    _fillCircle(im, cx, cy, r, color, opacity: opacity / (1 + i * 0.8));
  }
}

// ────────────────────────────────────────────────────────────────────
// Brand mark — a sumi-e kasa hat sigil with red sash + face mark.
// ────────────────────────────────────────────────────────────────────

void _drawSigil(img.Image im, double cx, double cy, double radius) {
  // Soft red halo behind the hat
  _glow(im, cx, cy, radius * 1.05, _red, opacity: 0.18);

  // Kasa hat — dark ink circle
  _fillCircle(im, cx, cy, radius, _ink, opacity: 0.95);

  // Radial creases (lighter brown)
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    final x1 = cx + math.cos(a) * 0;
    final y1 = cy + math.sin(a) * 0;
    final x2 = cx + math.cos(a) * radius * 0.95;
    final y2 = cy + math.sin(a) * radius * 0.95;
    _drawLine(im, x1, y1, x2, y2, [0x30, 0x24, 0x1C], width: radius * 0.012,
        opacity: 0.55);
  }

  // Concentric weave rings
  for (var i = 1; i <= 3; i++) {
    final rr = radius * (0.30 + i * 0.20);
    _drawRing(im, cx, cy, rr, [0x30, 0x24, 0x1C], width: radius * 0.014,
        opacity: 0.4);
  }

  // Outer rim
  _drawRing(im, cx, cy, radius, [0x46, 0x38, 0x2A], width: radius * 0.035,
      opacity: 0.85);

  // Center peak
  _fillCircle(im, cx, cy, radius * 0.10, _ink);
  _fillCircle(im, cx, cy, radius * 0.030, [0xF5, 0xF0, 0xE1], opacity: 0.9);

  // Red sash across hat horizontally
  final sashHalfW = radius * 0.85;
  final sashHalfH = radius * 0.07;
  _fillRect(im, (cx - sashHalfW).floor(), (cy - sashHalfH).floor(),
      (cx + sashHalfW).ceil(), (cy + sashHalfH).ceil(), _red, opacity: 0.95);

  // Sash highlight band
  _fillRect(im, (cx - sashHalfW + 4).floor(), (cy - sashHalfH * 0.5).floor(),
      (cx + sashHalfW - 4).ceil(),
      (cy - sashHalfH * 0.15).ceil(), _redBright,
      opacity: 0.55);

  // Forward face mark (small red disc above center)
  _fillCircle(im, cx, cy - radius * 0.25, radius * 0.085, _red, opacity: 0.95);
}

void _drawRing(img.Image im, double cx, double cy, double radius,
    List<int> color,
    {double width = 1, double opacity = 1.0}) {
  final r2Outer = math.pow(radius + width / 2, 2);
  final r2Inner = math.pow(radius - width / 2, 2);
  final minX = (cx - radius - width).floor().clamp(0, im.width - 1);
  final maxX = (cx + radius + width).ceil().clamp(0, im.width - 1);
  final minY = (cy - radius - width).floor().clamp(0, im.height - 1);
  final maxY = (cy + radius + width).ceil().clamp(0, im.height - 1);
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2Outer || d2 < r2Inner) continue;
      _blend(im, x, y, color, opacity);
    }
  }
}

void _drawLine(img.Image im, double x0, double y0, double x1, double y1,
    List<int> color,
    {double width = 1, double opacity = 1.0}) {
  final steps = (math.max((x1 - x0).abs(), (y1 - y0).abs())).ceil();
  for (var i = 0; i <= steps; i++) {
    final t = steps == 0 ? 0.0 : i / steps;
    final x = x0 + (x1 - x0) * t;
    final y = y0 + (y1 - y0) * t;
    _fillCircle(im, x, y, width / 2, color, opacity: opacity);
  }
}

// ────────────────────────────────────────────────────────────────────
// Public writers
// ────────────────────────────────────────────────────────────────────

void _writeIcon(String path, int size, {double padding = 0.10}) {
  final im = _newPaperImage(size, size);
  final cx = size / 2.0;
  final cy = size / 2.0;
  final radius = (size / 2.0) * (1.0 - padding);
  _drawSigil(im, cx, cy, radius);
  _grain(im, amp: 3);

  Directory(File(path).parent.path).createSync(recursive: true);
  File(path).writeAsBytesSync(img.encodePng(im));
  print('  wrote $path (${size}×$size)');
}

void _writeOgImage(String path) {
  const w = 1200, h = 630;
  final im = _newPaperImage(w, h);

  // Distant red sun (behind right sigil)
  _glow(im, 920, 250, 220, _red, opacity: 0.45);

  // Mountain silhouettes — atmosphere
  _drawMountains(im, w, h);

  // Big sigil — the brand
  _drawSigil(im, 920, h / 2.0, 220);

  // Three sumi-e brushstrokes on the left suggesting calligraphy without
  // bundling a font. Render as deliberate ink arcs (a vertical, a horizontal
  // sweep, a diagonal flick — abstract "title" composition).
  _brushStroke(im, 120, 140, 260, 360, _ink, width: 32, jitter: 8);
  _brushStroke(im, 340, 160, 360, 360, _ink, width: 28, jitter: 6);
  _brushStroke(im, 130, 380, 380, 410, _red, width: 18, jitter: 4);

  // Small decorative ink rule near the bottom
  _drawLine(im, 120, 480, 740, 480, _ink, width: 3, opacity: 0.55);
  _fillCircle(im, 120, 480, 5, _red, opacity: 0.85);
  _fillCircle(im, 740, 480, 5, _red, opacity: 0.85);

  _grain(im, amp: 4);
  Directory(File(path).parent.path).createSync(recursive: true);
  File(path).writeAsBytesSync(img.encodePng(im));
  print('  wrote $path (1200×630)');
}

/// Mountain silhouettes — soft ink-wash horizon for the OG card.
void _drawMountains(img.Image im, int w, int h) {
  // Two mountain rows at different y bases.
  final rng = math.Random(91);

  void row(double baseY, List<int> color, double opacity, double peakAmp) {
    for (var x = 0; x < w; x += 2) {
      // Multi-octave-ish height
      final n1 = math.sin(x * 0.006 + 1.3) * 0.5 + 0.5;
      final n2 = math.sin(x * 0.013 + 4.0) * 0.5 + 0.5;
      final n3 = rng.nextDouble() * 0.06;
      final height = (n1 * 0.55 + n2 * 0.35 + n3) * peakAmp;
      final topY = baseY - height;
      // Fill column from top to bottom of image
      for (var y = topY.toInt(); y < h; y++) {
        if (y < 0 || y >= h) continue;
        _blend(im, x, y, color, opacity);
        if (x + 1 < w) _blend(im, x + 1, y, color, opacity);
      }
    }
  }

  // Far range — lighter, higher
  row(h * 0.62, [70, 60, 48], 0.18, 130);
  // Near range — darker, lower
  row(h * 0.74, [40, 30, 24], 0.30, 110);
}

/// Slightly wobbly brush stroke from (x0,y0) → (x1,y1) with width and
/// jittered alpha along the path. Used as decoration.
void _brushStroke(img.Image im, double x0, double y0, double x1, double y1,
    List<int> color,
    {double width = 20, double jitter = 4}) {
  final rng = math.Random((x0 * 7 + y0 * 13 + x1 * 31).round());
  final steps = math.max((x1 - x0).abs(), (y1 - y0).abs()).ceil();
  for (var i = 0; i <= steps; i++) {
    final t = steps == 0 ? 0.0 : i / steps;
    // Taper: thicker in middle, thinner at ends.
    final taper = math.sin(t * math.pi);
    final w = (width * (0.4 + 0.6 * taper));
    final jx = (rng.nextDouble() - 0.5) * jitter;
    final jy = (rng.nextDouble() - 0.5) * jitter;
    final x = x0 + (x1 - x0) * t + jx;
    final y = y0 + (y1 - y0) * t + jy;
    final alpha = 0.85 + rng.nextDouble() * 0.12;
    _fillCircle(im, x, y, w / 2, color, opacity: alpha);
  }
}
