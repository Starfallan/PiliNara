import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/pagination.pb.dart';
import 'package:PiliPlus/grpc/grpc_req.dart';
import 'package:PiliPlus/grpc/url.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/user_whitelist.dart';
import 'package:fixnum/fixnum.dart';

abstract final class ReplyGrpc {
  static bool antiGoodsReply = Pref.antiGoodsReply;
  static var blockAtOnlyReply = Pref.blockAtOnlyReply;
  static var blockReplyAtCount = Pref.blockReplyAtCount;
  static List<RegExp> replyRegExp = Pref.compileBanWord(Pref.banWordForReply);
  static bool enableFilter = replyRegExp.isNotEmpty;
  static Map<int, String> replyBlockedMids = Pref.replyBlockedMids;
  static int replyMinLevel = Pref.replyMinLevel;
  static bool keepUpOwnerReply = Pref.keepUpOwnerReply;
  static bool keepUpTopReply = Pref.keepUpTopReply;
  static bool keepUpLikeReply = Pref.keepUpLikeReply;
  static bool keepUpReplyReply = Pref.keepUpReplyReply;

  // static Future replyInfo({required int rpid}) {
  //   return _request(
  //     GrpcUrl.replyInfo,
  //     ReplyInfoReq(rpid: Int64(rpid)),
  //     ReplyInfoReply.fromBuffer,
  //     onSuccess: (response) => response.reply,
  //   );
  // }

  static bool _hasGoods(Url url) =>
      url.hasExtra() &&
      (url.extra.goodsCmControl == Int64.ONE ||
          url.extra.hasGoodsItemId() ||
          url.extra.hasGoodsPrefetchedCache());

  // ref BiliRoamingX
  @pragma('vm:prefer-inline')
  static bool _needRemoveGoodGrpc(ReplyInfo reply) {
    return (reply.content.urls.isNotEmpty &&
            reply.content.urls.values.any(_hasGoods)) ||
        reply.content.message.contains(Constants.goodsUrlPrefix);
  }

  static bool _blockAtOnlyReply(ReplyInfo reply) {
    if (!blockAtOnlyReply) return false;

    final content = reply.content;
    final atNameToMid = content.atNameToMid;
    if (atNameToMid.isEmpty) return false;
    if (content.emotes.isNotEmpty || content.pictures.isNotEmpty) return false;

    final message = content.message;
    final length = message.length;

    int i = 0;

    if (reply.root != reply.parent) {
      i = message.indexOf(':') + 1;
      if (i <= 0) return false;
    }

    var hasAt = false;
    while (i < length) {
      var c = message.codeUnitAt(i);

      if (c case 0x20 /* ` ` */ || 0x0A /* `\n` */ ) {
        i++;
        continue;
      }

      if (c != 0x40 /* `@` */ ) return false;

      i++;
      final nameStart = i;

      while (i < length) {
        c = message.codeUnitAt(i);
        if (c case 0x20 || 0x40 || 0x0A) {
          break;
        }
        i++;
      }

      if (i == nameStart) return false;
      final name = message.substring(nameStart, i);
      if (!atNameToMid.containsKey(name)) return false;

      hasAt = true;
    }

    return hasAt;
  }

  static bool _blockReplyAtCount(ReplyInfo reply) {
    return blockReplyAtCount != null &&
        reply.content.atNameToMid.length >= blockReplyAtCount!;
  }

  static bool needRemoveGrpc(
    ReplyInfo reply, {
    Int64? upMid,
  }) {
    final mid = reply.mid.toInt();
    if (replyBlockedMids.isNotEmpty && replyBlockedMids.containsKey(mid)) {
      return true;
    }
    // fork 白名单优先于一切屏蔽规则（含全局黑名单）
    if (UserWhitelist.contains(mid)) return false;
    if (GlobalData().blackMids.contains(mid)) return true;
    if (_blockReplyAtCount(reply)) return true;
    if (_blockAtOnlyReply(reply)) return true;
    if (antiGoodsReply && _needRemoveGoodGrpc(reply)) return true;
    final replyControl = reply.replyControl;
    if (keepUpOwnerReply && upMid != null && reply.mid == upMid) return false;
    if (keepUpTopReply && replyControl.isUpTop) return false;
    if (keepUpLikeReply && replyControl.upLike) return false;
    if (keepUpReplyReply && replyControl.upReply) return false;
    return (replyMinLevel > 0 && reply.member.level.toInt() < replyMinLevel) ||
        (enableFilter && replyRegExp.hasMatch(reply.content.message));
  }

  static Future<LoadingState<MainListReply>> mainList({
    required int type,
    required int oid,
    Int64? rpid,
    required Mode mode,
    required String? offset,
    // Int64? cursorNext,
  }) async {
    final res = await GrpcReq.request(
      GrpcUrl.mainList,
      MainListReq(
        oid: Int64(oid),
        type: Int64(type),
        rpid: rpid,
        // cursor: CursorReq(
        //   mode: mode,
        //   next: cursorNext,
        // ),
        mode: mode,
        pagination: offset == null ? null : FeedPagination(offset: offset),
      ),
      MainListReply.fromBuffer,
    );
    if (res case Success(:final response)) {
      final upMid = response.subjectControl.upMid;
      // keyword filter
      if (response.hasUpTop()) {
        final topReply = response.upTop;
        if (needRemoveGrpc(topReply, upMid: upMid)) {
          response.clearUpTop();
        } else {
          topReply.replies.removeWhere((item) => needRemoveGrpc(item, upMid: upMid));
        }
      }

      if (response.replies.isNotEmpty) {
        response.replies.removeWhere((item) {
          final hasMatch = needRemoveGrpc(
            item,
            upMid: upMid,
          );
          if (!hasMatch && item.replies.isNotEmpty) {
            item.replies.removeWhere((item) {
              return needRemoveGrpc(item, upMid: upMid);
            });
          }
          return hasMatch;
        });
      }

      if (response.replies.isEmpty && !response.hasUpTop()) {
        final offset = response.paginationReply.nextOffset;
        if (offset.isNotEmpty && !response.cursor.isEnd) {
          return mainList(
            type: type,
            oid: oid,
            rpid: rpid,
            mode: mode,
            offset: offset,
          );
        }
      }
    }
    return res;
  }

  static Future<LoadingState<DetailListReply>> detailList({
    required int type,
    required int oid,
    required int root,
    required int rpid,
    required Mode mode,
    required String? offset,
    Map<Int64, ReplyInfo>? removed,
  }) async {
    final res = await GrpcReq.request(
      GrpcUrl.detailList,
      DetailListReq(
        oid: Int64(oid),
        type: Int64(type),
        root: Int64(root),
        rpid: Int64(rpid),
        scene: DetailListScene.REPLY,
        mode: mode,
        pagination: offset == null ? null : FeedPagination(offset: offset),
      ),
      DetailListReply.fromBuffer,
    );
    if (res case Success(:final response)) {
      final upMid = response.subjectControl.upMid;
      response.root.replies.removeWhere((item) {
        final flag = needRemoveGrpc(item, upMid: upMid);
        if (flag) removed?[item.id] = item;
        return flag;
      });
    }
    return res;
  }

  static Future<LoadingState<FoldListResp>> foldList({
    required int type,
    required int oid,
    required FeedPagination pagination,
  }) async {
    final res = await GrpcReq.request(
      GrpcUrl.foldList,
      FoldListReq(
        oid: Int64(oid),
        type: Int64(type),
        pagination: pagination,
      ),
      FoldListResp.fromBuffer,
    );
    return res..dataOrNull?.replies.removeWhere(needRemoveGrpc);
  }

  static Future<LoadingState<DialogListReply>> dialogList({
    required int type,
    required int oid,
    required int root,
    required int dialog,
    required String? offset,
  }) async {
    final res = await GrpcReq.request(
      GrpcUrl.dialogList,
      DialogListReq(
        oid: Int64(oid),
        type: Int64(type),
        root: Int64(root),
        dialog: Int64(dialog),
        pagination: offset == null ? null : FeedPagination(offset: offset),
      ),
      DialogListReply.fromBuffer,
    );
    if (res case Success(:final response)) {
      final upMid = response.subjectControl.upMid;
      response.replies.removeWhere((item) {
        return needRemoveGrpc(item, upMid: upMid);
      });
    }
    return res;
  }

  static Future<LoadingState<SearchItemReply>> searchItem({
    required int page,
    required SearchItemType itemType,
    required int oid,
    required int type,
    String? keyword,
  }) {
    return GrpcReq.request(
      GrpcUrl.searchItem,
      SearchItemReq(
        cursor: SearchItemCursorReq(
          next: Int64(page),
          itemType: itemType,
        ),
        oid: Int64(oid),
        type: Int64(type),
        keyword: keyword,
      ),
      SearchItemReply.fromBuffer,
    );
  }

  static Future<LoadingState<TranslateReplyResp>> translateReply({
    required Int64 type,
    required Int64 oid,
    required Int64 rpid,
  }) {
    return GrpcReq.request(
      GrpcUrl.translateReply,
      TranslateReplyReq(
        type: type,
        oid: oid,
        rpids: [rpid],
      ),
      TranslateReplyResp.fromBuffer,
    );
  }
}
