import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'editor_state.dart';

const _typeGroup = XTypeGroup(label: 'Flamekut levels', extensions: ['json']);

Future<String?> openLevelFile(LevelDoc doc) async {
  final XFile? file = await openFile(acceptedTypeGroups: [_typeGroup]);
  if (file == null) return null;
  final raw = await file.readAsString();
  doc.loadFromJsonString(raw, path: file.path);
  return file.path;
}

Future<String?> saveLevelAs(LevelDoc doc, {String? suggestedName}) async {
  final fileName = '${(suggestedName ?? doc.name).replaceAll(' ', '_')}.json';
  final FileSaveLocation? loc = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [_typeGroup],
  );
  if (loc == null) return null;
  final path = loc.path;
  final f = File(path);
  await f.writeAsString(doc.toJsonString());
  doc.sourcePath = path;
  doc.bump();
  return path;
}

Future<String?> saveLevel(LevelDoc doc) async {
  final path = doc.sourcePath;
  if (path == null) return saveLevelAs(doc);
  await File(path).writeAsString(doc.toJsonString());
  return path;
}
