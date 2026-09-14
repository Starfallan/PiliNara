/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';

/// Shared element used by video thumbnails and the inline video player.
///
/// The source thumbnail and the destination player intentionally do not need
/// to have the same child. During a push we use the destination player as the
/// flight shuttle; during a pop we keep the player in flight until it reaches
/// the thumbnail. The beta switch deliberately disables in-app PiP because
/// both features need to own the same player transition at that moment.
class VideoHero extends StatelessWidget {
  const VideoHero({
    super.key,
    required this.tag,
    required this.child,
    this.enabled,
  });

  final String? tag;
  final Widget child;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final heroTag = tag;
    if (heroTag == null || !(enabled ?? Pref.enableVideoSharedElement)) {
      return child;
    }

    return Hero(
      tag: heroTag,
      transitionOnUserGestures: true,
      // Interpolate the whole rect, including width and height. This gives
      // the requested thumbnail expand/player shrink instead of translation.
      createRectTween: (begin, end) => _VideoRectTween(begin: begin, end: end),
      flightShuttleBuilder:
          (
            _flightContext,
            _animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            final fromHero = fromHeroContext.widget as Hero;
            final toHero = toHeroContext.widget as Hero;
            return flightDirection == HeroFlightDirection.pop
                ? fromHero.child
                : toHero.child;
          },
      child: child,
    );
  }
}

/// Applies a gentle curve while still interpolating every edge of the rect.
class _VideoRectTween extends RectTween {
  _VideoRectTween({required Rect? begin, required Rect? end})
    : super(begin: begin, end: end);

  @override
  Rect? lerp(double t) => super.lerp(Curves.easeInOutCubic.transform(t));
}
