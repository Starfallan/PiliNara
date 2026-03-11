import 'package:PiliPlus/utils/parse_string.dart';

class Top {
  List<TopImage>? imgUrls;

  Top({this.imgUrls});

  Top.fromJson(Map<String, dynamic> json) {
    try {
      final list = json['result'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        imgUrls = list.map((e) => TopImage.fromJson(e)).toList();
      }
    } catch (_) {}
  }
}

class TopImage {
  late final String cover;
  late final double dy;

  TopImage.fromJson(Map<String, dynamic> json) {
    cover =
        noneNullOrEmptyString(json['item']?['image']?['default_image']) ??
        json['cover'];
    try {
      final Map image = json['item']['image'] ?? json['item']['animation'];
      final num halfHeight = (image['height'] as num) / 2;
      final List<num> location = (image['location'] as String)
          .split('-')
          .map(num.parse)
          .toList();
      final start = location[1];
      final end = location[2];
      dy = (start + (end - start) / 2 - halfHeight) / halfHeight;
    } catch (_) {
      dy = 0.0;
    }
  }
}
