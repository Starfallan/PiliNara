import 'dart:io';

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

abstract final class AppFont {
  static const _kFontExts = ['ttf', 'otf'];
  static final _kFontDir = path.join(appSupportDirPath, 'font');
  static final _loadedFonts = <String>{};

  /// 所有已导入的字体 Map: { fontFamily: filePath }
  static Map<String, String> get customFonts => Pref.customAppFont;

  // ── 迁移 ──────────────────────────────────────────

  static Future<void> _migrateIfNeeded() async {
    final oldPath = Pref.customFontPath;
    final oldFamily = Pref.customFontFamily;
    if (oldPath == null || oldFamily == null) return;

    // 如果已经迁移过（customAppFont 有数据），只清理残留旧 key
    if (customFonts.isNotEmpty) {
      await GStorage.setting.delete(SettingBoxKey.customFontPath);
      await GStorage.setting.delete(SettingBoxKey.customFontFamily);
      await GStorage.setting.delete(SettingBoxKey.customFontName);
      return;
    }

    final oldFile = File(oldPath);
    if (!oldFile.existsSync()) {
      // 文件已丢失，直接清理旧 Hive key
      await GStorage.setting.delete(SettingBoxKey.customFontPath);
      await GStorage.setting.delete(SettingBoxKey.customFontFamily);
      await GStorage.setting.delete(SettingBoxKey.customFontName);
      if (Pref.appFont == oldFamily) {
        await GStorage.setting.put(SettingBoxKey.appFont, null);
      }
      return;
    }

    final oldName = Pref.customFontName;
    // "custom_font_17283920" → "17283920"
    final ts = oldFamily.replaceFirst(RegExp(r'^custom_font_'), '');
    // "MyFont.ttf" → "MyFont"
    final display = oldName != null
        ? oldName.replaceAll(RegExp(r'\.[^.]+$'), '')
        : 'imported';
    final newKey = '$ts/$display';

    // 新目录 + 新路径
    final newDir = Directory(_kFontDir);
    if (!newDir.existsSync()) await newDir.create(recursive: true);
    final ext = path.extension(oldPath);
    final newPath = path.join(_kFontDir, '$ts-$display$ext');

    // 移动物理文件（同分区 rename 零开销）
    try {
      await oldFile.rename(newPath);
    } catch (_) {
      // 跨分区 rename 失败，fallback: copy + delete
      await oldFile.copy(newPath);
      try {
        await oldFile.delete();
      } catch (_) {}
    }

    final map = <String, String>{newKey: newPath};
    await GStorage.setting.put(SettingBoxKey.customAppFont, map);

    if (Pref.appFont == oldFamily) {
      await GStorage.setting.put(SettingBoxKey.appFont, newKey);
    }

    await GStorage.setting.delete(SettingBoxKey.customFontPath);
    await GStorage.setting.delete(SettingBoxKey.customFontFamily);
    await GStorage.setting.delete(SettingBoxKey.customFontName);

    // 清理旧 fonts/ 目录
    final oldDir = Directory(path.join(appSupportDirPath, 'fonts'));
    if (oldDir.existsSync()) {
      try {
        await oldDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  // ── 初始化 ────────────────────────────────────────

  static Future<void> init() async {
    await _migrateIfNeeded();
    final family = Pref.appFont;
    if (family != null && customFonts.containsKey(family)) {
      await loadFontIfNecessary(family);
    }
  }

  // ── 加载 ──────────────────────────────────────────

  static Future<void>? loadFontIfNecessary(String fontFamily) {
    if (_loadedFonts.contains(fontFamily)) return null;
    return _loadFont(fontFamily);
  }

  static Future<void> _loadFont(String fontFamily) async {
    try {
      _loadedFonts.add(fontFamily);
      final bytes = await File(customFonts[fontFamily]!).readAsBytes();
      await (FontLoader(fontFamily)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    } catch (_) {
      if (kDebugMode) rethrow;
    }
  }

  // ── 导入（多文件） ────────────────────────────────

  static Future<String?> pickFonts() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _kFontExts,
      );
      if (files.isEmpty) return null;

      final dir = Directory(_kFontDir);
      if (!dir.existsSync()) await dir.create(recursive: true);

      final futures = <Future<void>>[];
      final newFonts = <String, String>{};
      for (final file in files) {
        final ts = DateTime.now().millisecondsSinceEpoch.toString();
        final name = file.name;
        final saveTo = path.join(_kFontDir, '$ts-$name');

        futures.add(file.xFile.saveTo(saveTo));
        final displayName = name.replaceAll(RegExp(r'\.[^.]+$'), '');
        newFonts['$ts/$displayName'] = saveTo;
      }
      await Future.wait(futures);
      customFonts.addAll(newFonts);
      await GStorage.setting.put(SettingBoxKey.customAppFont, customFonts);

      final first = newFonts.keys.first;
      await loadFontIfNecessary(first);
      return first;
    } catch (_) {
      if (kDebugMode) rethrow;
    }
    return null;
  }

  // ── 移除单个 ──────────────────────────────────────

  static void removeFont(String fontFamily) {
    final filePath = customFonts.remove(fontFamily);
    if (filePath != null) {
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          file.delete();
        } catch (_) {}
      }
      GStorage.setting.put(SettingBoxKey.customAppFont, customFonts);
    }
    _loadedFonts.remove(fontFamily);
  }

  // ── 清空全部 ──────────────────────────────────────

  static Future<void> clearFonts() async {
    for (final p in customFonts.values) {
      try {
        File(p).delete();
      } catch (_) {}
    }
    customFonts.clear();
    _loadedFonts.clear();
    await Future.wait([
      GStorage.setting.deleteAll({
        SettingBoxKey.appFont,
        SettingBoxKey.customAppFont,
      }),
    ]);
  }

  // ── 兼容旧 API ────────────────────────────────────

  /// 保留单文件导入兼容接口，内部转调多文件版本
  static Future<bool> pickAndApply() async {
    final font = await pickFonts();
    return font != null;
  }

  /// 保留清空兼容接口
  static Future<bool> clear() async {
    final hadCustom = customFonts.isNotEmpty;
    await clearFonts();
    return hadCustom;
  }
}