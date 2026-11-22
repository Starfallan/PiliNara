import 'package:flutter/widgets.dart' show Color;

abstract final class BiliColors {
  static const pinkLight = Color(0xFFFF6699);
  static const pinkDark = Color(0xFFD44E7D);

  static const blueLight = Color(0xFF008AC5);
  static const blueDark = Color(0xFF2C9CC8);

  static const yellow = Color(0xFFFFCC00);

  /// 小站评论数徽标配色。后端按评论数分档，匿名返回十六进制，
  /// 登录后改为返回 CSS 变量名，两者对应同一档颜色。
  static const bubbleReplyColorVars = <String, Color>{
    'var(--Or5)': Color(0xFFFF661A),
    'var(--Ye6)': Color(0xFFFFB027),
    'var(--Ly5)': Color(0xFFFFCC00),
    'var(--Ly6)': Color(0xFFFFCC00),
    'var(--Ga5)': Color(0xFF9499A0),
  };
}
