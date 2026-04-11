import 'package:PiliPlus/models_new/bubble/dyn_list.dart';

class Content {
  String? count;
  List<DynList>? dynList;

  Content({this.count, this.dynList});

  factory Content.fromJson(Map<String, dynamic> json) => Content(
    count: json['count'] as String?,
    dynList: (json['dyn_list'] as List<dynamic>?)
        ?.map((e) => DynList.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
