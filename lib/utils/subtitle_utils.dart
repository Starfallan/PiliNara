import 'dart:convert';

// Logic inspired by BiliRoamingX.
abstract final class SubtitleUtils {
  /// Converts seconds to SRT timecode format: HH:mm:ss,mmm
  static String _srtTimecode(num seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds.toInt() % 60;
    int ms = ((seconds - seconds.toInt()) * 1000).round();
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')},${ms.toString().padLeft(3, '0')}";
  }

  /// Converts Bilibili BCC (JSON) body list to standard SRT string
  static String bccToSrt(List list) {
    final sb = StringBuffer();
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item == null) continue;

      // SRT structure: Index, Timestamp, Content, Empty Line
      sb.writeln(i + 1);
      sb.writeln("${_srtTimecode(item['from'])} --> ${_srtTimecode(item['to'])}");
      sb.writeln(item['content'].toString().trim());
      sb.writeln();
    }
    return sb.toString();
  }
}
