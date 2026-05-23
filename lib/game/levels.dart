import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'components/demon.dart';
import 'components/hazards.dart';
import 'components/items.dart';

class StarThresholds {
  const StarThresholds({required this.three, required this.two});
  final double three; // seconds — at or below ⇒ 3 stars
  final double two;   // seconds — at or below ⇒ 2 stars (else 1)
}

class LevelData {
  const LevelData({
    required this.id,
    required this.name,
    required this.thresholds,
    required this.demons,
    required this.hazards,
    required this.items,
  });

  final String id;
  final String name;
  final StarThresholds thresholds;
  final List<Demon> Function(double w, double h) demons;
  final List<Hazard> Function(double w, double h) hazards;
  final List<ItemPickup> Function(double w, double h) items;
}

/// Parses a single level JSON string. Used by the editor's test mode
/// to inject in-memory levels without going through the asset bundle.
LevelData parseLevelJson(String raw, {String id = 'editor_test'}) {
  return _parseLevel(id: id, raw: raw);
}

/// Loads `assets/levels/manifest.json` and the listed level files.
Future<List<LevelData>> loadLevels() async {
  final manifestRaw = await rootBundle.loadString('assets/levels/manifest.json');
  final manifest = json.decode(manifestRaw) as Map<String, dynamic>;
  final files = (manifest['levels'] as List).cast<String>();
  final out = <LevelData>[];
  for (final f in files) {
    final raw = await rootBundle.loadString('assets/levels/$f');
    out.add(_parseLevel(id: f.replaceAll('.json', ''), raw: raw));
  }
  return out;
}

LevelData _parseLevel({required String id, required String raw}) {
  final m = json.decode(raw) as Map<String, dynamic>;
  final thresholds = (m['starThresholds'] as Map<String, dynamic>?) ??
      const {'three': 8.0, 'two': 12.0};
  return LevelData(
    id: id,
    name: m['name'] as String? ?? id,
    thresholds: StarThresholds(
      three: (thresholds['three'] as num).toDouble(),
      two: (thresholds['two'] as num).toDouble(),
    ),
    demons: (w, h) => _parseDemons(m['demons'] as List? ?? const [], w, h),
    hazards: (w, h) => _parseHazards(m['hazards'] as List? ?? const [], w, h),
    items: (w, h) => _parseItems(m['items'] as List? ?? const [], w, h),
  );
}

double _num(Map<String, dynamic> m, String key, [double def = 0]) =>
    (m[key] as num?)?.toDouble() ?? def;
int _int(Map<String, dynamic> m, String key, [int def = 0]) =>
    (m[key] as num?)?.toInt() ?? def;

List<Demon> _parseDemons(List entries, double w, double h) {
  final out = <Demon>[];
  for (final e in entries.cast<Map<String, dynamic>>()) {
    final kind = e['kind'] as String;
    final x = _num(e, 'x') * w;
    final y = _num(e, 'y') * h;
    switch (kind) {
      case 'regular':
        out.add(Demon(
          position: Vector2(x, y),
          requiredNumber: _int(e, 'requiredNumber'),
        ));
        break;
      case 'patrol':
        out.add(PatrolDemon(
          position: Vector2(x, y),
          endPoint: Vector2(_num(e, 'endX') * w, _num(e, 'endY') * h),
          speed: _num(e, 'speed', 95),
          requiredNumber: _int(e, 'requiredNumber'),
        ));
        break;
      case 'orbital':
        out.add(OrbitalDemon(
          orbitCenter: Vector2(_num(e, 'centerX') * w, _num(e, 'centerY') * h),
          radius: _num(e, 'radius', 110),
          angularSpeed: _num(e, 'angularSpeed', 1.4),
          startPhase: _num(e, 'startPhase'),
          requiredNumber: _int(e, 'requiredNumber'),
        ));
        break;
      case 'turret':
        out.add(TurretDemon(
          position: Vector2(x, y),
          fireInterval: _num(e, 'fireInterval', 2.6),
          firePhase: _num(e, 'firePhase'),
          requiredNumber: _int(e, 'requiredNumber'),
        ));
        break;
      default:
        // Unknown kind: skip silently.
        break;
    }
  }
  return out;
}

List<Hazard> _parseHazards(List entries, double w, double h) {
  final out = <Hazard>[];
  for (final e in entries.cast<Map<String, dynamic>>()) {
    final kind = e['kind'] as String;
    final x = _num(e, 'x') * w;
    final y = _num(e, 'y') * h;
    switch (kind) {
      case 'wall':
        out.add(Wall(
          position: Vector2(x, y),
          halfExtents: Vector2(_num(e, 'halfW', 80), _num(e, 'halfH', 28)),
        ));
        break;
      case 'wisp':
        out.add(Wisp(position: Vector2(x, y)));
        break;
      case 'wispPatrol':
        out.add(WispPatrol(
          position: Vector2(x, y),
          endPoint: Vector2(_num(e, 'endX') * w, _num(e, 'endY') * h),
          speed: _num(e, 'speed', 100),
        ));
        break;
      case 'spikeField':
        out.add(SpikeField(
          position: Vector2(x, y),
          halfExtents: Vector2(_num(e, 'halfW', 100), _num(e, 'halfH', 30)),
          cycleDur: _num(e, 'cycleDur', 2.8),
          deadlyFraction: _num(e, 'deadlyFraction', 0.55),
          startPhase: _num(e, 'startPhase'),
        ));
        break;
      default:
        break;
    }
  }
  return out;
}

List<ItemPickup> _parseItems(List entries, double w, double h) {
  final out = <ItemPickup>[];
  for (final e in entries.cast<Map<String, dynamic>>()) {
    final kind = e['kind'] as String;
    final x = _num(e, 'x') * w;
    final y = _num(e, 'y') * h;
    final p = switch (kind) {
      'dragon' => PowerUp.dragon,
      'slow' => PowerUp.slow,
      'ghost' => PowerUp.ghost,
      _ => null,
    };
    if (p == null) continue;
    out.add(ItemPickup(position: Vector2(x, y), kind: p));
  }
  return out;
}
