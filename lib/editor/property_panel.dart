import 'package:flutter/material.dart';

import 'editor_state.dart';

class PropertyPanel extends StatefulWidget {
  const PropertyPanel({super.key, required this.doc});

  final LevelDoc doc;

  @override
  State<PropertyPanel> createState() => _PropertyPanelState();
}

class _PropertyPanelState extends State<PropertyPanel> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _t3Ctrl;
  late final TextEditingController _t2Ctrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.doc.name);
    _t3Ctrl = TextEditingController(text: widget.doc.thresholdThree.toString());
    _t2Ctrl = TextEditingController(text: widget.doc.thresholdTwo.toString());
    widget.doc.addListener(_onDocChange);
  }

  @override
  void dispose() {
    widget.doc.removeListener(_onDocChange);
    _nameCtrl.dispose();
    _t3Ctrl.dispose();
    _t2Ctrl.dispose();
    super.dispose();
  }

  void _onDocChange() {
    if (_nameCtrl.text != widget.doc.name) {
      _nameCtrl.text = widget.doc.name;
    }
    if (_t3Ctrl.text != widget.doc.thresholdThree.toString()) {
      _t3Ctrl.text = widget.doc.thresholdThree.toString();
    }
    if (_t2Ctrl.text != widget.doc.thresholdTwo.toString()) {
      _t2Ctrl.text = widget.doc.thresholdTwo.toString();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.doc.selected;
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF1F1A14),
        border: Border(
          left: BorderSide(color: Color(0xFF2D2620), width: 1),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('level'),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'name',
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Color(0xFFEDE2CE), fontSize: 15),
              decoration: _inputDeco(),
              onSubmitted: widget.doc.setName,
              onEditingComplete: () => widget.doc.setName(_nameCtrl.text),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: '★★★ (s)',
                  child: TextField(
                    controller: _t3Ctrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: Color(0xFFEDE2CE), fontSize: 15),
                    decoration: _inputDeco(),
                    onChanged: (v) {
                      final d = double.tryParse(v);
                      if (d != null) {
                        widget.doc.setThresholds(d, widget.doc.thresholdTwo);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledField(
                  label: '★★ (s)',
                  child: TextField(
                    controller: _t2Ctrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: Color(0xFFEDE2CE), fontSize: 15),
                    decoration: _inputDeco(),
                    onChanged: (v) {
                      final d = double.tryParse(v);
                      if (d != null) {
                        widget.doc
                            .setThresholds(widget.doc.thresholdThree, d);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionHeader('selected'),
          const SizedBox(height: 8),
          if (selected == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'click an entity in the canvas',
                style: TextStyle(
                  color: Color(0xFF8A7E68),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            )
          else
            _SelectedEditor(doc: widget.doc, e: selected),
        ],
      ),
    );
  }

  static InputDecoration _inputDeco() => const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: Color(0xFF2A2520),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF3A332A), width: 1),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFA72920), width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      );
}

class _SelectedEditor extends StatelessWidget {
  const _SelectedEditor({required this.doc, required this.e});
  final LevelDoc doc;
  final EditorEntity e;

  @override
  Widget build(BuildContext context) {
    final schema = kEntitySchema[e.category]?[e.kind] ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2520),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Text(
                '${e.category} · ${e.kind}',
                style: const TextStyle(
                  color: Color(0xFFEDE2CE),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFA72920), size: 20),
                tooltip: 'delete',
                onPressed: () => doc.removeEntity(e),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FracField(
                label: 'x',
                value: e.x,
                onChanged: (v) {
                  doc.mutateSelected((s) => s.x = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FracField(
                label: 'y',
                value: e.y,
                onChanged: (v) {
                  doc.mutateSelected((s) => s.y = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in schema.entries)
          _SchemaField(
            field: entry.key,
            spec: entry.value,
            value: e.props[entry.key],
            onChanged: (v) {
              doc.mutateSelected((s) => s.props[entry.key] = v);
            },
          ),
      ],
    );
  }
}

class _SchemaField extends StatelessWidget {
  const _SchemaField({
    required this.field,
    required this.spec,
    required this.value,
    required this.onChanged,
  });
  final String field;
  final FieldSpec spec;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    if (spec.type == 'frac') {
      return _FracField(
        label: spec.label,
        value: (value as num).toDouble(),
        onChanged: onChanged,
      );
    }
    if (spec.type == 'int') {
      return _IntField(
        label: spec.label,
        value: (value as num).toInt(),
        min: spec.min?.toInt() ?? 0,
        max: spec.max?.toInt() ?? 99,
        onChanged: onChanged,
      );
    }
    // double / fallback
    return _DoubleField(
      label: spec.label,
      value: (value as num).toDouble(),
      min: spec.min?.toDouble(),
      max: spec.max?.toDouble(),
      onChanged: onChanged,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A7E68),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _FracField extends StatelessWidget {
  const _FracField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _LabeledField(
        label: '$label  ${value.toStringAsFixed(2)}',
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFA72920),
            inactiveTrackColor: const Color(0xFF3A332A),
            thumbColor: const Color(0xFFEDE2CE),
            overlayColor: const Color(0x33A72920),
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _DoubleField extends StatefulWidget {
  const _DoubleField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double? min;
  final double? max;

  @override
  State<_DoubleField> createState() => _DoubleFieldState();
}

class _DoubleFieldState extends State<_DoubleField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(_DoubleField old) {
    super.didUpdateWidget(old);
    if ((double.tryParse(_ctrl.text) ?? 0) != widget.value) {
      _ctrl.text = widget.value.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRange = widget.min != null && widget.max != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _LabeledField(
        label: widget.label,
        child: hasRange
            ? Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFA72920),
                        inactiveTrackColor: const Color(0xFF3A332A),
                        thumbColor: const Color(0xFFEDE2CE),
                        overlayColor: const Color(0x33A72920),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: widget.value
                            .clamp(widget.min!, widget.max!),
                        min: widget.min!,
                        max: widget.max!,
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      widget.value.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Color(0xFFEDE2CE),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              )
            : TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: Color(0xFFEDE2CE), fontSize: 14),
                decoration: _PropertyPanelState._inputDeco(),
                onChanged: (v) {
                  final d = double.tryParse(v);
                  if (d != null) widget.onChanged(d);
                },
              ),
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _LabeledField(
        label: label,
        child: Row(
          children: [
            _StepBtn(
              icon: Icons.remove,
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: Color(0xFFEDE2CE),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _StepBtn(
              icon: Icons.add,
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A2520),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            color: onPressed == null
                ? const Color(0xFF4A4138)
                : const Color(0xFFEDE2CE),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
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
