class Meta {
  String? author;
  String? timeText;
  String? replyCount;
  String? viewStat;
  List<String>? tags;
  ReplyIcon? replyIcon;

  Meta({
    this.author,
    this.timeText,
    this.replyCount,
    this.viewStat,
    this.tags,
    this.replyIcon,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    author: json['author'] as String?,
    timeText: json['time_text'] as String?,
    replyCount: json['reply_count'] as String?,
    viewStat: json['view_stat'] as String?,
    tags: (json['tags'] as List?)?.cast<String>(),
    replyIcon: json['reply_icon'] == null
        ? null
        : ReplyIcon.fromJson(json['reply_icon'] as Map<String, dynamic>),
  );
}

/// 评论气泡图标与配色，后端已按评论数分档
class ReplyIcon {
  String? color;
  String? text;

  ReplyIcon({this.color, this.text});

  factory ReplyIcon.fromJson(Map<String, dynamic> json) => ReplyIcon(
    color: json['color'] as String?,
    text: json['text'] as String?,
  );
}
