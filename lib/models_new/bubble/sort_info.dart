import 'package:PiliPlus/models_new/bubble/sort_item.dart';

class SortInfo {
  bool? showSort;
  List<SortItem>? sortItems;
  int? curSortType;

  SortInfo({
    this.showSort,
    this.sortItems,
    this.curSortType,
  });

  factory SortInfo.fromJson(Map<String, dynamic> json) => SortInfo(
    showSort: json['show_sort'] as bool?,
    sortItems: (json['sort_items'] as List<dynamic>?)
        ?.map((e) => SortItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    curSortType: json['cur_sort_type'] as int?,
  );
}
