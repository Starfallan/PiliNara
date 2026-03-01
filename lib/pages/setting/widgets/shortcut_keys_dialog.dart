import 'package:flutter/material.dart';

class ShortcutKeysDialog extends StatelessWidget {
  const ShortcutKeysDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '快捷键清单',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('视频播放器快捷键功能', [
                      '空格键 - 播放/暂停视频',
                      'F键 - 切换全屏模式（Shift+F 切换应用内全屏）',
                      'D键 - 切换弹幕显示/隐藏',
                      'P键 - 桌面端画中画模式',
                      'M键 - 静音/取消静音',
                      'S键 - 全屏模式下截图',
                      'Enter键 - 发送弹幕或跳过片段',
                    ]),
                    _buildSection('播放控制快捷键', [
                      '方向键左 - 后退（可配置时长）',
                      '方向键右 - 前进（可配置时长）',
                      '方向键上/下 - 增加/减少音量',
                      'Shift+1/2 - 设置播放速度为1x或2x',
                    ]),
                    _buildSection('互动快捷键', [
                      'Q键 - 长按开始三连，松开取消三连',
                      'R键 - 长按开始三连，松开取消三连',
                      'W键 - 投币（需按住Cmd/Ctrl）',
                      'E键 - 快速收藏',
                      'T/V键 - 稍后再看',
                      'G键 - 关注/取消关注',
                      'L键 - 锁定/解锁控制面板',
                    ]),
                    _buildSection('其他', [
                      '[ 键 - 上一集',
                      '] 键 - 下一集',
                      'H键 - 返回主页（需按住Opt/Alt）',
                      'R键 - 刷新页面（需按住Cmd/Ctrl）',
                      ', 键 - 打开设置（需按住Cmd/Ctrl）',
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              item,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
