import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_layout.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/common_btn.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// 不附带业务动作的播放器控件外观，供布局编辑器展示完整控件集合。
class PlayerControlFace extends StatelessWidget {
  const PlayerControlFace({
    super.key,
    required this.control,
    this.bottomWidth = 42,
    this.fit = '自动',
    this.speed = '1.0X',
    this.quality = '1080P+',
    this.superResolution = '禁用',
  });

  final PlayerLayoutControl control;
  final double bottomWidth;
  final String fit;
  final String speed;
  final String quality;
  final String superResolution;

  Widget _header(IconData icon, double size) => SizedBox(
    width: 42,
    height: 34,
    child: IconButton(
      style: const ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
      onPressed: null,
      icon: Icon(icon, size: size, color: Colors.white),
    ),
  );

  Widget _action(IconData icon) => SizedBox(
    width: 42,
    height: 34,
    child: ActionItem(
      expand: false,
      icon: Icon(icon, color: Colors.white),
      semanticsLabel: control.label,
    ),
  );

  Widget _bottom(IconData icon, [double size = 22]) => ComBtn(
    width: bottomWidth,
    height: 30,
    icon: Icon(icon, size: size, color: Colors.white),
  );

  Widget _text(String text, {double size = 13, bool bottom = false}) {
    final child = Text(text, style: TextStyle(color: Colors.white, fontSize: size));
    return bottom
        ? SizedBox(
            height: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: child),
            ),
          )
        : child;
  }

  Widget _side(IconData icon, double size) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0x45000000),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: ComBtn(icon: Icon(icon, size: size, color: Colors.white)),
  );

  @override
  Widget build(BuildContext context) => switch (control) {
    .pin => _header(Icons.push_pin_outlined, 19),
    .sponsorSubmit => _header(CustomIcons.shield_play_arrow, 20),
    .sponsorInfo => _header(MdiIcons.advertisements, 19),
    .pip => _header(Icons.picture_in_picture_outlined, 19),
    .like => _action(FontAwesomeIcons.thumbsUp),
    .coin => _action(FontAwesomeIcons.b),
    .favorite => _action(FontAwesomeIcons.star),
    .download => _action(CustomIcons.download),
    .share => _action(FontAwesomeIcons.shareFromSquare),
    .viewPoints => _bottom(CustomIcons.view_headline_rotate_90),
    .dmChart => _bottom(Icons.show_chart),
    .superResolution => _text(superResolution, bottom: true),
    .episode => _bottom(Icons.list),
    .fit => _text(fit, bottom: true),
    .aiTranslate => _bottom(Icons.translate, 18),
    .subtitle => _bottom(Icons.closed_caption_off_outlined),
    .speed => _text(speed, bottom: true),
    .qa => _text(quality, bottom: true),
    .lock => _side(FontAwesomeIcons.lockOpen, 15),
    .screenshot => _side(Icons.photo_camera, 20),
    .clock => _text('13:24'),
    .battery => _text('100%'),
    .online => _text('16人正在看', size: 11),
    .dmCount => _text('12条弹幕', size: 11),
  };
}
