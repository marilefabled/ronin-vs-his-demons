import 'package:flutter/material.dart';

import 'editor_state.dart';

class EntityPalette extends StatefulWidget {
  const EntityPalette({super.key, required this.placement});

  final PlacementMode placement;

  @override
  State<EntityPalette> createState() => _EntityPaletteState();
}

class _EntityPaletteState extends State<EntityPalette> {
  @override
  void initState() {
    super.initState();
    widget.placement.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.placement.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF1F1A14),
        border: Border(
          right: BorderSide(color: Color(0xFF2D2620), width: 1),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(label: 'palette'),
          const SizedBox(height: 4),
          const _Note(text: 'click → arm · click canvas to drop'),
          const SizedBox(height: 12),
          _Group(label: 'demons', children: [
            _PaletteTile(
              category: 'demon',
              kind: 'regular',
              label: 'regular',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'demon',
              kind: 'patrol',
              label: 'patrol',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'demon',
              kind: 'orbital',
              label: 'orbital',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'demon',
              kind: 'turret',
              label: 'turret',
              placement: widget.placement,
            ),
          ]),
          const SizedBox(height: 14),
          _Group(label: 'hazards', children: [
            _PaletteTile(
              category: 'hazard',
              kind: 'wall',
              label: 'wall',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'hazard',
              kind: 'wisp',
              label: 'wisp',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'hazard',
              kind: 'wispPatrol',
              label: 'wisp patrol',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'hazard',
              kind: 'spikeField',
              label: 'spike field',
              placement: widget.placement,
            ),
          ]),
          const SizedBox(height: 14),
          _Group(label: 'items', children: [
            _PaletteTile(
              category: 'item',
              kind: 'dragon',
              label: 'dragon',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'item',
              kind: 'slow',
              label: 'slow',
              placement: widget.placement,
            ),
            _PaletteTile(
              category: 'item',
              kind: 'ghost',
              label: 'ghost',
              placement: widget.placement,
            ),
          ]),
          const SizedBox(height: 22),
          if (widget.placement.active) ...[
            ElevatedButton(
              onPressed: () => widget.placement.clear(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA72920),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              child: const Text('cancel placement'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB8A78A),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.category,
    required this.kind,
    required this.label,
    required this.placement,
  });

  final String category;
  final String kind;
  final String label;
  final PlacementMode placement;

  @override
  Widget build(BuildContext context) {
    final selected = placement.category == category && placement.kind == kind;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? const Color(0xFFA72920)
            : const Color(0xFF2A2520),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => placement.set(category, kind),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _CategoryDot(category: category, kind: kind),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : const Color(0xFFEDE2CE),
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.category, required this.kind});
  final String category;
  final String kind;

  Color get _color {
    if (category == 'demon') return const Color(0xFF1A1612);
    if (category == 'hazard') {
      if (kind == 'wall' || kind == 'spikeField') {
        return const Color(0xFF5A2A1A);
      }
      return const Color(0xFF82D8C8);
    }
    // items
    if (kind == 'dragon') return const Color(0xFFD45438);
    if (kind == 'slow') return const Color(0xFF5BA8C8);
    return const Color(0xFFA48ABE);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF000000), width: 0.5),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFEDE2CE),
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 6,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8A7E68),
        fontSize: 11,
        fontStyle: FontStyle.italic,
        letterSpacing: 1.2,
      ),
    );
  }
}
