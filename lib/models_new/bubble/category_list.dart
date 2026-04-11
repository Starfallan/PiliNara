class CategoryList {
  String? id;
  String? name;
  int? type;

  CategoryList({this.id, this.name, this.type});

  factory CategoryList.fromJson(Map<String, dynamic> json) => CategoryList(
    id: json['id'] as String?,
    name: json['name'] as String?,
    type: json['type'] as int?,
  );
}
