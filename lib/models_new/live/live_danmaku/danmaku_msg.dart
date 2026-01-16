import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_emote.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';

class DanmakuMsg {
  final String name;
  final Object uid;
  final String text;
  final Map<String, BaseEmote>? emots;
  final BaseEmote? uemote;
  final LiveDanmaku extra;
  final Owner? reply;

  const DanmakuMsg({
    required this.name,
    required this.uid,
    required this.text,
    this.emots,
    this.uemote,
    required this.extra,
    this.reply,
  });

  factory DanmakuMsg.fromPrefetch(Map<String, dynamic> obj) {
    final user = obj['user'];
    final uid = user['uid'];
    BaseEmote? uemote;
    if ((obj['emoticon']?['emoticon_unique'] as String?)?.isNotEmpty == true) {
      uemote = BaseEmote.fromJson(obj['emoticon']);
    }
    final checkInfo = obj['check_info'];
    Owner? reply;
    if (obj['reply'] case final Map map) {
      final replyMid = map['reply_mid'];
      if (replyMid != null && replyMid != 0) {
        reply = Owner(
          mid: replyMid,
          name: map['reply_uname'],
        );
      }
    }
    return DanmakuMsg(
      name: user['base']['name'],
      uid: uid,
      text: obj['text'],
      emots: (obj['emots'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, BaseEmote.fromJson(v)),
      ),
      uemote: uemote,
      extra: LiveDanmaku(
        id: obj['id_str'],
        mid: uid,
        dmType: obj['dm_type'],
        ts: checkInfo['ts'],
        ct: checkInfo['ct'],
      ),
      reply: reply,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'uid': uid,
    'text': text,
    'emots': emots,
    'uemote': uemote?.toJson(),
    'extra': extra.toJson(),
    'reply': reply?.toJson(),
  };
}
