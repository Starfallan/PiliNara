import 'package:PiliPlus/models_new/bubble/category_list.dart';

class Category {
  List<CategoryList>? categoryList;

  Category({this.categoryList});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    categoryList: (json['category_list'] as List<dynamic>?)
        ?.map((e) => CategoryList.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
