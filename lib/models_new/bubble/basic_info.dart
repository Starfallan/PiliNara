class BasicInfo {
  String? icon;
  String? title;
  String? jumpUri;

  BasicInfo({this.icon, this.title, this.jumpUri});

  factory BasicInfo.fromJson(Map<String, dynamic> json) => BasicInfo(
    icon: json['icon'] as String?,
    title: json['title'] as String?,
    jumpUri: json['jump_uri'] as String?,
  );
}
