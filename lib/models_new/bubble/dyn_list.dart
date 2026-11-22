import 'package:PiliPlus/models_new/bubble/meta.dart';
import 'package:PiliPlus/services/bubble_read_service.dart';

class DynList {
  String? dynId;
  String? title;
  bool? isRead;
  Meta? meta;

  DynList({
    this.dynId,
    this.title,
    this.isRead,
    this.meta,
  });

  factory DynList.fromJson(Map<String, dynamic> json) => DynList(
    dynId: json['dyn_id'] as String?,
    title: json['title'] as String?,
    isRead: json['is_read'] as bool?,
    meta: json['meta'] == null
        ? null
        : Meta.fromJson(json['meta'] as Map<String, dynamic>),
  );

  bool get isTop => meta?.tags?.contains('TOP') ?? false;
  bool get isFeatured => meta?.tags?.contains('FEATURE') ?? false;

  /// 接口的 is_read 从不下发 true，实际已读以本地记录为准
  bool get read => isRead == true || BubbleReadService.isRead(dynId);
}
