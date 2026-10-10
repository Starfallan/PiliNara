import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/miuix/miuix_colors.dart';
import 'package:PiliPlus/utils/miuix/miuix_shapes.dart';
import 'package:PiliPlus/utils/miuix/miuix_text_styles.dart';
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

    test('中性填充色取自 outlineVariant，与 miuix 的取色方式一致', () {
      expect(miuix.secondary, seed.outlineVariant);
      expect(miuix.onSecondary, seed.outline);
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
}
