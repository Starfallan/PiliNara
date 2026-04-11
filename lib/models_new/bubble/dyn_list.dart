import 'package:PiliPlus/models_new/bubble/meta.dart';

class DynList {
  String? dynId;
  String? title;
  Meta? meta;

  DynList({
    this.dynId,
    this.title,
    this.meta,
  });

  factory DynList.fromJson(Map<String, dynamic> json) => DynList(
    dynId: json['dyn_id'] as String?,
    title: json['title'] as String?,
    meta: json['meta'] == null
        ? null
        : Meta.fromJson(json['meta'] as Map<String, dynamic>),
  );
}
