import 'package:PiliPlus/utils/storage_pref.dart';

/// 小站帖子已读记录。
///
/// 接口的 `is_read` 从不下发 true（实测匿名与登录态均为 false，
/// 手动调 opus 详情接口也不会写已读），所以改为客户端本地记录：
/// 帖子页停留满 [Pref.bubbleReadDelay] 秒即记为已读。
///
/// 持久模式（[Pref.bubbleReadPersistent] 为 true）用 Hive 落盘，重启仍在；
/// 单次模式只在内存里记，退出小站页即清空。
abstract final class BubbleReadService {
  /// 单次模式下的内存记录
  static final Set<String> _session = <String>{};

  /// 参与已读计算的页面数，减到 0 时按模式决定是否清空
  static int _activePages = 0;

  static bool get _enabled => Pref.bubbleReadEnable;

  static bool isRead(String? dynId) {
    if (!_enabled || dynId == null) {
      return false;
    }
    return Pref.bubbleReadPersistent
        ? Pref.bubbleReadDynIds.contains(dynId)
        : _session.contains(dynId);
  }

  /// 记一条已读；开关关闭时直接忽略
  static void markRead(String? dynId) {
    if (!_enabled || dynId == null) {
      return;
    }
    if (Pref.bubbleReadPersistent) {
      final ids = Pref.bubbleReadDynIds;
      if (ids.add(dynId)) {
        Pref.bubbleReadDynIds = ids;
      }
    } else {
      _session.add(dynId);
    }
  }

  /// 进入小站页面，返回令牌供 [leavePage] 配对
  static int enterPage() {
    _activePages++;
    return _activePages;
  }

  /// 离开小站页面；最后一个页面退出后，单次模式清空记录
  static void leavePage(int token) {
    if (token <= 0) {
      return;
    }
    if (_activePages > 0) {
      _activePages--;
    }
    if (_activePages == 0 && !Pref.bubbleReadPersistent) {
      _session.clear();
    }
  }

  /// 手动清空已读记录（持久 + 单次都清）
  static void clearAll() {
    _session.clear();
    Pref.bubbleReadDynIds = <String>{};
  }

  /// 供设置页显示已记录条数
  static int get count =>
      Pref.bubbleReadPersistent ? Pref.bubbleReadDynIds.length : _session.length;
}
