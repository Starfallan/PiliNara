import 'package:PiliPlus/plugin/pl_player/models/fullscreen_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final defaults = FullscreenLayout.defaults(isMobile: true);

  test('inherits the whole old action switch and right-side lock order', () {
    final layout = FullscreenLayout.legacy(
      isMobile: true,
      showActions: false,
      showScreenshot: false,
      lockOnRight: true,
      showOnline: true,
    );
    expect(layout.items(PlayerLayoutRegion.actions).every(
      (item) => !layout.shows(item),
    ), isTrue);
    expect(layout.shows(PlayerLayoutControl.download), isFalse);
    expect(layout.items(PlayerLayoutRegion.left), isEmpty);
    expect(layout.items(PlayerLayoutRegion.right), [
      PlayerLayoutControl.screenshot,
      PlayerLayoutControl.lock,
    ]);
    expect(layout.shows(PlayerLayoutControl.screenshot), isFalse);
    expect(layout.shows(PlayerLayoutControl.online), isTrue);
  });

  test('invalid configuration falls back without mutating legacy settings', () {
    final legacy = FullscreenLayout.legacy(isMobile: false, showActions: false);
    for (final data in [null, 'invalid', [], {'version': 99}]) {
      expect(FullscreenLayout.fromJson(data, fallback: legacy), same(legacy));
    }
  });

  test('repairs duplicates, unknown controls, wrong regions and missing entries', () {
    final layout = FullscreenLayout.fromJson({
      'version': 1,
      'regions': {
        'header': ['qa', 'pip', 'pip', 'unknown', 'clock'],
        'bottom': ['speed', 12, 'subtitle', 'share'],
        'left': ['screenshot', 'lock'],
        'right': ['screenshot', 'lock'],
      },
      'hidden': ['like', 'like', 'fullscreen', null],
    }, fallback: defaults);
    final flattened = layout.regions.values.expand((items) => items).toList();
    expect(flattened.toSet().length, flattened.length);
    expect(flattened.length, PlayerLayoutControl.values.where((item) => item.region != null).length);
    expect(layout.items(PlayerLayoutRegion.header).first, PlayerLayoutControl.pip);
    expect(layout.items(PlayerLayoutRegion.bottom).take(2), [
      PlayerLayoutControl.speed,
      PlayerLayoutControl.subtitle,
    ]);
    expect(layout.items(PlayerLayoutRegion.left), [
      PlayerLayoutControl.screenshot,
      PlayerLayoutControl.lock,
    ]);
    expect(layout.items(PlayerLayoutRegion.right), isEmpty);
    expect(layout.hidden, {PlayerLayoutControl.like});
  });

  test('moving a control rejects crossing regions and information labels', () {
    expect(defaults.move(PlayerLayoutControl.share, PlayerLayoutRegion.bottom, 0), same(defaults));
    expect(defaults.move(PlayerLayoutControl.clock, PlayerLayoutRegion.header, 0), same(defaults));
  });

  test('inserts in both directions without changing hidden state or original', () {
    final hidden = defaults.toggle(PlayerLayoutControl.like);
    final moved = hidden.move(PlayerLayoutControl.like, PlayerLayoutRegion.actions, 5);
    expect(moved.items(PlayerLayoutRegion.actions).last, PlayerLayoutControl.like);
    expect(moved.shows(PlayerLayoutControl.like), isFalse);
    expect(defaults.items(PlayerLayoutRegion.actions).first, PlayerLayoutControl.like);
    expect(defaults.shows(PlayerLayoutControl.like), isTrue);
    final back = moved.move(PlayerLayoutControl.like, PlayerLayoutRegion.actions, 0);
    expect(back.items(PlayerLayoutRegion.actions), defaults.items(PlayerLayoutRegion.actions));
  });

  test('side controls can move to an empty side and retain same-side order', () {
    final right = defaults.move(PlayerLayoutControl.lock, PlayerLayoutRegion.right, 0);
    expect(right.items(PlayerLayoutRegion.left), isEmpty);
    expect(right.items(PlayerLayoutRegion.right), [
      PlayerLayoutControl.lock,
      PlayerLayoutControl.screenshot,
    ]);
    final left = right.move(PlayerLayoutControl.screenshot, PlayerLayoutRegion.left, 0);
    expect(left.items(PlayerLayoutRegion.left), [PlayerLayoutControl.screenshot]);
    expect(left.items(PlayerLayoutRegion.right), [PlayerLayoutControl.lock]);
  });

  test('round trip persists ordering and hidden information independently', () {
    final layout = defaults
        .toggle(PlayerLayoutControl.clock)
        .toggle(PlayerLayoutControl.online)
        .move(PlayerLayoutControl.qa, PlayerLayoutRegion.bottom, 0)
        .move(PlayerLayoutControl.lock, PlayerLayoutRegion.right, 1);
    final restored = FullscreenLayout.fromJson(layout.toJson(), fallback: defaults);
    expect(restored.toJson(), layout.toJson());
    expect(restored.hidden.clear, throwsUnsupportedError);
    expect(() => restored.items(PlayerLayoutRegion.bottom).clear(), throwsUnsupportedError);
  });
}
