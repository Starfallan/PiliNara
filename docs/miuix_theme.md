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
2. **A brand color** — the chosen seed is turned into a Material scheme by `flex_seed_scheme`
   (tonal spot, i.e. miuix's default palette style) and then translated into MIUI roles by
   `MiuixColors.fromColorScheme()`, the inverse of miuix's `mapMd3RolesToMiuixColorsCommon`.
   That is miuix's Monet mode.

Material 3's own colour features are gone: the dynamic colour (Monet-from-wallpaper) toggle and the
palette-style picker were removed from the settings, along with the page-transition and predictive
back switches. The theme is now miuix's fixed palette or the brand colour the user picks, and the
motion below.

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
| `secondary` / `onSecondary` | `onBackgroundVariant` / `onSecondary` |
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
* PiliNara's `secondary` is a *secondary text / icon* tone (and the fallback fill of the bottom
  bar's selection pill), whereas miuix's `secondary` is a neutral fill (`#E6E6E6` in light mode)
  that is unreadable as text. miuix's tint for content on a surface is `onBackgroundVariant`
  (which is what its Monet mapping resolves to `primary`), so `secondary` uses that.

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

* MIUI has fewer surface levels than Material 3. `surfaceDim` / `surfaceBright` and the two lowest
  container roles are therefore derived, as listed above.
* MIUI has no inverse roles, no `surfaceTint` and no `background` slot in Material's `ColorScheme`
  any more; those are derived as described in the table.
* PiliNara's pure-black mode is kept: it still darkens the canvas and each container layer on top
  of the MIUI palette.
* The continuous corners are drawn as a path (see below) rather than with miuix's runtime shader,
  and a `BoxDecoration` only accepts a `BorderRadius`, so tooltips keep circular corners.

## Miuix behaviours

The theme does not stop at tokens: miuix's interaction and surface behaviour is applied too.

### Continuous corners (squircle)

MIUI / HyperOS corners are *continuous*: the corner tile is `cornerRadius × 1.1`, and the straight
edges meet it through a cubic Bézier with a fixed control ratio of `0.643` — miuix's
`SquircleDefaults.Extension` and `SQUIRCLE_CONTROL`. `lib/utils/miuix/miuix_squircle.dart` builds
that silhouette as a `Path` and exposes it as `MiuixSquircleBorder` (and
`MiuixSquircleInputBorder` for fields), so cards, dialogs, sheets, popup menus, buttons and the
navigation indicator all use it. Bottom sheets use the top-only variant, and `enabled: false` falls
back to plain rounded corners, which is what miuix itself does where the runtime shader is
unavailable.

### Press feedback

Material's ripple (on Android M3, `InkSparkle`) is replaced by `MiuixIndication`: a press fades a
flat 10 % overlay over the whole surface — 200 ms in, 350 ms out — which is miuix's
`MiuixIndication` with `PRESS_ALPHA_DELTA = 0.10` and its 0.2 s / 0.35 s springs. miuix additionally
folds hover (6 %) and focus (8 %) into the same overlay; in Flutter those remain the job of
`InkWell.overlayColor`.

Two details of Flutter's ink pipeline matter here:

* The overlay is a **press** tint, so it has to fade in when the ink feature is *created* (touch
  down), not in `confirm()`: Flutter only calls `confirm()` when the tap is recognised, i.e. on
  release, so ramping up there makes the tint invisible while a finger is held down.
* The fade-out has to be scheduled by `confirm()` (and `cancel()`) itself, because Flutter never
  calls `cancel()` after a successful tap. Without it the 10 % tint stays on every widget that was
  tapped — a colour block left behind on the previously selected tab.
* The drawing itself goes through the SDK's `paintInkCircle`: ink features work in the *reference
  box's local coordinates* and must apply the transform Flutter passes in. Skipping it paints the
  overlay at the shared `Material`'s origin, so in a bottom bar or a tab bar (many `InkWell`s on one
  `Material`) every press appears on the **first** item. A large radius plus a clip to the control's
  own rect/shape produces miuix's flat block rather than a circular ripple.

### Text fields

MIUI fields are filled rather than outlined: `secondaryContainer` background, 16 dp continuous
corners, no border until focus (primary) or error (error colour), 12 dp inner padding. That is the
`InputDecorationThemeData` in `MiuixTheme`.

### Bottom sheets

Sheets carry miuix's drag handle: a 24 dp grab strip with a 45 × 4 dp pill (radius 2) at 20 % of the
`onSurfaceVariant` tone, growing to 55 dp / 35 % while pressed. `MiuixDragHandle` is painted above
the sheet content by `lib/common/widgets/scaffold/bottom_sheet.dart`; it draws and listens for the
press only, so dragging still belongs to the sheet's own gesture recogniser.

### Overscroll

MIUI stretches the scrollable at its ends instead of showing the Android glow. PiliNara's
`CustomScrollBehavior` already used `StretchingOverscrollIndicator` on Android, which matches
miuix's `MiuixOverscrollEffect`, so this needed no change.

### Motion

`lib/utils/miuix/miuix_motion.dart` carries miuix's own timing instead of Flutter's defaults:

* `MiuixMotion.programmatic` is the curve miuix bakes for programmatic navigation
  (`NavProgrammaticEasing`): the step response of an underdamped spring (response 0.8, damping 0.95)
  solved point by point — a brisk middle and a long tail, played over
  `MiuixMotion.programmaticDuration` (500 ms, `NavDriverSpec.PROGRAMMATIC_DURATION_MILLIS`).
* `decelerate` / `accelerate` / `sinOut` are miuix's `DecelerateEasing`, `AccelerateEasing` and
  `SinOutEasing`.
* `spring(damping, response)` is `folmeSpring`: stiffness `(2π / response)²`, damping ratio as given.
* `fast` / `fastExit` / `enter` / `exit` are the durations miuix's own components use (sheet handle
  100 / 150 ms, press feedback 200 / 350 ms).

The theme installs `MiuixPageTransitionsBuilder` for every platform: the entering page slides in
full width from the trailing edge and the covered page parallaxes a quarter width with a 10 % alpha
falloff — miuix's `NavTransitions.MiuixDefault` geometry with the motion above. Page-routed screens
go through GetX, which mirrors the same slide (its `rightToLeftWithFade`).

The covered page is additionally dimmed by up to 50 % (`NavDisplayEffects.dimAmount`) as the motion
runs, which is how miuix's effect layer darkens the layer below the entering one.

### Bottom navigation bar

The theme sets the bar's fill to `surfaceContainer` (MIUI's floating bar; the page is `surface`) and
`indicatorColor` stays unset because PiliNara paints the selected pill itself as a 6 % (light) / 8 %
(dark) overlay; putting an opaque colour into the theme turns the selection into a hard block on the
bar, which is what an earlier revision did. Icon and label colours follow miuix's
`FloatingNavigationBar`, where selected and unselected content share one colour
(`onSurfaceContainer`) and only the indicator marks the selection — miuix's `showDivider` is off by
default, so the bar carries no separators. The label size is Miuix's `footnote2` (11).

## Tests

`test/miuix_theme_test.dart` covers the fixed palettes, the palette picker entry, the role mapping,
the translation of a Material scheme into MIUI roles, the type scale and the shape tokens:

```bash
flutter test test/miuix_theme_test.dart
```
