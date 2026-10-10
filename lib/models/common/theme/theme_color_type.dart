import 'package:material_ui/material_ui.dart';

/// miuix 的主色，也就是 MIUI 蓝。
///
/// 选中它意味着使用 miuix 的固定配色，而不是由主色推导出来的动态配色——这与 miuix 自身的
/// 默认主题一致。
const Color miuixKeyColor = Color(0xFF3482FF);

/// miuix 蓝在 [colorThemeTypes] 里的下标；应用默认使用它，于是开箱即是 miuix 主题。
const int miuixColorIndex = 19;

const List<({Color color, String label})> colorThemeTypes = [
  (color: Color(0xFF5CB67B), label: '默认绿'),
  (color: Color(0xFFFF7299), label: '粉红色'),
  (color: Colors.red, label: '红色'),
  (color: Colors.orange, label: '橙色'),
  (color: Colors.amber, label: '琥珀色'),
  (color: Colors.yellow, label: '黄色'),
  (color: Colors.lime, label: '酸橙色'),
  (color: Colors.lightGreen, label: '浅绿色'),
  (color: Colors.green, label: '绿色'),
  (color: Colors.teal, label: '青色'),
  (color: Colors.cyan, label: '蓝绿色'),
  (color: Colors.lightBlue, label: '浅蓝色'),
  (color: Colors.blue, label: '蓝色'),
  (color: Colors.indigo, label: '靛蓝色'),
  (color: Colors.purple, label: '紫色'),
  (color: Colors.deepPurple, label: '深紫色'),
  (color: Colors.blueGrey, label: '蓝灰色'),
  (color: Colors.brown, label: '棕色'),
  (color: Colors.grey, label: '灰色'),
  (color: miuixKeyColor, label: 'MIUI 蓝'),
];
