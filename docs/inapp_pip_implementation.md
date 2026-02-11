# 应用内小窗（In-App PiP）实现方案 (v2.0)

## 概述

本文档描述了 PiliPlus 应用内小窗功能的完整实现方案。该方案允许用户在应用内以浮窗形式观看视频或直播，同时浏览其他内容。相比初期版本，v2.0 重点优化了**播放器单项单例持久性**、**横竖屏自适应**以及**复杂交互控制**。

## 架构设计

### 核心原理：播放器单项单例与生命周期管理
应用采用全局唯一的 \`PlPlayerController\` 实例。
- **挑战**：常规页面销毁会触发播放器 \`dispose()\`，导致小窗或新打开的页面无法继续播放。
- **对策**：引入 \`stopPip(callOnClose: false)\` 机制，仅移除 UI 覆盖层，不销毁控制器实例，确保新载入的详情页能无缝接管播放器。

### 双服务架构 (Service Mutual Exclusion)
分离的双服务架构：
- **\`PipOverlayService\`**: 负责视频小窗管理。
- **\`LivePipOverlayService\`**: 负责直播小窗管理。
- **互斥逻辑**：当其中一个启动时，会自动调用另一个的 \`stop(callOnClose: false)\`，确保全局仅存一个小窗且不干扰单项单例播放器的工作。

## 交互设计

### 1. 动态缩放控制 (Cyclic Zoom)
取消了原有的双击暂停逻辑（暂停功能移至控制栏），改为**循环缩放**：
- **手势**：双击小窗在 \`1.0x\` -> \`1.5x\` -> \`2.0x\` 之间循环切换缩放比例。
- **布局更新**：缩放时会自动计算并约束位置，防止按钮或窗口超出屏幕边界。

### 2. 五按钮控制栏 (Control Bar)
小窗通过点击显示一层面板，包含 5 个功能：
- **右上角 [关闭]**：调用 \`stopPip(callOnClose: true)\`，彻底关闭小窗并销毁播放器实例。
- **中心 [返回]**：触发 \`onReturn\` 回调，通过路由返回对应的视频/直播详情页。
- **底部 [后退/前进]**：支持 10s 或 15s 的进度跳转（根据视频类型自适应）。
- **底部 [播放/暂停]**：直接控制单项单例播放器的运行状态。

### 3. 方向感知 (Orientation Awareness)
小窗启动时会读取播放器的 \`isVertical\` 状态：
- **横屏 (16:9)**：默认尺寸 \`200x112\`。
- **竖屏 (9:16)**：默认尺寸 \`112x200\`。
- **布局自动切换**：窗口的长宽比例会随视频内容自动调整，不再强制横屏显示。

## 关键流程实现

### 1. 页面进入（initState）
详情页进入时需识别是否是从正在运行的小窗“展开”：
\`\`\`dart
// lib/pages/live_room/view.dart
final bool isReturningFromPip = LivePipOverlayService.isCurrentLiveRoom(currentRoomId);

if (LivePipOverlayService.isInPipMode) {
  // 无论是否是同一房间，先移除 UI 覆盖层，但不销毁播放器逻辑
  LivePipOverlayService.stopLivePip(callOnClose: false);
}

// 正常创建控制器，如果 isReturningFromPip 为 true，则内部跳过 DataSource 初始化
_liveRoomController = Get.put(LiveRoomController(heroTag, fromPip: isReturningFromPip));
\`\`\`

### 2. 页面退出（onPopInvoked）
页面退出时根据用户设置与播放状态决定是否开启小窗：
\`\`\`dart
void _startLivePipIfNeeded() {
  if (plPlayerController.playerStatus.playing && !isFullScreen) {
    _isEnteringPipMode = true;
    LivePipOverlayService.startLivePip(
      context: context,
      roomId: _liveRoomController.roomId,
      plPlayerController: plPlayerController,
      onClose: () => _handleCleanup(), // 手动关闭时才真正 dispose
      onReturn: () => Get.toNamed('/liveRoom', ...),
    );
  }
}
\`\`\`

## SponsorBlock 集成

### 逻辑保持
由于单例不销毁，小窗模式下 SponsorBlock 的 \`positionSubscription\` 在后台继续运行。

### 重设监听 (Reset Subscription)
从小窗返回视频页时，由于 Flutter \`State\` 重建，必须重新创建 UI 层的监听逻辑：
\`\`\`dart
// lib/pages/video/view.dart
if (fromPip && videoDetailController.segmentList.isNotEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    videoDetailController.initSkip(); // 重新关联 position 监听
  });
}
\`\`\`

## UI 刷新与状态恢复

为了解决从 PiP 返回后 UI（简介、评论）不渲染的问题，采用以下策略：
1. **立即 setState**：在 \`initState\` 末尾触发，强制当前 Widget 树重绘。
2. **刷新 Observable**：通过 \`controller.videoState.refresh()\` 强制 \`Obx\` 检测。
3. **强制逻辑更新**：调用 \`controller.update()\` 触发所有 \`GetBuilder\`。

## 性能与稳定性优化

### 1. 自动吸附与边界约束
拖拽结束时小窗会自动计算距离左右边界的距离，并吸附至较近的一侧，同时保留状态栏和底部导航栏的避让。

### 2. 日志系统保护与性能
- **高频调用拦截**：在日志开关关闭时，\`_logSponsorBlock\` 等高频调用通过 \`Pref.enableLog\` 判断后立即返回，减少字符串拼接开销。
- **崩溃保护 (White Screen Fix)**：在 \`logger\` 报告错误前校验 \`Catcher2\` 是否初始化，防止在关闭日志功能时因空调用导致详情页异常。

## 未来改进方向
- [ ] 支持手势直接调整缩放比例（Pinch to Zoom）。
- [ ] 优化跨页面 Hero 动画。
- [ ] 多房间小窗预览支持。

---
**文档版本**: 2.0  
**最后更新**: 2026-02-09  
**维护者**: AI Coding Agent
