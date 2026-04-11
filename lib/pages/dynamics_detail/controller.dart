import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show Mode;
import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/reply.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/common/dyn/common_dyn_controller.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart' show AnimationController;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class DynamicDetailController extends CommonDynController
    with GetSingleTickerProviderStateMixin {
  static const String _kWebLinkPlaceholder = '网页链接';

  @override
  late int oid;
  @override
  late int replyType;
  late DynamicItemModel dynItem;
  final RxInt detailVersion = 0.obs;

  int? targetRpid;
  final RxnInt targetIndex = RxnInt();

  AnimationController? _animController;
  AnimationController get animController =>
      _animController ??= AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );

  final ListController listController = ListController();

  @override
  dynamic get sourceId => replyType == 1 ? IdUtils.av2bv(oid) : oid;

  @override
  void onInit() {
    super.onInit();
    dynItem = Get.arguments['item'];
    targetRpid = Get.arguments['targetRpid'];
    if (targetRpid != null) {
      mode.value = Mode.MAIN_LIST_HOT;
    }
    final commentType = dynItem.basic?.commentType;
    final commentIdStr = dynItem.basic?.commentIdStr;
    if (commentType != null &&
        commentType != 0 &&
        commentIdStr != null &&
        commentIdStr.isNotEmpty) {
      _init(commentIdStr, commentType);
      _tryFetchFullDynamicDetail();
    } else {
      DynamicsHttp.dynamicDetail(id: dynItem.idStr).then((res) {
        if (res case Success(:final response)) {
          _replaceDynItem(response);
          _init(response.basic!.commentIdStr!, response.basic!.commentType!);
        } else {
          res.toast();
        }
      });
    }
  }

  void _init(String commentIdStr, int commentType) {
    oid = int.parse(commentIdStr);
    replyType = commentType;
    queryData();
  }

  void _replaceDynItem(DynamicItemModel item) {
    dynItem = item;
    detailVersion.value++;
  }

  bool _shouldFetchFullDetail() {
    final moduleDynamic = dynItem.modules.moduleDynamic;
    final nodes =
        moduleDynamic?.desc?.richTextNodes ??
        moduleDynamic?.major?.opus?.summary?.richTextNodes;
    if (nodes == null || nodes.isEmpty) {
      return false;
    }
    for (final node in nodes) {
      if (node.type == 'RICH_TEXT_NODE_TYPE_WEB' &&
          (node.jumpUrl == null || node.jumpUrl!.isEmpty)) {
        return true;
      }
      if (node.text == _kWebLinkPlaceholder ||
          node.origText == _kWebLinkPlaceholder) {
        return true;
      }
    }
    return false;
  }

  void _tryFetchFullDynamicDetail() {
    if (!_shouldFetchFullDetail()) {
      return;
    }
    DynamicsHttp.dynamicDetail(id: dynItem.idStr).then((res) {
      if (isClosed) {
        return;
      }
      if (res case Success(:final response)) {
        _replaceDynItem(response);
        final nextCommentType = response.basic?.commentType;
        final nextCommentIdStr = response.basic?.commentIdStr;
        if (nextCommentType != null &&
            nextCommentType != 0 &&
            nextCommentIdStr != null &&
            nextCommentIdStr.isNotEmpty) {
          final nextOid = int.tryParse(nextCommentIdStr);
          if (nextOid != null &&
              (nextOid != oid || nextCommentType != replyType)) {
            _init(nextCommentIdStr, nextCommentType);
          }
        }
      }
    });
  }

  @override
  bool customHandleResponse(bool isRefresh, Success response) {
    final result = super.customHandleResponse(isRefresh, response);
    if (isRefresh && targetRpid != null) {
      _setTargetIndex();
      targetRpid = null;
    }
    return result;
  }

  void _setTargetIndex() {
    final data = loadingState.value.data;
    if (data == null || data.isEmpty) return;
    final targetId = Int64(targetRpid!);
    final index = data.indexWhere((item) => item.id == targetId);
    if (index != -1) {
      targetIndex.value = index;
    }
  }

  Future<LoadingState> onSetPubSetting(bool isPrivate, Object dynId) async {
    final res = await DynamicsHttp.dynPrivatePubSetting(
      dynId: dynId,
      action: isPrivate ? 'public_pub' : 'private_pub',
    );
    if (res.isSuccess) {
      dynItem.modules.moduleAuthor?.badgeText = isPrivate ? null : '仅自己可见';
      detailVersion.value++;
      SmartDialog.showToast('设置成功');
    } else {
      res.toast();
    }
    return res;
  }

  Future<void> onSetReplySubject(int action) async {
    final res = await ReplyHttp.replySubjectModify(
      oid: oid,
      type: replyType,
      action: action,
    );
    if (res.isSuccess) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!isClosed) {
          onReload();
        }
      });
    }
  }

  @override
  void onClose() {
    _animController?.dispose();
    listController.dispose();
    super.onClose();
  }
}
