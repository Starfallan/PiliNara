import 'package:PiliPlus/models_new/bubble/base_info.dart';
import 'package:PiliPlus/models_new/bubble/category.dart';
import 'package:PiliPlus/models_new/bubble/content.dart';
import 'package:PiliPlus/models_new/bubble/sort_info.dart';

class BubbleData {
  BaseInfo? baseInfo;
  Content? content;
  Category? category;
  SortInfo? sortInfo;

  BubbleData({
    this.baseInfo,
    this.content,
    this.category,
    this.sortInfo,
  });

  factory BubbleData.fromJson(Map<String, dynamic> json) => BubbleData(
    baseInfo: json['base_info'] == null
        ? null
        : BaseInfo.fromJson(json['base_info'] as Map<String, dynamic>),
    content: json['content'] == null
        ? null
        : Content.fromJson(json['content'] as Map<String, dynamic>),
    category: json['category'] == null
        ? null
        : Category.fromJson(json['category'] as Map<String, dynamic>),
    sortInfo: json['sort_info'] == null
        ? null
        : SortInfo.fromJson(json['sort_info'] as Map<String, dynamic>),
  );
}
