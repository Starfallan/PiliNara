import 'package:PiliPlus/services/logger.dart';
import 'package:flutter/foundation.dart';

void mediaTrace(
  String scope,
  String event, {
  Object? message,
  Map<String, Object?>? data,
}) {
  if (!kDebugMode) return;
  final buffer = StringBuffer('[MediaTrace][$scope] $event');
  if (message != null) {
    buffer.write(' | $message');
  }
  if (data != null && data.isNotEmpty) {
    final items = data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    buffer.write(' | $items');
  }
  logger.i(buffer.toString());
}
