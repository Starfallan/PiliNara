import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class UserWhitelist {
  static bool contains(int? mid) {
    return mid != null && GlobalData().whitelistMids.containsKey(mid);
  }

  static void save(Map<int, String> whitelistMids) {
    Pref.whitelistMids = whitelistMids;
    GlobalData().whitelistMids = whitelistMids;
    _removeLocalConflicts(whitelistMids.keys);
  }

  static void add({
    required int mid,
    required String name,
  }) {
    final whitelistMids = Map<int, String>.from(Pref.whitelistMids);
    final displayName = name.trim().isEmpty ? 'UID:$mid' : name.trim();
    whitelistMids[mid] = displayName;
    save(whitelistMids);
  }

  static void _removeLocalConflicts(Iterable<int> mids) {
    final whitelistSet = mids.toSet();
    if (whitelistSet.isEmpty) {
      return;
    }

    final recommendBlockedMids = Map<int, String>.from(
      Pref.recommendBlockedMids,
    )..removeWhere((key, _) => whitelistSet.contains(key));
    Pref.recommendBlockedMids = recommendBlockedMids;
    GlobalData().recommendBlockedMids = recommendBlockedMids;
    RecommendFilter.recommendBlockedMids = recommendBlockedMids;

    final dynamicsBlockedMids = Set<int>.from(
      Pref.dynamicsBlockedMids,
    )..removeAll(whitelistSet);
    Pref.dynamicsBlockedMids = dynamicsBlockedMids;
    GlobalData().dynamicsBlockedMids = dynamicsBlockedMids;
    DynamicsDataModel.dynamicsBlockedMids = dynamicsBlockedMids;

    final replyBlockedMids = Map<int, String>.from(
      Pref.replyBlockedMids,
    )..removeWhere((key, _) => whitelistSet.contains(key));
    Pref.replyBlockedMids = replyBlockedMids;
    ReplyGrpc.replyBlockedMids = replyBlockedMids;
  }
}
