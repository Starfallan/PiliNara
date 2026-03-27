import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/utils/json_file_handler.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:catcher_2/catcher_2.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final logger = PiliLogger();

class PiliLogger extends Logger {
  PiliLogger()
      : super(
          filter: ProductionFilter(), // 使用生产环境过滤器，默认不打印普通日志
          printer: PrettyPrinter(methodCount: 0),
        );

  @override
  void log(
    Level level,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) {
    // 如果日志开关关闭，且不是调试模式，则直接返回，不处理任何逻辑（节省性能）
    if (!Pref.enableLog && !kDebugMode) {
      return;
    }

    if (Pref.enableLog && (level == Level.error || level == Level.fatal)) {
      try {
        Catcher2.reportCheckedError(error, stackTrace);
      } catch (e) {
        // Fallback if Catcher2 is not initialized or fails
      }
    }

    // 只有在调试模式或者开启了日志时，才交给父类处理（打印到控制台等）
    super.log(level, message, error: error, stackTrace: stackTrace, time: time);
  }
}

abstract final class LoggerUtils {
  static File? _logFile;

  static Future<File> getLogsPath() async {
    if (_logFile != null) return _logFile!;

    String dir = (await getApplicationDocumentsDirectory()).path;
    final String filename = p.join(dir, '.pili_logs.json');
    final File file = File(filename);
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    return _logFile = file;
  }

  static Future<bool> clearLogs() async {
    try {
      if (Pref.enableLog) {
        await JsonFileHandler.add(
          (raf) => raf.setPosition(0).then((raf) => raf.truncate(0)),
        );
      } else {
        final file = await getLogsPath();
        await file.writeAsBytes(const [], flush: true);
      }
    } catch (e) {
      // if (kDebugMode) debugPrint('Error clearing file: $e');
      return false;
    }
    return true;
  }
}

abstract final class DebugDumpUtils {
  static const String _dirName = 'debug_dumps';
  static final Map<String, File> _dumpFiles = {};
  static final Map<String, Future<void>> _queues = {};
  static final Set<String> _reportedFiles = <String>{};

  static Future<File> getDumpFile(String filename) async {
    if (_dumpFiles[filename] case final file?) {
      return file;
    }

    final dir = await getApplicationSupportDirectory();
    final dumpDir = Directory(p.join(dir.path, _dirName));
    if (!dumpDir.existsSync()) {
      await dumpDir.create(recursive: true);
    }
    final file = File(p.join(dumpDir.path, filename));
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    _dumpFiles[filename] = file;
    if (_reportedFiles.add(filename)) {
      logger.i('[DebugDumpUtils] $filename => ${file.path}');
    }
    return file;
  }

  static Future<void> appendJsonLine({
    required String filename,
    required Map<String, dynamic> data,
  }) {
    if (!kDebugMode) {
      return Future.value();
    }
    final line = '${jsonEncode(data)}\n';
    final previous = _queues[filename] ?? Future<void>.value();
    return _queues[filename] = previous.then((_) async {
      final file = await getDumpFile(filename);
      await file.writeAsString(
        line,
        mode: FileMode.writeOnlyAppend,
        flush: true,
      );
    });
  }

  static Future<void> clearDump(String filename) async {
    final file = await getDumpFile(filename);
    await file.writeAsBytes(const [], flush: true);
  }
}
