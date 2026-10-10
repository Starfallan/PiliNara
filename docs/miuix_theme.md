# Miuix Theme

## Overview

PiliNara's theme *is* the miuix theme. Colors, corner radii and the type scale are all taken from
Miuix, the MIUI / HyperOS design system, instead of being derived from Material defaults:

* **Colors** — the MIUI color roles of `top.yukonga.miuix.kmp.theme.Colors`, including the fixed
  MIUI light and dark palettes and the Monet-style generation miuix uses for key colors.
* **Shapes** — MIUI's corner radii: 16 for cards, buttons, text fields and menus, 32 for dialogs,
  28 for the top corners of a bottom sheet, 12 for tooltips, and a 52 dp top bar.
* **Type scale** — Miuix's fourteen text slots (main 17, body2 14, footnote1 13, title1 32 …).

## Where it lives

| File | Contents |
|------|----------|
| `lib/utils/miuix/miuix_colors.dart` | The `MiuixColors` token set: `light` / `dark` are ported 1:1 from miuix's `lightColorScheme()` / `darkColorScheme()`. Also holds the mapping to Material's `ColorScheme` and the translation of any other scheme into MIUI roles. |
| `lib/utils/miuix/miuix_shapes.dart` | `MiuixShapes`, the corner radii and bar heights of the miuix components. |
| `lib/utils/miuix/miuix_text_styles.dart` | `miuixTextTheme()`, Miuix's type scale as a Material `TextTheme`. |
| `lib/utils/miuix/miuix_theme.dart` | `MiuixTheme.getThemeData()`, which builds the app's `ThemeData` from those tokens (card, dialog, bottom sheet, popup menu, top bar, snackbar, tooltip, switch, slider, buttons, navigation bars). |
| `lib/utils/theme_utils.dart` | The app's entry point: `ThemeUtils.getThemeData()` resolves a `MiuixColors` and applies the pure-black mode on top. |
| `lib/models/common/theme/theme_color_type.dart` | `miuixKeyColor` (MIUI blue) and its position in the palette picker. |

## How a color scheme is resolved

`MyApp.getAllTheme()` in `lib/main.dart` picks one of three paths:

1. **MIUI blue (the default)** — selecting `MIUI 蓝` uses miuix's fixed palettes
   (`MiuixColors.light` / `MiuixColors.dark`) verbatim. This is what miuix itself renders in its
   default `ColorSchemeMode.System`, and it is what a new install gets.
2. **Dynamic color** — the wallpaper's Material scheme is translated into MIUI roles by
   `MiuixColors.fromColorScheme()`, which is the inverse of miuix's
   `mapMd3RolesToMiuixColorsCommon`. This is miuix's Monet mode. It is off by default, because
   miuix's own default theme is the fixed palette.
3. **A brand color** — the chosen seed is turned into a Material scheme by `flex_seed_scheme`
   (the existing palette style setting still applies) and then translated the same way.

Whatever the path, `ThemeUtils.getThemeData()` ends up with a `MiuixColors` and builds the theme
from it, so a custom brand color keeps MIUI's neutral fills, dividers and dimming rather than
Material's.

## Mapping to Material roles

PiliNara's widgets read Material's `ColorScheme`, so the MIUI tokens are mapped onto it:

| Material | miuix |
|----------|-------|
| `primary` / `onPrimary` | `primary` / `onPrimary` |
| `primaryContainer` / `onPrimaryContainer` | `primaryContainer` / `onPrimaryContainer` |
| `primaryFixed` / `onPrimaryFixed` | `primaryVariant` / `onPrimaryVariant` |
| `secondary` / `onSecondary` | `secondary` / `onSecondary` |
| `secondaryContainer` / `onSecondaryContainer` | `secondaryContainer` / `onSecondaryVariant` |
| `tertiary` / `tertiaryContainer` | `tertiaryContainer` |
| `surface` / `onSurface` | `surface` / `onSurface` |
| `surfaceContainer` … `Highest` | the same-named tokens |
| `surfaceContainerLowest` / `Low` | `surfaceVariant` / `secondaryVariant` |
| `surfaceDim` / `surfaceBright` | `surfaceContainerHigh` / `surfaceContainer` |
| `onSurfaceVariant` / `outline` | `onSurfaceVariantSummary` |
| `outlineVariant` | `dividerLine` |
| `scrim` | `windowDimming` |
| `inverseSurface` / `onInverseSurface` | `onSecondaryVariant` / `secondaryVariant` |
| `surfaceTint` | transparent (MIUI surfaces are flat and untinted) |

PiliNara has always used `outline` as its secondary text color, so it lands on MIUI's summary text
tone; real dividers are `outlineVariant`, which is `dividerLine`.

Two pairings deliberately differ from miuix's own:

* PiliNara paints icons and labels on `secondaryContainer`, while miuix's `onSecondaryContainer` is
  a placeholder gray (`#A9A9A9` in light mode) that is nearly invisible on the `#F0F0F0` fill.
  miuix pairs that fill with `onSecondaryVariant` (`#303030`), so the app does too.
* `outline` carries PiliNara's secondary text, as described above.

## Type scale

| Material | miuix slot | Size |
|----------|------------|------|
| `displayLarge`, `headlineLarge` | title1 | 32 |
| `displayMedium`, `headlineMedium`, `headlineSmall` | title2 | 24 |
| `displaySmall`, `titleLarge` | title3 | 20 |
| `titleMedium` | headline1 | 17 |
| `titleSmall` | headline2 | 16 |
| `bodyLarge` | main (paragraph, body1 fold in here) | 17 |
| `bodyMedium` | body2 | 14 |
| `bodySmall` | footnote1 | 13 |
| `labelLarge` | button | 17 |
| `labelMedium` | subtitle | 14, bold |
| `labelSmall` | footnote2 | 11 |

Miuix only sets a line height on `paragraph` (1.2 em), so the styles leave `height` unset and let
the font's own metrics apply. `title4` (18) has no separate Material role; it sits next to
`titleMedium` and `titleLarge`. The font family and weight preferences still override every role,
as they did before.

Miuix takes its text color from `LocalContentColor`; Flutter's widgets read it out of the
`TextTheme` roles instead, so `miuixTextTheme()` is called with `color: onSurface`. Without it,
widgets such as `ListTile` would paint black text on a `#242424` card in dark mode.

## Limits of the port

* Miuix draws continuous (squircle) corners on Android; Flutter's `BorderRadius` is a plain
  circular corner. The radii match, the curve does not.
* MIUI has fewer surface levels than Material 3. `surfaceDim` / `surfaceBright` and the two lowest
  container roles are therefore derived, as listed above.
* MIUI has no inverse roles, no `surfaceTint` and no `background` slot in Material's `ColorScheme`
  any more; those are derived as described in the table.
* PiliNara's pure-black mode is kept: it still darkens the canvas and each container layer on top
  of the MIUI palette.

## Tests

`test/miuix_theme_test.dart` covers the fixed palettes, the palette picker entry, the role mapping,
the translation of a Material scheme into MIUI roles, the type scale and the shape tokens:

```bash
flutter test test/miuix_theme_test.dart
```
