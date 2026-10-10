import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/miuix/miuix_colors.dart';
import 'package:PiliPlus/utils/miuix/miuix_drag_handle.dart';
import 'package:PiliPlus/utils/miuix/miuix_indication.dart';
import 'package:PiliPlus/utils/miuix/miuix_shapes.dart';
import 'package:PiliPlus/utils/miuix/miuix_squircle.dart';
import 'package:PiliPlus/utils/miuix/miuix_text_styles.dart';
import 'package:PiliPlus/utils/miuix/miuix_theme.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('miuix 固定配色', () {
    test('取自 miuix lightColorScheme()', () {
      const light = MiuixColors.light;
      expect(light.brightness, Brightness.light);
      expect(light.primary, const Color(0xFF3482FF));
      expect(light.onPrimary, const Color(0xFFFFFFFF));
      expect(light.surface, const Color(0xFFF7F7F7));
      expect(light.background, const Color(0xFFFFFFFF));
      expect(light.surfaceContainer, const Color(0xFFFFFFFF));
      expect(light.surfaceContainerHighest, const Color(0xFFE8E8E8));
      expect(light.dividerLine, const Color(0xFFE0E0E0));
      expect(light.onSurfaceVariantSummary, const Color(0x99000000));
      expect(light.windowDimming, const Color(0x4D000000));
      expect(light.disabledPrimary, const Color(0xFFC2D9FF));
    });

    test('取自 miuix darkColorScheme()', () {
      const dark = MiuixColors.dark;
      expect(dark.brightness, Brightness.dark);
      expect(dark.primary, const Color(0xFF277AF7));
      expect(dark.surface, const Color(0xFF000000));
      expect(dark.background, const Color(0xFF242424));
      expect(dark.surfaceContainer, const Color(0xFF242424));
      expect(dark.surfaceContainerHighest, const Color(0xFF2D2D2D));
      expect(dark.dividerLine, const Color(0xFF393939));
      expect(dark.onSurfaceVariantSummary, const Color(0x80FFFFFF));
      expect(dark.windowDimming, const Color(0x99000000));
    });

    test('of() 按明暗模式取配色', () {
      expect(MiuixColors.of(Brightness.light), MiuixColors.light);
      expect(MiuixColors.of(Brightness.dark), MiuixColors.dark);
      expect(MiuixColors.light.reverse, MiuixColors.dark);
    });
  });

  group('主题色列表', () {
    test('MIUI 蓝是 miuix 的主色', () {
      expect(colorThemeTypes, hasLength(20));
      expect(colorThemeTypes[miuixColorIndex].color, miuixKeyColor);
      expect(colorThemeTypes[miuixColorIndex].label, 'MIUI 蓝');
      expect(miuixKeyColor, MiuixColors.classicKeyColor);
    });
  });

  group('miuix 令牌到 Material 角色的映射', () {
    const light = MiuixColors.light;
    final scheme = light.toColorScheme();

    test('明暗与主色', () {
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, light.primary);
      expect(scheme.onPrimary, light.onPrimary);
      expect(scheme.primaryContainer, light.primaryContainer);
      expect(scheme.primaryFixed, light.primaryVariant);
    });

    test('表面层次', () {
      expect(scheme.surface, light.surface);
      expect(scheme.surfaceContainer, light.surfaceContainer);
      expect(scheme.surfaceContainerHigh, light.surfaceContainerHigh);
      expect(scheme.surfaceContainerHighest, light.surfaceContainerHighest);
      expect(scheme.surfaceBright, light.surfaceContainer);
      expect(scheme.surfaceDim, light.surfaceContainerHigh);
    });

    test('次级文字、分隔线与遮罩', () {
      // PiliNara 一直把 outline 当次级文字色用。
      expect(scheme.outline, light.onSurfaceVariantSummary);
      expect(scheme.onSurfaceVariant, light.onSurfaceVariantSummary);
      // PiliNara 的 secondary 也是次级文字/图标色（以及底栏指示块的兜底色），
      // 所以用 miuix 压在背景上的变体色，而不是它那块中性填充。
      expect(scheme.secondary, light.onBackgroundVariant);
      expect(scheme.secondary, isNot(light.secondary));
      expect(scheme.outlineVariant, light.dividerLine);
      expect(scheme.scrim, light.windowDimming);
      // MIUI 的表面是平的，不做高程着色。
      expect(scheme.surfaceTint, Colors.transparent);
      expect(scheme.inverseSurface, light.onSecondaryVariant);
      expect(scheme.onInverseSurface, light.secondaryVariant);
    });

    test('secondaryContainer 上的前景色用 onSecondaryVariant', () {
      // miuix 的 onSecondaryContainer 是占位符灰（#A9A9A9），压在 #F0F0F0 上几乎看不清，
      // 而 PiliNara 在这个容器上画图标与文字。
      expect(scheme.secondaryContainer, light.secondaryContainer);
      expect(scheme.onSecondaryContainer, light.onSecondaryVariant);
    });
  });

  group('任意 Material 配色会被翻译成 miuix 角色', () {
    final seed = const Color(0xFF5CB67B).asColorSchemeSeed(
      FlexSchemeVariant.material,
      Brightness.light,
    );
    final miuix = MiuixColors.fromColorScheme(seed);

    test('主色与错误色保持原样', () {
      expect(miuix.primary, seed.primary);
      expect(miuix.onPrimary, seed.onPrimary);
      expect(miuix.error, seed.error);
      expect(miuix.errorContainer, seed.errorContainer);
    });

    test('次级色取自 outline，与 miuix 的取色方式一致', () {
      expect(miuix.secondary, seed.outline);
      expect(miuix.onSecondary, seed.surface);
      expect(miuix.secondaryVariant, seed.surfaceContainerHigh);
    });

    test('禁用态与滑轨是不透明的合成色', () {
      expect(
        miuix.sliderBackground,
        Color.alphaBlend(seed.primary.withValues(alpha: 0.2), seed.surface),
      );
      expect(
        miuix.disabledPrimary,
        Color.alphaBlend(seed.primary.withValues(alpha: 0.38), seed.surface),
      );
      expect(
        miuix.onSurfaceSecondary,
        Color.alphaBlend(seed.onSurface.withValues(alpha: 0.8), seed.surface),
      );
    });

    test('深色模式使用更重的遮罩', () {
      final darkSeed = const Color(0xFF5CB67B).asColorSchemeSeed(
        FlexSchemeVariant.material,
        Brightness.dark,
      );
      expect(
        MiuixColors.fromColorScheme(darkSeed).windowDimming,
        const Color(0x99000000),
      );
      expect(miuix.windowDimming, const Color(0x4D000000));
    });
  });

  group('miuix 字阶', () {
    final textTheme = miuixTextTheme();

    test('字号取自 miuix 的十四个槽位', () {
      expect(textTheme.displayLarge?.fontSize, 32);
      expect(textTheme.headlineSmall?.fontSize, 24);
      expect(textTheme.titleLarge?.fontSize, 20);
      expect(textTheme.titleMedium?.fontSize, 17);
      expect(textTheme.titleSmall?.fontSize, 16);
      expect(textTheme.bodyLarge?.fontSize, 17);
      expect(textTheme.bodyMedium?.fontSize, 14);
      expect(textTheme.bodySmall?.fontSize, 13);
      expect(textTheme.labelLarge?.fontSize, 17);
      expect(textTheme.labelSmall?.fontSize, 11);
    });

    test('subtitle 那一档是加粗的', () {
      expect(textTheme.labelMedium?.fontWeight, FontWeight.bold);
      expect(textTheme.bodyLarge?.fontWeight, isNull);
    });

    test('字体族与字重偏好覆盖到全部角色', () {
      final styled = miuixTextTheme(
        fontFamily: 'PiliFont',
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF2F2F2),
      );
      for (final style in [
        styled.displayLarge,
        styled.headlineLarge,
        styled.titleMedium,
        styled.bodyLarge,
        styled.bodySmall,
        styled.labelMedium,
        styled.labelSmall,
      ]) {
        expect(style?.fontFamily, 'PiliFont');
        expect(style?.fontWeight, FontWeight.w600);
        expect(style?.color, const Color(0xFFF2F2F2));
      }
    });
  });

  group('miuix 几何', () {
    test('圆角取自 miuix 各组件的默认值', () {
      expect(MiuixShapes.cardCornerRadius, 16);
      expect(MiuixShapes.buttonCornerRadius, 16);
      expect(MiuixShapes.dialogCornerRadius, 32);
      expect(MiuixShapes.menuCornerRadius, 16);
      expect(MiuixShapes.bottomSheetCornerRadius, 28);
      expect(MiuixShapes.tooltipCornerRadius, 12);
      expect(MiuixShapes.floatingBarCornerRadius, 50);
      expect(MiuixShapes.topBarHeight, 52);
    });

    test('底部弹层只圆上面两个角', () {
      expect(MiuixShapes.bottomSheetRadius.topLeft.x, 28);
      expect(MiuixShapes.bottomSheetRadius.bottomLeft, Radius.zero);
    });
  });

  group('miuix 连续圆角（squircle）', () {
    test('角块是半径的 1.1 倍，并夹在短边一半以内', () {
      expect(miuixSquircleExtension, 1.1);
      expect(miuixSquircleTile(16, const Size(200, 100)), closeTo(17.6, 0.001));
      // 短边 40，一半是 20，超出的部分被夹住。
      expect(miuixSquircleTile(32, const Size(200, 40)), closeTo(20, 0.001));
      expect(miuixSquircleTile(0, const Size(200, 100)), 0);
    });

    test('路径从角块末端起笔，普通圆角矩形则从边上起笔', () {
      const rect = Rect.fromLTWH(0, 0, 100, 60);
      final squircle = miuixSquirclePath(rect, 16);
      final rounded = miuixSquirclePath(rect, 16, enabled: false);
      final start = squircle.computeMetrics().first.getTangentForOffset(0)!;
      final roundedStart = rounded.computeMetrics().first.getTangentForOffset(0)!;
      expect(start.position.dx, closeTo(17.6, 0.01));
      expect(start.position.dy, 0);
      // 普通圆角矩形的路径从左边（或上边）的直线段开始。
      expect(
        roundedStart.position.dx == 0 || roundedStart.position.dy == 0,
        isTrue,
      );
      expect(squircle.getBounds(), rect);
      expect(rounded.getBounds(), rect);
    });

    test('顶部弹层只圆上面两角', () {
      const rect = Rect.fromLTWH(0, 0, 100, 80);
      final topOnly = miuixSquirclePath(rect, 28, topOnly: true);
      final allRound = miuixSquirclePath(rect, 28);
      expect(topOnly.contains(const Offset(0.5, 79.5)), isTrue);
      expect(allRound.contains(const Offset(0.5, 79.5)), isFalse);
    });

    test('形状可以当 ThemeData 的 shape 用，且带描边时相等性稳定', () {
      const border = MiuixSquircleBorder(cornerRadius: 16);
      expect(border.getOuterPath(const Rect.fromLTWH(0, 0, 100, 60)), isNotNull);
      expect(border.copyWith(), border);
      expect(border.scale(2).cornerRadius, 32);
      const inputBorder = MiuixSquircleInputBorder(cornerRadius: 16);
      expect(inputBorder.isOutline, isFalse);
    });
  });

  group('miuix 按压反馈', () {
    test('是替换水波纹的 ink feature 工厂，按下叠加 10%', () {
      const indication = MiuixIndication(Color(0xFF000000));
      expect(indication, isA<InteractiveInkFeatureFactory>());
      expect(indication.pressAlpha, 0.1);
      expect(indication.enterDuration, const Duration(milliseconds: 200));
      expect(indication.exitDuration, const Duration(milliseconds: 350));
    });
  });

  group('miuix 弹层手柄', () {
    test('尺寸取自 miuix', () {
      expect(MiuixDragHandle.restWidth, 45);
      expect(MiuixDragHandle.pressedWidth, 55);
      expect(MiuixDragHandle.handleHeight, 4);
      expect(MiuixDragHandle.handleRadius, 2);
      expect(MiuixDragHandle.areaHeight, 24);
    });
  });

  group('主题里的 miuix 特性', () {
    final theme = MiuixTheme.getThemeData(colors: MiuixColors.light);

    test('卡片、对话框、弹层、菜单与按钮都是连续圆角', () {
      expect(
        theme.cardTheme.shape,
        const MiuixSquircleBorder(cornerRadius: MiuixShapes.cardCornerRadius),
      );
      expect(
        theme.dialogTheme.shape,
        const MiuixSquircleBorder(cornerRadius: MiuixShapes.dialogCornerRadius),
      );
      expect(
        theme.bottomSheetTheme.shape,
        const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.bottomSheetCornerRadius,
          topOnly: true,
        ),
      );
      expect(
        theme.popupMenuTheme.shape,
        const MiuixSquircleBorder(cornerRadius: MiuixShapes.menuCornerRadius),
      );
      expect(
        theme.filledButtonTheme.style?.shape?.resolve({}),
        const MiuixSquircleBorder(cornerRadius: MiuixShapes.buttonCornerRadius),
      );
    });

    test('按压反馈换成 miuix 的整块淡入', () {
      expect(theme.splashFactory, isA<MiuixIndication>());
      expect(
        (theme.splashFactory as MiuixIndication).color,
        MiuixColors.light.onSurface,
      );
    });

    test('输入框是 MIUI 的填充样式', () {
      final decoration = theme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, MiuixColors.light.secondaryContainer);
      expect(decoration.border, isA<MiuixSquircleInputBorder>());
      expect(decoration.hintStyle?.color, MiuixColors.light.onSurfaceVariantSummary);
    });

    test('底栏不与应用自己的取色打架', () {
      // MIUI 的浮动底栏底色是 surfaceContainer（页面底色才是 surface），设成 surface 会让整条栏
      // 和页面糊在一起。
      expect(
        theme.navigationBarTheme.backgroundColor,
        MiuixColors.light.surfaceContainer,
      );
      // 指示块与图标色必须留空：PiliNara 的底栏把它们画成 6%/8% 的叠加色并按状态取图标色，
      // 主题给定不透明的值就会变成硬色块。
      expect(theme.navigationBarTheme.indicatorColor, isNull);
      expect(theme.navigationBarTheme.iconTheme, isNull);
      expect(
        theme.navigationBarTheme.labelTextStyle?.resolve({
          WidgetState.selected,
        })?.color,
        MiuixColors.light.onSurface,
      );
      expect(
        theme.navigationBarTheme.labelTextStyle?.resolve({})?.color,
        MiuixColors.light.onSurfaceVariantSummary,
      );
    });
  });
}
