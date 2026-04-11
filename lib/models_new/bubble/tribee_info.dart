class TribeInfo {
  String? id;
  String? title;
  String? subTitle;
  String? faceUrl;
  String? jumpUri;
  String? summary;

  TribeInfo({
    this.id,
    this.title,
    this.subTitle,
    this.faceUrl,
    this.jumpUri,
    this.summary,
  });

  factory TribeInfo.fromJson(Map<String, dynamic> json) => TribeInfo(
    id: json['id'] as String?,
    title: json['title'] as String?,
    subTitle: json['sub_title'] as String?,
    faceUrl: json['face_url'] as String?,
    jumpUri: json['jump_uri'] as String?,
    summary: json['summary'] as String?,
  );
}
