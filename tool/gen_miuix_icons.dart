// 把 miuix 的 miuix-icons 模块（Kotlin ImageVector，每个图标一个文件、五档字重）里的
// Regular 那一档翻成 Flutter 能画的路径数据，生成 lib/utils/miuix/miuix_icon_data.dart。
//
// 用法（在一个装有 miuix 源码的目录旁执行）：
//   dart run tool/gen_miuix_icons.dart <miuix-icons/src/commonMain/kotlin/.../extended 目录>
//
// miuix 的图标是矢量（不是字体），每个图标是 1297.2 的自定义 viewport + 一串 PathNode，
// 外面套着 group(scaleY = -1, translationY = viewport) 做 Y 轴翻转；这里把变换烘进坐标，
// 再按 24:viewport 缩放到 Flutter 常用的 24×24 空间，输出成 SVG 风格的路径字符串。
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('用法: dart run tool/gen_miuix_icons.dart <图标目录> [输出文件]');
    exitCode = 2;
    return;
  }
  final dir = Directory(args[0]);
  if (!dir.existsSync()) {
    stderr.writeln('目录不存在: ${args[0]}');
    exitCode = 2;
    return;
  }
  final outPath = args.length > 1
      ? args[1]
      : 'lib/utils/miuix/miuix_icon_data.dart';

  final ops = <String, int>{};
  final icons = <String, _Icon>{};
  final skipped = <String>[];

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.kt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final text = file.readAsStringSync();
    final iconName = file.uri.pathSegments.last.replaceAll('.kt', '');
    // 每个文件里五档字重各一个 Builder，取 name = "<Icon>.Regular" 那段。
    final chunks = text.split('ImageVector.Builder(');
    String? regular;
    for (final chunk in chunks) {
      if (chunk.contains('name = "$iconName.Regular"')) {
        regular = chunk;
        break;
      }
    }
    if (regular == null) {
      skipped.add('$iconName（找不到 Regular）');
      continue;
    }

    final viewport = _num(regular, 'viewportWidth = ([0-9.]+)f');
    final viewportH = _num(regular, 'viewportHeight = ([0-9.]+)f');
    if (viewport == null || viewportH == null || viewport <= 0) {
      skipped.add('$iconName（viewport 解析失败）');
      continue;
    }
    // group(scaleY = -1.0f, translationY = <viewport>) → y' = translationY - y
    final translationY =
        _num(regular, 'translationY = ([0-9.]+)f') ?? viewportH;

    final scale = 24 / viewport;
    final buffer = StringBuffer();
    for (final match in RegExp(
      r'PathNode\.([A-Za-z]+)\(([^)]*)\)',
    ).allMatches(regular)) {
      final op = match.group(1)!;
      ops[op] = (ops[op] ?? 0) + 1;
      final numbers = match
          .group(2)!
          .split(',')
          .map((s) => double.tryParse(s.trim().replaceAll('f', '')))
          .whereType<double>()
          .toList();
      final svg = _toSvg(op, numbers, scale, translationY);
      if (svg == null) {
        skipped.add('$iconName（$op 未支持）');
        break;
      }
      if (svg.isNotEmpty) buffer.write('$svg ');
    }
    if (buffer.isEmpty) {
      skipped.add('$iconName（没有路径）');
      continue;
    }
    icons[iconName] = _Icon(
      dartName: _camel(iconName),
      path: buffer.toString().trim(),
    );
  }

  final out = File(outPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(_emit(icons.values.toList(), ops, skipped));
  stdout
    ..writeln('生成 ${out.path}：${icons.length} 个图标')
    ..writeln('PathNode 统计: ${_sortedOps(ops)}');
  if (skipped.isNotEmpty) {
    stdout.writeln('跳过 ${skipped.length} 个：${skipped.take(8).join('、')}');
  }
}

String? _toSvg(
  String op,
  List<double> n,
  double scale,
  double translationY,
) {
  String x(v) => _fmt(v * scale);
  String y(v) => _fmt((translationY - v) * scale);
  return switch (op) {
    'MoveTo' when n.length >= 2 => 'M ${x(n[0])} ${y(n[1])}',
    'LineTo' when n.length >= 2 => 'L ${x(n[0])} ${y(n[1])}',
    'HorizontalTo' when n.length >= 1 => 'H ${x(n[0])}',
    'VerticalTo' when n.length >= 1 => 'V ${y(n[0])}',
    'QuadTo' when n.length >= 4 =>
      'Q ${x(n[0])} ${y(n[1])} ${x(n[2])} ${y(n[3])}',
    'CurveTo' when n.length >= 6 =>
      'C ${x(n[0])} ${y(n[1])} ${x(n[2])} ${y(n[3])} ${x(n[4])} ${y(n[5])}',
    'Close' => 'Z',
    _ => null,
  };
}

String _emit(List<_Icon> icons, Map<String, int> ops, List<String> skipped) {
  final buffer = StringBuffer()
    ..writeln('// 由 tool/gen_miuix_icons.dart 从 miuix 的 miuix-icons 模块生成，请勿手改。')
    ..writeln('//')
    ..writeln('// 每个图标是 miuix ImageVector（Regular 字重）里的路径，坐标已经过 Y 轴翻转')
    ..writeln('// 并缩放到 24×24，路径用 SVG 风格的命令串描述。')
    ..writeln('/// 一个 miuix 图标的路径数据。')
    ..writeln('class MiuixIconData {')
    ..writeln('  const MiuixIconData(this.path, {this.viewport = 24});')
    ..writeln()
    ..writeln('  /// SVG 风格的路径命令串（M/L/H/V/Q/C/Z）。')
    ..writeln('  final String path;')
    ..writeln()
    ..writeln('  /// 路径所在的方形视口边长，图标按这个尺寸绘制。')
    ..writeln('  final double viewport;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// miuix 的图标集（由生成器产出，${icons.length} 个）。')
    ..writeln('abstract final class MiuixIcons {');
  for (final icon in icons) {
    buffer.writeln(
      '  static const MiuixIconData ${icon.dartName} = '
      'MiuixIconData(\n    \'${icon.path}\',\n  );',
    );
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _sortedOps(Map<String, int> ops) {
  final entries = ops.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => '${e.key}=${e.value}').join(' ');
}

double? _num(String text, String pattern) {
  final match = RegExp(pattern).firstMatch(text);
  return match == null ? null : double.tryParse(match.group(1)!);
}

String _fmt(double value) {
  final rounded = (value * 100).roundToDouble() / 100;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toString();
}

String _camel(String name) {
  if (name.isEmpty) return name;
  // 切开驼峰：AddCircle → add Circle → addCircle
  final parts = name
      .replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1 $2')
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), ' ')
      .trim()
      .split(RegExp(r'\s+'));
  final first = parts.first.toLowerCase();
  final rest = parts.skip(1).map(
    (p) => p[0].toUpperCase() + p.substring(1),
  );
  return [first, ...rest].join();
}

class _Icon {
  const _Icon({required this.dartName, required this.path});

  final String dartName;
  final String path;
}
