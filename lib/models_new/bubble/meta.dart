class Meta {
  String? author;
  String? timeText;
  String? replyCount;
  String? viewStat;

  Meta({
    this.author,
    this.timeText,
    this.replyCount,
    this.viewStat,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    author: json['author'] as String?,
    timeText: json['time_text'] as String?,
    replyCount: json['reply_count'] as String?,
    viewStat: json['view_stat'] as String?,
  );
}
