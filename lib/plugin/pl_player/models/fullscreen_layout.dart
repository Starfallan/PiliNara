enum PlayerLayoutRegion { header, actions, bottom, left, right }

enum PlayerLayoutControl {
  pin('窗口置顶', PlayerLayoutRegion.header),
  sponsorSubmit('提交片段', PlayerLayoutRegion.header),
  sponsorInfo('片段信息', PlayerLayoutRegion.header),
  pip('画中画', PlayerLayoutRegion.header),
  like('点赞', PlayerLayoutRegion.actions),
  coin('投币', PlayerLayoutRegion.actions),
  favorite('收藏', PlayerLayoutRegion.actions),
  download('缓存', PlayerLayoutRegion.actions),
  share('分享', PlayerLayoutRegion.actions),
  viewPoints('章节', PlayerLayoutRegion.bottom),
  dmChart('高能进度条', PlayerLayoutRegion.bottom),
  superResolution('超分辨率', PlayerLayoutRegion.bottom),
  episode('选集', PlayerLayoutRegion.bottom),
  fit('画面比例', PlayerLayoutRegion.bottom),
  aiTranslate('翻译', PlayerLayoutRegion.bottom),
  subtitle('字幕', PlayerLayoutRegion.bottom),
  speed('倍速', PlayerLayoutRegion.bottom),
  qa('画质', PlayerLayoutRegion.bottom),
  lock('锁定', PlayerLayoutRegion.left),
  screenshot('截图', PlayerLayoutRegion.right),
  clock('时间', null),
  battery('电量', null),
  online('观看人数', null),
  dmCount('弹幕数', null);

  const PlayerLayoutControl(this.label, this.region);
  final String label;
  final PlayerLayoutRegion? region;

  bool get isSide => this == lock || this == screenshot;

  bool accepts(PlayerLayoutRegion target) =>
      isSide ? target == .left || target == .right : region == target;

  static PlayerLayoutControl? fromName(Object? name) {
    for (final item in values) {
      if (item.name == name) return item;
    }
    return null;
  }
}

/// 全屏控件偏好。数据只含稳定标识、区域顺序与隐藏集合，不含视频能力。
class FullscreenLayout {
  FullscreenLayout._(
    Map<PlayerLayoutRegion, List<PlayerLayoutControl>> regions,
    Set<PlayerLayoutControl> hidden,
  ) : regions = Map.unmodifiable({
        for (final entry in regions.entries)
          entry.key: List<PlayerLayoutControl>.unmodifiable(entry.value),
      }),
      hidden = Set.unmodifiable(hidden);

  final Map<PlayerLayoutRegion, List<PlayerLayoutControl>> regions;
  final Set<PlayerLayoutControl> hidden;

  factory FullscreenLayout.defaults({required bool isMobile}) =>
      FullscreenLayout.legacy(isMobile: isMobile);

  factory FullscreenLayout.legacy({
    required bool isMobile,
    bool showActions = true,
    bool showLock = true,
    bool showScreenshot = true,
    bool lockOnRight = false,
    bool? showBattery,
    bool showOnline = false,
    bool showDmCount = false,
  }) {
    final regions = {
      for (final region in PlayerLayoutRegion.values)
        region: PlayerLayoutControl.values
            .where((item) => item.region == region)
            .toList(),
    };
    if (lockOnRight) {
      regions[PlayerLayoutRegion.left]!.clear();
      regions[PlayerLayoutRegion.right]!.add(PlayerLayoutControl.lock);
    }
    return FullscreenLayout._(regions, {
      if (!showActions) ...regions[PlayerLayoutRegion.actions]!,
      if (!showLock) PlayerLayoutControl.lock,
      if (!showScreenshot) PlayerLayoutControl.screenshot,
      if (!(showBattery ?? isMobile)) PlayerLayoutControl.battery,
      if (!showOnline) PlayerLayoutControl.online,
      if (!showDmCount) PlayerLayoutControl.dmCount,
    });
  }

  factory FullscreenLayout.fromJson(
    Object? data, {
    required FullscreenLayout fallback,
  }) {
    if (data is! Map || data['version'] != 1) return fallback;
    final rawRegions = data['regions'];
    final regions = <PlayerLayoutRegion, List<PlayerLayoutControl>>{};
    final seen = <PlayerLayoutControl>{};
    for (final region in PlayerLayoutRegion.values) {
      final raw = rawRegions is Map ? rawRegions[region.name] : null;
      regions[region] = [
        if (raw is List)
          for (final name in raw)
            if (PlayerLayoutControl.fromName(name) case final item?)
              if (item.accepts(region) && seen.add(item)) item,
      ];
    }
    for (final region in PlayerLayoutRegion.values) {
      for (final item in fallback.items(region)) {
        if (seen.add(item)) regions[region]!.add(item);
      }
    }
    final rawHidden = data['hidden'];
    return FullscreenLayout._(regions, {
      if (rawHidden is List)
        for (final name in rawHidden) ?PlayerLayoutControl.fromName(name),
      if (rawHidden is! List) ...fallback.hidden,
    });
  }

  List<PlayerLayoutControl> items(PlayerLayoutRegion region) => regions[region]!;
  bool shows(PlayerLayoutControl item) => !hidden.contains(item);

  FullscreenLayout toggle(PlayerLayoutControl item) {
    final updated = {...hidden};
    if (!updated.remove(item)) updated.add(item);
    return FullscreenLayout._(regions, updated);
  }

  /// index 是移除源项目之前的插入位置，越区拖放不改变草稿。
  FullscreenLayout move(
    PlayerLayoutControl item,
    PlayerLayoutRegion target,
    int index,
  ) {
    if (!item.accepts(target)) return this;
    final updated = {
      for (final entry in regions.entries) entry.key: [...entry.value],
    };
    final oldIndex = updated[target]!.indexOf(item);
    if (oldIndex >= 0 && oldIndex < index) index--;
    for (final list in updated.values) {
      list.remove(item);
    }
    final list = updated[target]!;
    list.insert(index.clamp(0, list.length), item);
    return FullscreenLayout._(updated, hidden);
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'regions': {
      for (final entry in regions.entries)
        entry.key.name: entry.value.map((item) => item.name).toList(),
    },
    'hidden': hidden.map((item) => item.name).toList(),
  };
}
