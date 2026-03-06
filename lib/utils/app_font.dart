import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

abstract final class AppFont {
  static const List<String> allowedExtensions = ['ttf', 'otf'];
  static const String _fontDirName = 'fonts';

  static String? get currentFontName => Pref.customFontName;

  static Future<void> init() async {
    final fontPath = Pref.customFontPath;
    final fontFamily = Pref.customFontFamily;
    if (fontPath == null || fontFamily == null) {
      return;
    }

    final file = File(fontPath);
    if (!file.existsSync()) {
      await clear();
      return;
    }

    try {
      await _loadFont(fontPath: fontPath, fontFamily: fontFamily);
    } catch (_) {
      await clear();
    }
  }

  static Future<bool> pickAndApply() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return false;
    }

    final picked = result.files.single;
    final extension = path
        .extension(picked.path ?? picked.name)
        .replaceFirst('.', '')
        .toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw UnsupportedError('unsupported font file: $extension');
    }

    final fontDir = Directory(path.join(appSupportDirPath, _fontDirName));
    if (!fontDir.existsSync()) {
      await fontDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = path.join(fontDir.path, 'custom_font_$timestamp.$extension');
    final targetFile = File(targetPath);
    if (picked.path case final String sourcePath) {
      await File(sourcePath).copy(targetPath);
    } else if (picked.bytes case final Uint8List bytes) {
      await targetFile.writeAsBytes(bytes, flush: true);
    } else {
      throw StateError('missing font bytes');
    }

    final fontFamily = 'custom_font_$timestamp';
    try {
      await _loadFont(fontPath: targetPath, fontFamily: fontFamily);
      final previousFontPath = Pref.customFontPath;
      await GStorage.setting.put(SettingBoxKey.customFontPath, targetPath);
      await GStorage.setting.put(SettingBoxKey.customFontFamily, fontFamily);
      await GStorage.setting.put(
        SettingBoxKey.customFontName,
        path.basename(picked.path ?? picked.name),
      );
      if (previousFontPath != null && previousFontPath != targetPath) {
        final previousFile = File(previousFontPath);
        if (previousFile.existsSync()) {
          try {
            await previousFile.delete();
          } catch (_) {}
        }
      }
      return true;
    } catch (_) {
      if (targetFile.existsSync()) {
        await targetFile.delete();
      }
      rethrow;
    }
  }

  static Future<bool> clear() async {
    final fontPath = Pref.customFontPath;
    await GStorage.setting.delete(SettingBoxKey.customFontPath);
    await GStorage.setting.delete(SettingBoxKey.customFontFamily);
    await GStorage.setting.delete(SettingBoxKey.customFontName);
    if (fontPath == null || fontPath.isEmpty) {
      return false;
    }

    final file = File(fontPath);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    return true;
  }

  static Future<void> _loadFont({
    required String fontPath,
    required String fontFamily,
  }) async {
    final bytes = await File(fontPath).readAsBytes();
    final loader = FontLoader(fontFamily);
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
