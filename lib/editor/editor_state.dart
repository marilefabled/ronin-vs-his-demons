import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One placeable thing on the level. Positions are stored as fractions
/// (0..1) of world width/height so they're resolution-independent and
/// match the JSON format the game already loads.
class EditorEntity {
  EditorEntity({
    required this.id,
    required this.category, // 'demon' | 'hazard' | 'item'
    required this.kind,
    required this.props,
  });

  final String id;
  final String category;
  String kind;
  final Map<String, dynamic> props;

  double get x => (props['x'] as num).toDouble();
  set x(double v) => props['x'] = v;
  double get y => (props['y'] as num).toDouble();
  set y(double v) => props['y'] = v;

  Map<String, dynamic> toJson() {
    return {'kind': kind, ...props};
  }

  static EditorEntity fromJson({
    required String id,
    required String category,
    required Map<String, dynamic> j,
  }) {
    final props = Map<String, dynamic>.from(j);
    final kind = props.remove('kind') as String;
    return EditorEntity(
      id: id,
      category: category,
      kind: kind,
      props: props,
    );
  }
}

/// Field schema for properties UI. type is one of:
///   - 'frac'    : 0..1 fraction (x/y/endX/etc) — slider
///   - 'double'  : free double — text field
///   - 'int'     : free int — stepper
///   - 'choice'  : enum dropdown (kind for items)
class FieldSpec {
  const FieldSpec({
    required this.label,
    required this.type,
    required this.defaultValue,
    this.min,
    this.max,
    this.choices,
  });

  final String label;
  final String type;
  final dynamic defaultValue;
  final num? min;
  final num? max;
  final List<String>? choices;
}

/// All entity-kinds and their per-kind property schemas. Common position
/// fields (x, y) are NOT listed here — the canvas handles them.
const Map<String, Map<String, Map<String, FieldSpec>>> kEntitySchema = {
  'demon': {
    'regular': {
      'requiredNumber':
          FieldSpec(label: 'required #', type: 'int', defaultValue: 0, min: 0, max: 10),
    },
    'patrol': {
      'endX': FieldSpec(label: 'end x', type: 'frac', defaultValue: 0.5),
      'endY': FieldSpec(label: 'end y', type: 'frac', defaultValue: 0.5),
      'speed': FieldSpec(label: 'speed', type: 'double', defaultValue: 95.0, min: 30, max: 260),
      'requiredNumber':
          FieldSpec(label: 'required #', type: 'int', defaultValue: 0, min: 0, max: 10),
    },
    'orbital': {
      'centerX': FieldSpec(label: 'center x', type: 'frac', defaultValue: 0.5),
      'centerY': FieldSpec(label: 'center y', type: 'frac', defaultValue: 0.5),
      'radius':
          FieldSpec(label: 'radius', type: 'double', defaultValue: 110.0, min: 30, max: 300),
      'angularSpeed': FieldSpec(
          label: 'angular speed', type: 'double', defaultValue: 1.4, min: -3, max: 3),
      'startPhase': FieldSpec(
          label: 'phase', type: 'double', defaultValue: 0.0, min: 0, max: 6.28),
      'requiredNumber':
          FieldSpec(label: 'required #', type: 'int', defaultValue: 0, min: 0, max: 10),
    },
    'turret': {
      'fireInterval': FieldSpec(
          label: 'fire interval', type: 'double', defaultValue: 2.6, min: 0.4, max: 6),
      'firePhase': FieldSpec(
          label: 'fire phase', type: 'double', defaultValue: 0.0, min: 0, max: 5),
      'requiredNumber':
          FieldSpec(label: 'required #', type: 'int', defaultValue: 0, min: 0, max: 10),
    },
  },
  'hazard': {
    'wall': {
      'halfW': FieldSpec(label: 'half W', type: 'double', defaultValue: 80.0, min: 10, max: 400),
      'halfH': FieldSpec(label: 'half H', type: 'double', defaultValue: 28.0, min: 10, max: 400),
    },
    'wisp': {},
    'wispPatrol': {
      'endX': FieldSpec(label: 'end x', type: 'frac', defaultValue: 0.5),
      'endY': FieldSpec(label: 'end y', type: 'frac', defaultValue: 0.5),
      'speed': FieldSpec(label: 'speed', type: 'double', defaultValue: 100.0, min: 30, max: 260),
    },
    'spikeField': {
      'halfW': FieldSpec(label: 'half W', type: 'double', defaultValue: 100.0, min: 20, max: 400),
      'halfH': FieldSpec(label: 'half H', type: 'double', defaultValue: 30.0, min: 10, max: 400),
      'cycleDur': FieldSpec(
          label: 'cycle dur', type: 'double', defaultValue: 2.8, min: 0.6, max: 8),
      'deadlyFraction': FieldSpec(
          label: 'lethal fraction', type: 'double', defaultValue: 0.55, min: 0.1, max: 0.9),
      'startPhase':
          FieldSpec(label: 'start phase', type: 'double', defaultValue: 0.0, min: 0, max: 8),
    },
  },
  'item': {
    'dragon': {},
    'slow': {},
    'ghost': {},
  },
};

/// Top-level mutable level being edited.
class LevelDoc extends ChangeNotifier {
  String name = 'untitled';
  double thresholdThree = 8.0;
  double thresholdTwo = 12.0;
  final List<EditorEntity> entities = [];

  String? sourcePath; // last save/load location

  EditorEntity? selected;

  String _nextId() => 'e_${DateTime.now().microsecondsSinceEpoch}';

  EditorEntity addEntity({
    required String category,
    required String kind,
    required double x,
    required double y,
  }) {
    final schema = kEntitySchema[category]?[kind] ?? const <String, FieldSpec>{};
    final props = <String, dynamic>{'x': x, 'y': y};
    for (final entry in schema.entries) {
      props[entry.key] = entry.value.defaultValue;
    }
    final e = EditorEntity(
      id: _nextId(),
      category: category,
      kind: kind,
      props: props,
    );
    entities.add(e);
    selected = e;
    notifyListeners();
    return e;
  }

  void removeEntity(EditorEntity e) {
    entities.remove(e);
    if (selected == e) selected = null;
    notifyListeners();
  }

  void clearAll() {
    entities.clear();
    selected = null;
    notifyListeners();
  }

  void select(EditorEntity? e) {
    selected = e;
    notifyListeners();
  }

  void mutateSelected(void Function(EditorEntity e) fn) {
    final s = selected;
    if (s == null) return;
    fn(s);
    notifyListeners();
  }

  /// Public re-emit so external code (canvas drag) can flag a change.
  void bump() => notifyListeners();

  void setName(String v) {
    name = v;
    notifyListeners();
  }

  void setThresholds(double three, double two) {
    thresholdThree = three;
    thresholdTwo = two;
    notifyListeners();
  }

  // ---------- serialization ----------

  String toJsonString() {
    final demons = entities
        .where((e) => e.category == 'demon')
        .map((e) => e.toJson())
        .toList();
    final hazards = entities
        .where((e) => e.category == 'hazard')
        .map((e) => e.toJson())
        .toList();
    final items = entities
        .where((e) => e.category == 'item')
        .map((e) => e.toJson())
        .toList();
    final out = {
      'name': name,
      'starThresholds': {
        'three': thresholdThree,
        'two': thresholdTwo,
      },
      'demons': demons,
      'hazards': hazards,
      'items': items,
    };
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  void loadFromJsonString(String raw, {String? path}) {
    final m = json.decode(raw) as Map<String, dynamic>;
    name = (m['name'] as String?) ?? 'untitled';
    final th = m['starThresholds'] as Map<String, dynamic>?;
    if (th != null) {
      thresholdThree = (th['three'] as num).toDouble();
      thresholdTwo = (th['two'] as num).toDouble();
    }
    entities.clear();
    void absorb(List? list, String category) {
      if (list == null) return;
      for (final raw in list.cast<Map<String, dynamic>>()) {
        entities.add(EditorEntity.fromJson(
          id: _nextId(),
          category: category,
          j: Map<String, dynamic>.from(raw),
        ));
      }
    }

    absorb(m['demons'] as List?, 'demon');
    absorb(m['hazards'] as List?, 'hazard');
    absorb(m['items'] as List?, 'item');
    selected = null;
    sourcePath = path;
    notifyListeners();
  }
}

/// What the palette currently has armed for placement (or null).
class PlacementMode extends ChangeNotifier {
  String? category;
  String? kind;

  bool get active => category != null && kind != null;

  void set(String category, String kind) {
    this.category = category;
    this.kind = kind;
    notifyListeners();
  }

  void clear() {
    category = null;
    kind = null;
    notifyListeners();
  }
}
