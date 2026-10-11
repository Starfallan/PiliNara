// 仅供本地预览：用 --update-goldens 生成 miuix 主题下的界面截图（不提交到仓库）。
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/utils/miuix/miuix_colors.dart';
import 'package:PiliPlus/utils/miuix/miuix_drag_handle.dart';
import 'package:PiliPlus/utils/miuix/miuix_icon.dart';
import 'package:PiliPlus/utils/miuix/miuix_icon_data.dart';
import 'package:PiliPlus/utils/miuix/miuix_shapes.dart';
import 'package:PiliPlus/utils/miuix/miuix_squircle.dart';
import 'package:PiliPlus/utils/miuix/miuix_theme.dart';
import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _fontFamily = 'PreviewFont';

void main() {
  testWidgets('miuix 主题预览', (tester) async {
    // 真实文件 IO 必须放在 runAsync 里，否则会被测试的假时钟卡住。
    await tester.runAsync(() async {
      final bytes = await File(r'C:\Windows\Fonts\simhei.ttf').readAsBytes();
      final loader = FontLoader(_fontFamily)
        ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    tester.view.physicalSize = const Size(760, 1900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    for (final entry in [
      ('light', MiuixColors.light),
      ('dark', MiuixColors.dark),
    ]) {
      // ignore: avoid_print
      print('rendering ${entry.$1}');
      await tester.pumpWidget(_Preview(colors: entry.$2));
      // MaterialApp 的主题切换是带动画的，等它结束再截图，否则会拍到中间态。
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      // ignore: avoid_print
      print('capturing ${entry.$1}');
      await expectLater(
        find.byType(_Preview),
        matchesGoldenFile('goldens/miuix_${entry.$1}.png'),
      );
      // ignore: avoid_print
      print('captured ${entry.$1}');
    }
  });

  // 单独出一张底栏的图：这里渲染的是应用自己的 FloatingNavigationBar，
  // 用来确认选中指示块不是硬色块、图标与标签也能看清。
  testWidgets('miuix 底栏预览', (tester) async {
    await tester.runAsync(() async {
      final bytes = await File(r'C:\Windows\Fonts\simhei.ttf').readAsBytes();
      final loader = FontLoader(_fontFamily)
        ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    tester.view.physicalSize = const Size(760, 340);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    for (final entry in [
      ('light', MiuixColors.light),
      ('dark', MiuixColors.dark),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MiuixTheme.getThemeData(
            colors: entry.$2,
            fontFamily: _fontFamily,
          ),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingNavigationBar(
                      selectedIndex: 0,
                      destinations: const [
                        FloatingNavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: '首页',
                        ),
                        FloatingNavigationDestination(
                          icon: Icon(Icons.video_library_outlined),
                          selectedIcon: Icon(Icons.video_library),
                          label: '动态',
                        ),
                        FloatingNavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: '我的',
                        ),
                      ],
                      onDestinationSelected: (_) {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/miuix_navbar_${entry.$1}.png'),
      );
      // ignore: avoid_print
      print('captured navbar ${entry.$1}');
    }
  });

  // miuix 图标集（矢量转过来的路径）：核对方向、粗细与缩放是否正常。
  testWidgets('miuix 图标预览', (tester) async {
    await tester.runAsync(() async {
      final bytes = await File(r'C:\Windows\Fonts\simhei.ttf').readAsBytes();
      final loader = FontLoader(_fontFamily)
        ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    tester.view.physicalSize = const Size(760, 640);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    const icons = [
      ('back', MiuixIcons.back),
      ('close', MiuixIcons.close),
      ('search', MiuixIcons.search),
      ('settings', MiuixIcons.settings),
      ('home', MiuixIcons.home),
      ('add', MiuixIcons.add),
      ('delete', MiuixIcons.delete),
      ('share', MiuixIcons.share),
      ('download', MiuixIcons.download),
      ('refresh', MiuixIcons.refresh),
      ('play', MiuixIcons.play),
      ('pause', MiuixIcons.pause),
    ];

    for (final entry in [
      ('light', MiuixColors.light),
      ('dark', MiuixColors.dark),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MiuixTheme.getThemeData(
            colors: entry.$2,
            fontFamily: _fontFamily,
          ),
          home: Scaffold(
            body: Center(
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (final icon in icons)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MiuixIcon(icon.$2, size: 32),
                        const SizedBox(height: 4),
                        Text(icon.$1, style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/miuix_icons_${entry.$1}.png'),
      );
      // ignore: avoid_print
      print('captured icons ${entry.$1}');
    }
  });

  // 按压反馈：点一下之后必须淡出（否则会在被点过的标签上留一块色），按住时才显示叠加色。
  testWidgets('miuix 按压反馈预览', (tester) async {
    await tester.runAsync(() async {
      final bytes = await File(r'C:\Windows\Fonts\simhei.ttf').readAsBytes();
      final loader = FontLoader(_fontFamily)
        ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    tester.view.physicalSize = const Size(760, 420);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> pumpPreview(MiuixColors colors) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MiuixTheme.getThemeData(
            colors: colors,
            fontFamily: _fontFamily,
          ),
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FilledButton(
                        onPressed: () {},
                        child: const Text('点一下'),
                      ),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('按住'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final entry in [
      ('light', MiuixColors.light),
      ('dark', MiuixColors.dark),
    ]) {
      await pumpPreview(entry.$2);
      // 左边的按钮点一下（松手后叠加色必须完全消失），右边的按钮按住不放
      // （按住期间叠加色只出现在右边这一个按钮上——落点错了就会跑到最左边那个，
      // 也就是用户反馈的「点其他标签时第一个标签也出现点击效果」）。
      await tester.tap(find.text('点一下'));
      await tester.pump(const Duration(seconds: 1));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('按住')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/miuix_ink_${entry.$1}.png'),
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      // ignore: avoid_print
      print('captured ink ${entry.$1}');
    }
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.colors});

  final MiuixColors colors;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MiuixTheme.getThemeData(
        colors: colors,
        fontFamily: _fontFamily,
      ),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: const Text('MIUI 主题预览'),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('色板', style: theme.textTheme.titleSmall),
                Builder(
                  builder: (context) {
                    final tile = ListTileTheme.of(context);
                    // ignore: avoid_print
                    print(
                      'diagnostic: defaultText=${DefaultTextStyle.of(context).style.color} '
                      'bodyLarge=${theme.textTheme.bodyLarge?.color} '
                      'onSurface=${scheme.onSurface} '
                      'tileText=${tile.textColor} '
                      'tileTitle=${tile.titleTextStyle?.color}',
                    );
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final swatch in [
                      ('primary', colors.primary),
                      ('onPrimary', colors.onPrimary),
                      ('primaryVariant', colors.primaryVariant),
                      ('secondary', colors.secondary),
                      ('secondaryVariant', colors.secondaryVariant),
                      ('selected', colors.onSecondaryVariant),
                      ('surface', colors.surface),
                      ('container', colors.surfaceContainer),
                      ('containerHigh', colors.surfaceContainerHigh),
                      ('containerHighest', colors.surfaceContainerHighest),
                      ('background', colors.background),
                      ('outline', colors.outline),
                      ('divider', colors.dividerLine),
                      ('error', colors.error),
                      ('tertiary', colors.tertiaryContainer),
                      ('summary', colors.onSurfaceVariantSummary),
                    ])
                      _Swatch(label: swatch.$1, color: swatch.$2),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.tune),
                        title: const Text('卡片标题（17）'),
                        subtitle: const Text('次级文字 60% 黑'),
                        trailing: Switch(value: true, onChanged: (_) {}),
                      ),
                      Divider(height: 1, thickness: 1, color: colors.dividerLine),
                      ListTile(
                        leading: const Icon(Icons.dark_mode_outlined),
                        title: const Text('未开启的开关'),
                        trailing: Switch(value: false, onChanged: (_) {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('按钮与滑块', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: () {},
                              child: const Text('确定'),
                            ),
                            const SizedBox(width: 12),
                            IconButton.filledTonal(
                              onPressed: () {},
                              icon: const Icon(Icons.favorite_border),
                            ),
                          ],
                        ),
                        Slider(value: 0.55, onChanged: (_) {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('连续圆角（左）vs 普通圆角（右）',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 72,
                                decoration: ShapeDecoration(
                                  color: colors.primary,
                                  shape: const MiuixSquircleBorder(
                                    cornerRadius: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 72,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'MIUI 输入框',
                            prefixIcon: Icon(Icons.search),
                          ),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 弹层：连续圆角 + 拖拽手柄。
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.background,
                    shape: MiuixSquircleBorder(
                      cornerRadius: MiuixShapes.bottomSheetCornerRadius,
                      topOnly: true,
                      side: BorderSide(color: colors.dividerLine),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MiuixDragHandle(),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          bottom: 20,
                        ),
                        child: Row(
                          children: [
                            Text('弹层内容', style: theme.textTheme.titleMedium),
                            const Spacer(),
                            Text(
                              '手柄 45×4dp',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('对话框', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '圆角 32，底色 background',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('底部弹层', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '上两角 28',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onSecondaryVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Snackbar：底色 onSecondaryVariant',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.secondaryVariant,
                          ),
                        ),
                      ),
                      Text(
                        '撤销',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '提示气泡 12',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '次级容器',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSecondaryVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '主色填充',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: Text(
        label,
        style: TextStyle(color: onColor, fontSize: 10),
        textAlign: TextAlign.center,
      ),
    );
  }
}
