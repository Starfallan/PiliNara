import 'package:PiliPlus/models_new/reply_interaction/interact_status.dart';

class ReplyInteractData {
  InteractStatus upReplySelection;
  InteractStatus upReply;
  // InteractStatus upDm;

  ReplyInteractData({
    required this.upReplySelection,
    required this.upReply,
    // required this.upDm,
  });

  factory ReplyInteractData.fromJson(Map<String, dynamic> json) =>
      ReplyInteractData(
        upReplySelection: InteractStatus.fromJson(json["up_reply_selection"]),
        upReply: InteractStatus.fromJson(json["up_reply"]),
        // upDm: InteractStatus.fromJson(json["up_dm"]),
      );
}
