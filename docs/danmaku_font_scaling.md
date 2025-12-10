# Danmaku Font Size Scaling for Merged Danmaku

## Overview

This feature implements font size scaling for merged duplicate danmaku, similar to Pakku.js. When multiple identical danmaku are merged together, the font size increases logarithmically based on the number of merged items, making popular danmaku more visually prominent.

## Current Implementation Status

### ✅ Completed in PiliPlus

The PiliPlus-side implementation is **complete**:

1. **Font Size Calculation Logic** (`lib/pages/danmaku/controller.dart`)
   - Added `_calcEnlargeRate()` method implementing the Pakku.js formula: `count <= 5 ? 1.0 : log(count) / log(5)`
   - Added `_calcEnlargedFontSize()` method to calculate the final scaled font size
   - Modified `handleDanmaku()` to calculate and store enlarged font sizes in `DanmakuElem.fontsize` field during danmaku merging

2. **Formula**
   ```dart
   enlargeRate = count <= 5 ? 1.0 : log(count) / log(5)
   enlargedFontSize = baseFontSize * enlargeRate
   ```

3. **Example scaling**:
   - 1-5 identical danmaku: 1.0x (base size, e.g., 25px)
   - 10 identical danmaku: 1.43x (e.g., ~36px)
   - 20 identical danmaku: 1.86x (e.g., ~47px)
   - 50 identical danmaku: 2.43x (e.g., ~61px)
   - 100 identical danmaku: 2.86x (e.g., ~72px)

### 🔄 Pending: canvas_danmaku Package Updates

The `canvas_danmaku` package (external Git dependency) currently does not support per-item font sizes for regular danmaku. The package needs the following minimal changes to complete this feature:

#### Required Changes in canvas_danmaku

**1. Add fontSize field to DanmakuContentItem** (`lib/models/danmaku_content_item.dart`)

```dart
class DanmakuContentItem<T> {
  final String text;
  Color color;
  final DanmakuItemType type;
  final bool selfSend;
  final bool isColorful;
  final int? count;
  final double? fontSize;  // 👈 ADD THIS FIELD
  final T? extra;
  
  DanmakuContentItem(
    this.text, {
    this.color = Colors.white,
    this.type = DanmakuItemType.scroll,
    this.selfSend = false,
    this.isColorful = false,
    this.count,
    this.fontSize,  // 👈 ADD THIS PARAMETER
    this.extra,
  });
}
```

**2. Modify generateParagraph()** (`lib/utils/utils.dart`)

```dart
static ui.Paragraph generateParagraph({
  required DanmakuContentItem content,
  required double fontSize,
  required int fontWeight,
}) {
  // 👇 Use content.fontSize if available, otherwise use global fontSize
  final effectiveFontSize = content.fontSize ?? fontSize;
  
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.left,
    fontWeight: FontWeight.values[fontWeight],
    textDirection: TextDirection.ltr,
    maxLines: 1,
  ));

  if (content.count case final count?) {
    builder
      ..pushStyle(ui.TextStyle(
        color: content.color,
        fontSize: effectiveFontSize * 0.6,  // 👈 Use effectiveFontSize
      ))
      ..addText('($count)')
      ..pop();
  }

  builder
    ..pushStyle(ui.TextStyle(color: content.color, fontSize: effectiveFontSize))  // 👈 Use effectiveFontSize
    ..addText(content.text);

  return builder.build()
    ..layout(const ui.ParagraphConstraints(width: double.infinity));
}
```

**3. Update recordDanmakuImage()** (`lib/utils/utils.dart`)

Apply the same `content.fontSize ?? fontSize` pattern in the `recordDanmakuImage()` function for both the content and stroke paragraphs.

### 🚀 Activation: Update PiliPlus view.dart

Once canvas_danmaku is updated, uncomment and add the fontSize parameter in `lib/pages/danmaku/view.dart`:

```dart
_controller!.addDanmaku(
  DanmakuContentItem(
    e.content,
    color: blockColorful ? Colors.white : DmUtils.decimalToColor(e.color),
    type: DmUtils.getPosition(e.mode),
    isColorful: playerController.showVipDanmaku &&
        e.colorful == DmColorfulType.VipGradualColor,
    count: e.count > 1 ? e.count : null,
    fontSize: e.fontsize > 0 ? e.fontsize.toDouble() : null,  // 👈 ADD THIS LINE
    selfSend: e.isSelf,
    extra: VideoDanmaku(
      id: e.id.toInt(),
      mid: e.midHash,
      like: e.like.toInt(),
    ),
  ),
);
```

## Testing

Once canvas_danmaku is updated and the above line is added:

1. Enable danmaku merging in PiliPlus settings
2. Play a video with many duplicate danmaku (popular videos work well)
3. Verify that merged danmaku appear larger as the count increases:
   - Count ≤ 5: Normal size
   - Count > 5: Progressively larger, following logarithmic scaling
4. The `(count)` prefix should scale proportionally with the danmaku text

## Next Steps

1. **Submit PR to canvas_danmaku**: The changes needed are minimal and well-defined above
2. **Update PiliPlus**: Once canvas_danmaku is updated, add the `fontSize` parameter in view.dart (one line change)
3. **Test**: Verify the feature works as expected with real danmaku data

## References

- Original feature request: [增加重复弹幕合并时弹幕字体随重复数量增多而增大的功能]
- Pakku.js implementation: https://github.com/xmcp/pakku.js/
- Pakku.js enlarge rate formula: `count<=5 ? 1 : (Math.log(count) / MATH_LOG5)`
- canvas_danmaku repository: https://github.com/bggRGjQaUbCoE/canvas_danmaku
