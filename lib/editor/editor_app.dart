import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_state.dart';
import 'entity_palette.dart';
import 'level_canvas.dart';
import 'level_io.dart';
import 'property_panel.dart';
import 'test_play.dart';
import 'validator.dart';

class EditorApp extends StatefulWidget {
  const EditorApp({super.key});

  @override
  State<EditorApp> createState() => _EditorAppState();
}

class _EditorAppState extends State<EditorApp> {
  final LevelDoc _doc = LevelDoc();
  final PlacementMode _placement = PlacementMode();
  final FocusNode _keyFocus = FocusNode();
  String _statusText = 'new level';

  @override
  void initState() {
    super.initState();
    _doc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _keyFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent ev) {
    if (ev is KeyDownEvent) {
      if (ev.logicalKey == LogicalKeyboardKey.escape) {
        if (_placement.active) {
          _placement.clear();
        } else {
          _doc.select(null);
        }
        return KeyEventResult.handled;
      }
      if (ev.logicalKey == LogicalKeyboardKey.delete ||
          ev.logicalKey == LogicalKeyboardKey.backspace) {
        if (_doc.selected != null) {
          _doc.removeEntity(_doc.selected!);
          return KeyEventResult.handled;
        }
      }
      // Cmd+S / Ctrl+S → save
      if (ev.logicalKey == LogicalKeyboardKey.keyS &&
          (HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed)) {
        _save();
        return KeyEventResult.handled;
      }
      // Cmd+O / Ctrl+O → open
      if (ev.logicalKey == LogicalKeyboardKey.keyO &&
          (HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed)) {
        _open();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _open() async {
    try {
      final path = await openLevelFile(_doc);
      if (path != null) {
        setState(() => _statusText = 'opened ${_basename(path)}');
      }
    } catch (e) {
      setState(() => _statusText = 'open failed: $e');
    }
  }

  Future<void> _save() async {
    try {
      final path = await saveLevel(_doc);
      if (path != null) {
        final issues = validateLevelDoc(_doc);
        final suffix = issues.isEmpty
            ? ''
            : ' · ${issues.length} validation issue${issues.length == 1 ? '' : 's'}';
        setState(() => _statusText = 'saved ${_basename(path)}$suffix');
      }
    } catch (e) {
      setState(() => _statusText = 'save failed: $e');
    }
  }

  Future<void> _saveAs() async {
    try {
      final path = await saveLevelAs(_doc);
      if (path != null) {
        final issues = validateLevelDoc(_doc);
        final suffix = issues.isEmpty
            ? ''
            : ' · ${issues.length} validation issue${issues.length == 1 ? '' : 's'}';
        setState(() => _statusText = 'saved as ${_basename(path)}$suffix');
      }
    } catch (e) {
      setState(() => _statusText = 'save failed: $e');
    }
  }

  void _test() {
    if (_doc.entities.where((e) => e.category == 'demon').isEmpty) {
      setState(() => _statusText = 'add at least one demon to test');
      return;
    }
    setState(() => _statusText = 'launching test play…');
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TestPlayPage(levelJson: _doc.toJsonString()),
    ));
  }

  void _validate() {
    final issues = validateLevelDoc(_doc);
    if (issues.isEmpty) {
      setState(() => _statusText = '✓ valid · ${_doc.entities.length} entities');
    } else {
      setState(() => _statusText =
          '✗ ${issues.length} issue${issues.length == 1 ? '' : 's'} · ${issues.first}');
      // Show the full list as a dialog
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F1A14),
          title: const Text(
            'validation issues',
            style: TextStyle(color: Color(0xFFEDE2CE), letterSpacing: 4),
          ),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: issues
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('· ',
                                style: TextStyle(
                                    color: Color(0xFFA72920), fontSize: 16)),
                            Expanded(
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: Color(0xFFEDE2CE),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ok'),
            ),
          ],
        ),
      );
    }
  }

  void _newDoc() {
    _doc.clearAll();
    _doc.setName('untitled');
    _doc.setThresholds(8.0, 12.0);
    _doc.sourcePath = null;
    setState(() => _statusText = 'new level');
  }

  String _basename(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14110D),
      body: Focus(
        focusNode: _keyFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            _Toolbar(
              onNew: _newDoc,
              onOpen: _open,
              onSave: _save,
              onSaveAs: _saveAs,
              onTest: _test,
              onValidate: _validate,
              statusText: _statusText,
              entityCount: _doc.entities.length,
              docName: _doc.name,
              dirty: _doc.sourcePath != null,
            ),
            Expanded(
              child: Row(
                children: [
                  EntityPalette(placement: _placement),
                  Expanded(
                    child: Container(
                      color: const Color(0xFF14110D),
                      child: LevelCanvas(
                        doc: _doc,
                        placement: _placement,
                      ),
                    ),
                  ),
                  PropertyPanel(doc: _doc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onTest,
    required this.onValidate,
    required this.statusText,
    required this.entityCount,
    required this.docName,
    required this.dirty,
  });

  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onTest;
  final VoidCallback onValidate;
  final String statusText;
  final int entityCount;
  final String docName;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF1F1A14),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2D2620), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'ronin vs his demons · level editor',
            style: TextStyle(
              color: Color(0xFFEDE2CE),
              fontSize: 15,
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 32),
          _ToolButton(label: 'new', shortcut: '⌘N', onPressed: onNew),
          _ToolButton(label: 'open', shortcut: '⌘O', onPressed: onOpen),
          _ToolButton(label: 'save', shortcut: '⌘S', onPressed: onSave),
          _ToolButton(label: 'save as…', onPressed: onSaveAs),
          const SizedBox(width: 12),
          _ToolButton(label: 'validate', onPressed: onValidate),
          const SizedBox(width: 8),
          _PrimaryButton(label: 'test play', onPressed: onTest),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2520),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$docName · $entityCount entities',
              style: const TextStyle(
                color: Color(0xFFB8A78A),
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: const TextStyle(
              color: Color(0xFF8A7E68),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.play_arrow, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, letterSpacing: 1.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFA72920),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.label, required this.onPressed, this.shortcut});
  final String label;
  final String? shortcut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: shortcut ?? '',
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFEDE2CE),
            backgroundColor: const Color(0xFF2A2520),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
