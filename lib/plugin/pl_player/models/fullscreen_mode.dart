const double kScreenRatio = 1.2;

// 全屏模式
enum FullScreenMode {
  // 根据内容自适应
  auto('按视频方向（默认）'),
  // 不改变当前方向
  none('不改变当前方向'),
  // 始终竖屏
  vertical('强制竖屏'),
  // 始终横屏
  horizontal('强制横屏'),
  // 屏幕长宽比 < kScreenRatio 或为竖屏视频时竖屏，否则横屏
  ratio('屏幕长宽比<$kScreenRatio或为竖屏视频时竖屏，否则横屏'),
  // 强制重力转屏（仅安卓）
  gravity('忽略系统方向锁定，强制按重力转屏（仅安卓）'),
  ;

  final String desc;
  const FullScreenMode(this.desc);
}
