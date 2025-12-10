# Danmaku Font Size Scaling for Merged Danmaku

## Overview

This feature implements font size scaling for merged duplicate danmaku, similar to Pakku.js. When multiple identical danmaku are merged together, the font size increases logarithmically based on the number of merged items, making popular danmaku more visually prominent.

## Implementation Status

### Completed in PiliPlus

1. **Font Size Calculation Logic** (`lib/pages/danmaku/controller.dart`)
   - Added `_calcEnlargeRate()` method that implements the Pakku.js formula
   - Added `_calcEnlargedFontSize()` method to calculate the final font size
   - Modified `handleDanmaku()` to calculate and store enlarged font sizes in `DanmakuElem.fontsize`

2. **Formula**
   ```dart
   enlargeRate = count <= 5 ? 1.0 : log(count) / log(5)
   enlargedFontSize = baseFontSize * enlargeRate
   ```

### Pending: canvas_danmaku Package Updates

The `canvas_danmaku` package currently does not support per-item font sizes for regular danmaku (only for special danmaku via `SpecialDanmakuContentItem`). To complete this feature, the following changes are needed in canvas_danmaku:

1. **Add fontSize field to DanmakuContentItem**
   ```dart
   class DanmakuContentItem<T> {
     final String text;
     Color color;
     final DanmakuItemType type;
     final bool selfSend;
     final bool isColorful;
     final int? count;
     final double? fontSize;  // <-- Add this field
     final T? extra;
     
     DanmakuContentItem(
       this.text, {
       this.color = Colors.white,
       this.type = DanmakuItemType.scroll,
       this.selfSend = false,
       this.isColorful = false,
       this.count,
       this.fontSize,  // <-- Add this parameter
       this.extra,
     });
   }
   ```

2. **Modify generateParagraph() in utils.dart**
   ```dart
   static ui.Paragraph generateParagraph({
     required DanmakuContentItem content,
     required double fontSize,
     required int fontWeight,
   }) {
     // Use content.fontSize if available, otherwise use the global fontSize
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
           fontSize: effectiveFontSize * 0.6,
         ))
         ..addText('($count)')
         ..pop();
     }

     builder
       ..pushStyle(ui.TextStyle(color: content.color, fontSize: effectiveFontSize))
       ..addText(content.text);

     return builder.build()
       ..layout(const ui.ParagraphConstraints(width: double.infinity));
   }
   ```

3. **Update recordDanmakuImage() similarly** to use `content.fontSize` if available

4. **Update danmaku_screen.dart** to pass content.fontSize when calling these methods

### Using the Feature (Once canvas_danmaku is Updated)

Once canvas_danmaku supports per-item fontSize, update `lib/pages/danmaku/view.dart`:

```dart
_controller!.addDanmaku(
  DanmakuContentItem(
    e.content,
    color: blockColorful ? Colors.white : DmUtils.decimalToColor(e.color),
    type: DmUtils.getPosition(e.mode),
    isColorful: playerController.showVipDanmaku &&
        e.colorful == DmColorfulType.VipGradualColor,
    count: e.count > 1 ? e.count : null,
    fontSize: e.fontsize > 0 ? e.fontsize.toDouble() : null,  // <-- Add this line
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

To test the implementation once complete:

1. Enable danmaku merging in settings
2. Play a video with many duplicate danmaku
3. Verify that merged danmaku (shown with count like "(5)text") appear larger as the count increases
4. Danmaku with count ≤ 5 should appear at normal size
5. Danmaku with count > 5 should scale logarithmically

## References

- Original feature request: [Issue #XX]
- Pakku.js implementation: https://github.com/xmcp/pakku.js/
- Pakku.js enlarge rate formula: `count<=5 ? 1 : (Math.log(count) / MATH_LOG5)`
