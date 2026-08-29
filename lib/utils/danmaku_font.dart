import 'dart:io';

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

abstract final class DanmakuFont {
  static const List<String> allowedExtensions = ['ttf', 'otf'];
  static const String _fontDirName = 'danmaku_fonts';
  static final _loadedFonts = <String>{};

  static String? get currentFontName => Pref.customDanmakuFontName;

  static Future<void> init() async {
    final fontPath = Pref.customDanmakuFontPath;
    final fontFamily = Pref.customDanmakuFontFamily;
    if (fontPath == null || fontFamily == null) {
      await _cleanupFontDir();
      return;
    }

    final file = File(fontPath);
    if (!file.existsSync()) {
      await clear();
      return;
    }

    try {
      await _loadFont(fontPath: fontPath, fontFamily: fontFamily);
      await _cleanupFontDir(excludePath: fontPath);
    } catch (_) {
      await clear();
    }
  }

  static Future<bool> pickAndApply() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (picked == null) {
      return false;
    }

    final extension = picked.extension?.toLowerCase();
    if (extension == null || !allowedExtensions.contains(extension)) {
      throw UnsupportedError('unsupported font file: $extension');
    }

    final fontDir = Directory(path.join(appSupportDirPath, _fontDirName));
    if (!fontDir.existsSync()) {
      await fontDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = path.join(fontDir.path, 'custom_danmaku_font_$timestamp.$extension');
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(await picked.readAsBytes(), flush: true);

    final fontFamily = 'custom_danmaku_font_$timestamp';
    try {
      await _loadFont(fontPath: targetPath, fontFamily: fontFamily);
      final previousFontPath = Pref.customDanmakuFontPath;
      await GStorage.setting.put(SettingBoxKey.customDanmakuFontPath, targetPath);
      await GStorage.setting.put(SettingBoxKey.customDanmakuFontFamily, fontFamily);
      await GStorage.setting.put(
        SettingBoxKey.customDanmakuFontName,
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
      await _cleanupFontDir(excludePath: targetPath);
      return true;
    } catch (_) {
      if (targetFile.existsSync()) {
        await targetFile.delete();
      }
      rethrow;
    }
  }

  static Future<bool> clear() async {
    final fontPath = Pref.customDanmakuFontPath;
    final hadCustomFont =
        (fontPath != null && fontPath.isNotEmpty) ||
        Pref.customDanmakuFontFamily != null ||
        Pref.customDanmakuFontName != null;
    await GStorage.setting.delete(SettingBoxKey.customDanmakuFontPath);
    await GStorage.setting.delete(SettingBoxKey.customDanmakuFontFamily);
    await GStorage.setting.delete(SettingBoxKey.customDanmakuFontName);
    _loadedFonts.clear();
    if (fontPath != null && fontPath.isNotEmpty) {
      final file = File(fontPath);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    final deletedFiles = await _cleanupFontDir();
    return hadCustomFont || deletedFiles;
  }

  static Future<void> _loadFont({
    required String fontPath,
    required String fontFamily,
  }) async {
    if (_loadedFonts.contains(fontFamily)) return;
    try {
      _loadedFonts.add(fontFamily);
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader(fontFamily)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    } catch (_) {}
  }

  static Future<bool> _cleanupFontDir({String? excludePath}) async {
    final fontDir = Directory(path.join(appSupportDirPath, _fontDirName));
    if (!fontDir.existsSync()) {
      return false;
    }

    var deletedAny = false;
    await for (final entity in fontDir.list()) {
      if (entity is! File) {
        continue;
      }
      if (excludePath != null && path.equals(entity.path, excludePath)) {
        continue;
      }
      final extension = path.extension(entity.path).replaceFirst('.', '').toLowerCase();
      if (!allowedExtensions.contains(extension)) {
        continue;
      }
      try {
        await entity.delete();
        deletedAny = true;
      } catch (_) {}
    }
    return deletedAny;
  }
}
