class SortItem {
  int? sortType;
  String? text;

  SortItem({this.sortType, this.text});

  factory SortItem.fromJson(Map<String, dynamic> json) => SortItem(
    sortType: json['sort_type'] as int?,
    text: json['text'] as String?,
  );
}
