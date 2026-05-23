import 'dart:math' as math;

import 'editor_state.dart';

/// Runs the same kind of solvability checks the procgen validator runs,
/// but on the editor's [LevelDoc]. Returns a list of human-readable
/// issues; an empty list means valid.
List<String> validateLevelDoc(LevelDoc doc) {
  final issues = <String>[];

  // Pull entities by category once.
  final demons =
      doc.entities.where((e) => e.category == 'demon').toList();
  final hazards =
      doc.entities.where((e) => e.category == 'hazard').toList();

  // 1. Must have at least one demon.
  if (demons.isEmpty) {
    issues.add('no demons — gate condition is met instantly');
  }

  // 2. Overlap checks (in fraction-space; ~0.10 of world is roughly 110 px).
  for (var i = 0; i < demons.length; i++) {
    for (var j = i + 1; j < demons.length; j++) {
      final a = demons[i];
      final b = demons[j];
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      // 110 / 1080 ~ 0.10
      if (dx * dx + dy * dy < 0.10 * 0.10) {
        issues.add('demons overlap (${a.kind} and ${b.kind})');
      }
    }
  }

  // 3. Numbered demons feasibility.
  var maxReq = 0;
  for (final d in demons) {
    final req = (d.props['requiredNumber'] as num?)?.toInt() ?? 0;
    if (req > maxReq) maxReq = req;
  }
  if (maxReq >= demons.length) {
    issues.add(
        'numbered demon needs $maxReq prior kills but only ${demons.length} demons exist');
  }

  // 4. Topological numbered-gating: a forward-only path (Y descending —
  // closer to spawn first) should be able to satisfy each numbered demon.
  final byY = [...demons]..sort((a, b) => b.y.compareTo(a.y));
  var killable = 0;
  for (final d in byY) {
    final req = (d.props['requiredNumber'] as num?)?.toInt() ?? 0;
    if (req > killable) {
      issues.add(
          'numbered ${d.kind} (req $req) at y=${d.y.toStringAsFixed(2)} cannot be reached in any forward order');
    }
    killable++;
  }

  // 5. Demons / items embedded in walls or spike fields.
  bool insideRect(double px, double py, EditorEntity rect, double pad) {
    final rx = rect.x;
    final ry = rect.y;
    final hw = ((rect.props['halfW'] as num?)?.toDouble() ?? 0) / 1080;
    final hh = ((rect.props['halfH'] as num?)?.toDouble() ?? 0) / 1920;
    return (px - rx).abs() < hw + pad && (py - ry).abs() < hh + pad;
  }

  for (final h in hazards) {
    if (h.kind != 'wall' && h.kind != 'spikeField') continue;
    for (final d in demons) {
      if (insideRect(d.x, d.y, h, 0.025)) {
        issues.add('${d.kind} embedded inside ${h.kind}');
      }
    }
    for (final it
        in doc.entities.where((e) => e.category == 'item')) {
      if (insideRect(it.x, it.y, h, 0.020)) {
        issues.add('item ${it.kind} embedded inside ${h.kind}');
      }
    }
  }

  // 6. BFS reachability — coarse grid, walls + spikes block.
  if (!_reachable(demons, hazards)) {
    issues.add('no path from spawn (50,84%) to gate (50,14%) — walls/spikes block all routes');
  }

  return issues;
}

bool _reachable(List<EditorEntity> demons, List<EditorEntity> hazards) {
  // 27×48 grid (40-px cells in 1080×1920 world); fractions normalized.
  const cols = 27;
  const rows = 48;
  final blocked = List.generate(rows, (_) => List<bool>.filled(cols, false));

  void blockRect(double cx, double cy, double hwFrac, double hhFrac) {
    final minX = ((cx - hwFrac) * cols).floor().clamp(0, cols - 1);
    final maxX = ((cx + hwFrac) * cols).ceil().clamp(0, cols - 1);
    final minY = ((cy - hhFrac) * rows).floor().clamp(0, rows - 1);
    final maxY = ((cy + hhFrac) * rows).ceil().clamp(0, rows - 1);
    for (var r = minY; r <= maxY; r++) {
      for (var c = minX; c <= maxX; c++) {
        blocked[r][c] = true;
      }
    }
  }

  for (final h in hazards) {
    if (h.kind == 'wall' || h.kind == 'spikeField') {
      final hw = ((h.props['halfW'] as num?)?.toDouble() ?? 0) / 1080;
      final hh = ((h.props['halfH'] as num?)?.toDouble() ?? 0) / 1920;
      blockRect(h.x, h.y, hw, hh);
    }
  }

  final startCol = (0.5 * cols).floor();
  final startRow = (0.84 * rows).floor();
  final endCol = (0.5 * cols).floor();
  final endRow = (0.14 * rows).floor();
  if (blocked[startRow][startCol] || blocked[endRow][endCol]) return false;

  final visited = List.generate(rows, (_) => List<bool>.filled(cols, false));
  final q = <List<int>>[
    [startCol, startRow]
  ];
  visited[startRow][startCol] = true;
  const dirs = <List<int>>[
    [1, 0], [-1, 0], [0, 1], [0, -1],
    [1, 1], [1, -1], [-1, 1], [-1, -1],
  ];
  while (q.isNotEmpty) {
    final cur = q.removeAt(0);
    final cx = cur[0], cy = cur[1];
    if (cx == endCol && cy == endRow) return true;
    for (final d in dirs) {
      final nx = cx + d[0];
      final ny = cy + d[1];
      if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;
      if (blocked[ny][nx]) continue;
      if (visited[ny][nx]) continue;
      visited[ny][nx] = true;
      q.add([nx, ny]);
    }
  }
  // Suppress lint about unused math import in case we drop Distance later
  math.max(0, 0);
  return false;
}
