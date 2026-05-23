import 'dart:convert';
import 'dart:math' as math;

/// Procedurally generates a single level JSON string. Difficulty 1..10
/// scales counts and complexity. Validation rejects unwinnable layouts;
/// up to [maxAttempts] retries before falling back to a known-good level.
class ProcGen {
  ProcGen({required this.seed, required this.difficulty});

  final int seed;
  final int difficulty;

  static const int maxAttempts = 60;

  String generateJson() {
    final rng = math.Random(seed);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final cand = _Candidate(name: _name(rng))
        .._build(rng, _params(difficulty));
      final issues = _validate(cand);
      if (issues.isEmpty) return _serialize(cand);
    }
    return _serialize(_fallback());
  }

  // ---------- difficulty ----------

  _Params _params(int d) {
    final c = d.clamp(1, 10);
    return _Params(
      regulars: 2 + (c / 2).round(),                 // 2..7
      patrols: c >= 3 ? math.min(2, (c / 4).round()) : 0,
      orbitals: c >= 4 ? math.min(2, ((c - 3) / 3).round()) : 0,
      turrets: c >= 5 ? math.min(2, ((c - 4) / 3).round()) : 0,
      numberedReq: c >= 3 ? math.min(c - 1, 2 + (c - 3) ~/ 2) : 0,
      walls: c >= 4 ? math.min(2, (c - 3) ~/ 2) : 0,
      wisps: c >= 6 ? math.min(2, (c - 5) ~/ 2) : 0,
      spikes: c >= 7 ? 1 : 0,
      items: c >= 5 ? math.min(2, (c - 4) ~/ 2) : 0,
      threeStarSec: 5.5 + c * 0.7,
      twoStarSec: 8.5 + c * 1.1,
    );
  }

  String _name(math.Random rng) {
    const adjectives = [
      'silent', 'falling', 'broken', 'quiet', 'restless',
      'turning', 'hollow', 'binding', 'thirsty', 'patient',
    ];
    const nouns = [
      'rain', 'crow', 'lantern', 'circle', 'breath',
      'thread', 'shadow', 'season', 'name', 'wound',
    ];
    final a = adjectives[rng.nextInt(adjectives.length)];
    final n = nouns[rng.nextInt(nouns.length)];
    return '$a $n';
  }

  // ---------- validation ----------

  static const _gridCols = 27;
  static const _gridRows = 48;
  static const _cellW = 1080.0 / _gridCols; // 40
  static const _cellH = 1920.0 / _gridRows; // 40

  /// Returns a list of validation issues. Empty list means valid.
  static List<String> _validate(_Candidate c) {
    final issues = <String>[];

    // 1. Must have at least one demon (else gate condition demonsAlive==0
    // is satisfied at start and the player can't actually clear).
    if (c.demons.isEmpty) issues.add('no demons');

    // 2. Pairwise demon spacing (avoid stacked-on-top spawns).
    for (var i = 0; i < c.demons.length; i++) {
      for (var j = i + 1; j < c.demons.length; j++) {
        final dx = c.demons[i].x - c.demons[j].x;
        final dy = c.demons[i].y - c.demons[j].y;
        const minD = 110.0;
        if (dx * dx + dy * dy < minD * minD) {
          issues.add('demon overlap');
        }
      }
    }

    // 3. Numbered demon's required count must be < total demons (else
    // unreachable count threshold).
    var maxReq = 0;
    for (final d in c.demons) {
      if (d.requiredNumber > maxReq) maxReq = d.requiredNumber;
    }
    if (maxReq >= c.demons.length) {
      issues.add('numbered req $maxReq >= demons ${c.demons.length}');
    }

    // 4. Numbered demons must have enough non-numbered (or lower-numbered)
    // demons strictly closer to spawn (higher y) than them, so a forward
    // path can hit those first.
    for (final d in c.demons) {
      if (d.requiredNumber == 0) continue;
      final earlier = c.demons
          .where((o) => identical(o, d) ? false : o.y > d.y)
          .toList();
      // Of the earlier demons, count those whose own requirement we
      // could already satisfy by then (greedy assumption).
      earlier.sort((a, b) => b.y.compareTo(a.y));
      var killable = 0;
      for (final o in earlier) {
        if (o.requiredNumber <= killable) killable++;
      }
      if (killable < d.requiredNumber) {
        issues.add('numbered demon unreachable in topological order');
      }
    }

    // 5. Demons / items not embedded in walls or spike fields.
    bool insideRect(double px, double py, double rx, double ry, double hw, double hh) {
      return (px - rx).abs() < hw && (py - ry).abs() < hh;
    }

    for (final d in c.demons) {
      for (final w in c.walls) {
        if (insideRect(d.x, d.y, w.x, w.y, w.halfW + 30, w.halfH + 30)) {
          issues.add('demon inside wall');
        }
      }
      for (final s in c.spikes) {
        if (insideRect(d.x, d.y, s.x, s.y, s.halfW + 30, s.halfH + 30)) {
          issues.add('demon inside spike field');
        }
      }
    }
    for (final it in c.items) {
      for (final w in c.walls) {
        if (insideRect(it.x, it.y, w.x, w.y, w.halfW + 24, w.halfH + 24)) {
          issues.add('item inside wall');
        }
      }
      for (final s in c.spikes) {
        if (insideRect(it.x, it.y, s.x, s.y, s.halfW + 20, s.halfH + 20)) {
          issues.add('item inside spike field');
        }
      }
    }

    // 6. BFS reachability — spawn → gate avoiding walls + spike fields.
    // Spike fields treated as worst-case always-on for safety.
    if (!_reachable(c)) issues.add('no path spawn → gate');

    // 7. Spawn area + gate area not blocked.
    for (final w in c.walls) {
      if (insideRect(540, 1612, w.x, w.y, w.halfW + 60, w.halfH + 60)) {
        issues.add('wall blocks spawn');
      }
      if (insideRect(540, 268, w.x, w.y, w.halfW + 60, w.halfH + 60)) {
        issues.add('wall blocks gate');
      }
    }

    return issues;
  }

  static bool _reachable(_Candidate c) {
    final blocked = List.generate(_gridRows, (_) => List<bool>.filled(_gridCols, false));
    void blockRect(double x, double y, double hw, double hh) {
      final minX = ((x - hw) / _cellW).floor().clamp(0, _gridCols - 1);
      final maxX = ((x + hw) / _cellW).ceil().clamp(0, _gridCols - 1);
      final minY = ((y - hh) / _cellH).floor().clamp(0, _gridRows - 1);
      final maxY = ((y + hh) / _cellH).ceil().clamp(0, _gridRows - 1);
      for (var r = minY; r <= maxY; r++) {
        for (var col = minX; col <= maxX; col++) {
          blocked[r][col] = true;
        }
      }
    }

    for (final w in c.walls) blockRect(w.x, w.y, w.halfW, w.halfH);
    for (final s in c.spikes) blockRect(s.x, s.y, s.halfW, s.halfH);

    final startCol = (540 / _cellW).floor();
    final startRow = (1612 / _cellH).floor();
    final endCol = (540 / _cellW).floor();
    final endRow = (268 / _cellH).floor();

    if (blocked[startRow][startCol] || blocked[endRow][endCol]) return false;

    final visited = List.generate(_gridRows, (_) => List<bool>.filled(_gridCols, false));
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
        if (nx < 0 || nx >= _gridCols || ny < 0 || ny >= _gridRows) continue;
        if (blocked[ny][nx]) continue;
        if (visited[ny][nx]) continue;
        visited[ny][nx] = true;
        q.add([nx, ny]);
      }
    }
    return false;
  }

  // ---------- serialization ----------

  String _serialize(_Candidate c) {
    final demons = c.demons.map(_demonToJson).toList();
    final hazards = <Map<String, dynamic>>[
      ...c.walls.map((w) => {
            'kind': 'wall',
            'x': _frac(w.x, 1080),
            'y': _frac(w.y, 1920),
            'halfW': w.halfW,
            'halfH': w.halfH,
          }),
      ...c.wisps.map((w) => {
            'kind': w.patrolEndX != null ? 'wispPatrol' : 'wisp',
            'x': _frac(w.x, 1080),
            'y': _frac(w.y, 1920),
            if (w.patrolEndX != null) 'endX': _frac(w.patrolEndX!, 1080),
            if (w.patrolEndY != null) 'endY': _frac(w.patrolEndY!, 1920),
            if (w.speed != null) 'speed': w.speed,
          }),
      ...c.spikes.map((s) => {
            'kind': 'spikeField',
            'x': _frac(s.x, 1080),
            'y': _frac(s.y, 1920),
            'halfW': s.halfW,
            'halfH': s.halfH,
            'cycleDur': s.cycleDur,
          }),
    ];
    final items = c.items
        .map((it) => {
              'kind': it.kind,
              'x': _frac(it.x, 1080),
              'y': _frac(it.y, 1920),
            })
        .toList();
    final out = {
      'name': c.name,
      'starThresholds': {
        'three': c.threeStarSec,
        'two': c.twoStarSec,
      },
      'demons': demons,
      'hazards': hazards,
      'items': items,
    };
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  Map<String, dynamic> _demonToJson(_Demon d) {
    final m = <String, dynamic>{
      'kind': d.kind,
      'x': _frac(d.x, 1080),
      'y': _frac(d.y, 1920),
    };
    if (d.requiredNumber > 0) m['requiredNumber'] = d.requiredNumber;
    if (d.kind == 'patrol') {
      m['endX'] = _frac(d.endX!, 1080);
      m['endY'] = _frac(d.endY!, 1920);
      m['speed'] = d.speed;
    }
    if (d.kind == 'orbital') {
      m['centerX'] = _frac(d.centerX!, 1080);
      m['centerY'] = _frac(d.centerY!, 1920);
      m['radius'] = d.radius;
      m['angularSpeed'] = d.angularSpeed;
    }
    if (d.kind == 'turret') {
      m['fireInterval'] = d.fireInterval;
      if (d.firePhase > 0) m['firePhase'] = d.firePhase;
    }
    return m;
  }

  static double _frac(double v, double total) =>
      double.parse((v / total).toStringAsFixed(3));

  _Candidate _fallback() {
    final c = _Candidate(name: 'still circle');
    c.demons.addAll([
      _Demon(kind: 'regular', x: 540 * 0.30, y: 1920 * 0.72),
      _Demon(kind: 'regular', x: 540 * 1.40, y: 1920 * 0.72),
      _Demon(kind: 'regular', x: 540, y: 1920 * 0.40),
    ]);
    c.threeStarSec = 6.0;
    c.twoStarSec = 9.0;
    return c;
  }
}

class _Params {
  _Params({
    required this.regulars,
    required this.patrols,
    required this.orbitals,
    required this.turrets,
    required this.numberedReq,
    required this.walls,
    required this.wisps,
    required this.spikes,
    required this.items,
    required this.threeStarSec,
    required this.twoStarSec,
  });
  final int regulars, patrols, orbitals, turrets, numberedReq;
  final int walls, wisps, spikes, items;
  final double threeStarSec, twoStarSec;
}

class _Candidate {
  _Candidate({required this.name});
  String name;
  final List<_Demon> demons = [];
  final List<_Wall> walls = [];
  final List<_Wisp> wisps = [];
  final List<_Spike> spikes = [];
  final List<_Item> items = [];
  double threeStarSec = 8.0;
  double twoStarSec = 12.0;

  void _build(math.Random rng, _Params p) {
    threeStarSec = p.threeStarSec;
    twoStarSec = p.twoStarSec;

    // Walls go first so we know the topology.
    for (var i = 0; i < p.walls; i++) {
      // Walls in mid-band, leaving an open lane on at least one side.
      final side = rng.nextBool() ? -1 : 1;
      final cx = 540 + side * (140 + rng.nextDouble() * 110);
      final cy = 1920 * (0.45 + rng.nextDouble() * 0.20);
      walls.add(_Wall(
        x: cx,
        y: cy,
        halfW: 60 + rng.nextDouble() * 70,
        halfH: 22 + rng.nextDouble() * 12,
      ));
    }

    // Spike fields — central horizontal bar with timing
    for (var i = 0; i < p.spikes; i++) {
      spikes.add(_Spike(
        x: 540,
        y: 1920 * (0.30 + rng.nextDouble() * 0.10),
        halfW: 110 + rng.nextDouble() * 80,
        halfH: 24 + rng.nextDouble() * 8,
        cycleDur: 2.4 + rng.nextDouble() * 1.0,
      ));
    }

    // Wisps — patrols spanning mid-field
    for (var i = 0; i < p.wisps; i++) {
      final patrol = rng.nextBool();
      final cy = 1920 * (0.34 + rng.nextDouble() * 0.10);
      if (patrol) {
        wisps.add(_Wisp(
          x: 1080 * (0.18 + rng.nextDouble() * 0.05),
          y: cy,
          patrolEndX: 1080 * (0.78 + rng.nextDouble() * 0.05),
          patrolEndY: cy,
          speed: 110 + rng.nextDouble() * 60,
        ));
      } else {
        wisps.add(_Wisp(
          x: 1080 * (0.22 + rng.nextDouble() * 0.56),
          y: cy,
        ));
      }
    }

    // Demons in vertical bands — bottom (closer to spawn) for regulars
    final bandBottom = (0.62, 0.78);
    final bandMid = (0.42, 0.58);
    final bandTop = (0.18, 0.32);

    void placeDemonIn((double, double) band, _Demon d, {int maxTries = 12}) {
      for (var t = 0; t < maxTries; t++) {
        final x = 1080 * (0.14 + rng.nextDouble() * 0.72);
        final y = 1920 * (band.$1 + rng.nextDouble() * (band.$2 - band.$1));
        d.x = x;
        d.y = y;
        var ok = true;
        for (final other in demons) {
          final dx = other.x - x, dy = other.y - y;
          if (dx * dx + dy * dy < 130 * 130) {
            ok = false;
            break;
          }
        }
        for (final w in walls) {
          if ((x - w.x).abs() < w.halfW + 36 &&
              (y - w.y).abs() < w.halfH + 36) {
            ok = false;
            break;
          }
        }
        for (final s in spikes) {
          if ((x - s.x).abs() < s.halfW + 36 &&
              (y - s.y).abs() < s.halfH + 36) {
            ok = false;
            break;
          }
        }
        if (ok) return;
      }
    }

    // Place regulars across all 3 bands, weighted toward bottom
    final regulars = p.regulars;
    final inBottom = (regulars * 0.55).round().clamp(1, regulars);
    final inMid = ((regulars - inBottom) * 0.6).round();
    final inTop = regulars - inBottom - inMid;

    for (var i = 0; i < inBottom; i++) {
      final d = _Demon(kind: 'regular', x: 0, y: 0);
      placeDemonIn(bandBottom, d);
      demons.add(d);
    }
    for (var i = 0; i < inMid; i++) {
      final d = _Demon(kind: 'regular', x: 0, y: 0);
      placeDemonIn(bandMid, d);
      demons.add(d);
    }
    for (var i = 0; i < inTop; i++) {
      final d = _Demon(kind: 'regular', x: 0, y: 0);
      placeDemonIn(bandTop, d);
      demons.add(d);
    }

    // Patrols across mid-field
    for (var i = 0; i < p.patrols; i++) {
      final y = 1920 * (0.46 + rng.nextDouble() * 0.10);
      final d = _Demon(kind: 'patrol', x: 1080 * 0.20, y: y)
        ..endX = 1080 * 0.80
        ..endY = y
        ..speed = 100 + rng.nextDouble() * 40;
      demons.add(d);
    }

    // Orbital demons
    for (var i = 0; i < p.orbitals; i++) {
      final cx = 1080 * (0.30 + rng.nextDouble() * 0.40);
      final cy = 1920 * (0.40 + rng.nextDouble() * 0.10);
      final radius = 80 + rng.nextDouble() * 60;
      final d = _Demon(kind: 'orbital', x: cx + radius, y: cy)
        ..centerX = cx
        ..centerY = cy
        ..radius = radius
        ..angularSpeed = 1.2 + rng.nextDouble() * 0.6;
      demons.add(d);
    }

    // Turrets at the top corners
    for (var i = 0; i < p.turrets; i++) {
      final left = i % 2 == 0;
      final d = _Demon(
        kind: 'turret',
        x: 1080 * (left ? 0.16 : 0.84),
        y: 1920 * (0.28 + rng.nextDouble() * 0.06),
      )
        ..fireInterval = 2.2 + rng.nextDouble() * 0.6
        ..firePhase = i * 1.1;
      demons.add(d);
    }

    // Numbered demon near gate
    if (p.numberedReq > 0 && demons.length > p.numberedReq) {
      final d = _Demon(
        kind: 'regular',
        x: 1080 * (0.40 + rng.nextDouble() * 0.20),
        y: 1920 * (0.16 + rng.nextDouble() * 0.06),
        requiredNumber: p.numberedReq,
      );
      demons.add(d);
    }

    // Items in the middle — placeholder, then nudge if blocked
    const itemKinds = ['slow', 'dragon', 'ghost'];
    for (var i = 0; i < p.items; i++) {
      var x = 1080 * (0.30 + rng.nextDouble() * 0.40);
      var y = 1920 * (0.40 + rng.nextDouble() * 0.20);
      // bump once if conflicting with anything obvious
      for (final w in walls) {
        if ((x - w.x).abs() < w.halfW + 36 &&
            (y - w.y).abs() < w.halfH + 36) {
          x = 1080 * 0.50;
          y = 1920 * 0.62;
          break;
        }
      }
      items.add(_Item(
        kind: itemKinds[rng.nextInt(itemKinds.length)],
        x: x,
        y: y,
      ));
    }
  }
}

class _Demon {
  _Demon({
    required this.kind,
    required this.x,
    required this.y,
    this.requiredNumber = 0,
  });
  String kind;
  double x, y;
  int requiredNumber;
  double? endX, endY;
  double? centerX, centerY;
  double radius = 110;
  double angularSpeed = 1.4;
  double fireInterval = 2.6;
  double firePhase = 0;
  double speed = 95;
}

class _Wall {
  _Wall({
    required this.x,
    required this.y,
    required this.halfW,
    required this.halfH,
  });
  final double x, y, halfW, halfH;
}

class _Wisp {
  _Wisp({
    required this.x,
    required this.y,
    this.patrolEndX,
    this.patrolEndY,
    this.speed,
  });
  final double x, y;
  final double? patrolEndX, patrolEndY, speed;
}

class _Spike {
  _Spike({
    required this.x,
    required this.y,
    required this.halfW,
    required this.halfH,
    required this.cycleDur,
  });
  final double x, y, halfW, halfH, cycleDur;
}

class _Item {
  _Item({required this.kind, required this.x, required this.y});
  final String kind;
  final double x, y;
}
