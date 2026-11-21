import 'dart:collection';
import 'dart:typed_data';

import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/grpc_req.dart';
import 'package:PiliPlus/grpc/url.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/pages/video/reply_reply/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protobuf/protobuf.dart';

ReplyInfo _reply(int id, {int parent = 1, int? dialog}) => ReplyInfo(
  id: Int64(id),
  oid: Int64(10),
  type: Int64.ONE,
  root: Int64.ONE,
  parent: Int64(parent),
  dialog: Int64(dialog ?? id),
  ctime: Int64(1700000000 + id),
  member: Member(name: '用户 $id'),
  content: Content(message: '回复 $id'),
);

DetailListReply _details(List<ReplyInfo> replies, {bool hasFold = false}) =>
    DetailListReply(
      root: _reply(1)
        ..count = Int64(replies.length)
        ..replies.addAll(replies),
      cursor: CursorReply(isEnd: true),
      mixedCards: hasFold
          ? [
              MixedCard(
                type: .FOLD,
                fold: FoldCard(bottomText: '展开被折叠的评论'),
              ),
            ]
          : null,
    );

List<String> _stubReplies(List<GeneratedMessage> replies) {
  final pending = Queue.of(replies);
  final requests = <String>[];
  final interceptor = InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.uri.path == '/x/frontend/finger/spi') {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'code': -1},
          ),
        );
        return;
      }
      requests.add(options.uri.path);
      final response = pending.isEmpty ? null : pending.removeFirst();
      handler.resolve(
        Response<Uint8List>(
          requestOptions: options,
          statusCode: 200,
          headers: Headers.fromMap({
            'grpc-status': [response == null ? '1' : '0'],
          }),
          data: response == null
              ? Uint8List(0)
              : GrpcReq.compressProtobuf(response.writeToBuffer()),
        ),
      );
    },
  );
  Request.dio.interceptors.add(interceptor);
  addTearDown(() => Request.dio.interceptors.remove(interceptor));
  return requests;
}

Future<void> _openPanel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const Scaffold(
        body: VideoReplyReplyPanel(
          enableSlide: false,
          oid: 10,
          rpid: 1,
          isVideoDetail: true,
          replyType: 1,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _replyRow(int id) => find.byWidgetPredicate(
  (widget) => widget is ReplyItemGrpc && widget.replyItem.id == Int64(id),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GStorage.setting = await Hive.openBox('setting', bytes: Uint8List(0));
    GStorage.localCache = await Hive.openBox('localCache', bytes: Uint8List(0));
    Request();
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    Request.dio.close(force: true);
    await Hive.close();
  });

  testWidgets('确认加载折叠评论后可以双向切换并保留树的折叠状态', (tester) async {
    final requests = _stubReplies([
      _details([_reply(2)], hasFold: true),
      FoldListResp(replies: [_reply(3, parent: 2, dialog: 2)]),
    ]);
    await _openPanel(tester);

    final threadToggle = find.byTooltip('线程化展示');
    final flatToggle = find.byTooltip('平铺展示');
    await _tap(tester, threadToggle);
    expect(find.text('是否加载全部评论以显示线程化评论？'), findsOneWidget);
    expect(requests, [GrpcUrl.detailList]);
    await _tap(tester, find.text('确认'));

    expect(find.byIcon(Icons.view_comfortable_outlined), findsOneWidget);
    expect(flatToggle, findsOneWidget);
    expect(_replyRow(3), findsOneWidget);
    await _tap(tester, find.text('折叠'));
    expect(_replyRow(3), findsNothing);

    await _tap(tester, flatToggle);
    expect(_replyRow(3), findsOneWidget);
    expect(tester.widget<ReplyItemGrpc>(_replyRow(3)).depth, -1);
    await _tap(tester, threadToggle);
    expect(_replyRow(3), findsNothing);
    await _tap(tester, find.text('展开 1 条评论'));
    expect(tester.widget<ReplyItemGrpc>(_replyRow(3)).depth, 1);
    expect(requests, [GrpcUrl.detailList, GrpcUrl.foldList]);
  });

  testWidgets('平铺排序后用新列表建树，平铺删除后不会恢复已删除回复', (tester) async {
    final requests = _stubReplies([
      _details([_reply(2)]),
      _details([_reply(3), _reply(4)]),
    ]);
    await _openPanel(tester);

    final threadToggle = find.byTooltip('线程化展示');
    final flatToggle = find.byTooltip('平铺展示');
    await _tap(tester, threadToggle);
    await _tap(tester, flatToggle);
    await _tap(tester, find.byIcon(Icons.sort));
    expect(_replyRow(2), findsNothing);
    expect(_replyRow(3), findsOneWidget);

    await _tap(tester, threadToggle);
    expect(tester.widget<ReplyItemGrpc>(_replyRow(4)).depth, 0);
    await _tap(tester, flatToggle);
    final row = tester.widget<ReplyItemGrpc>(_replyRow(4));
    row.onDelete!(row.replyItem, null);
    await tester.pumpAndSettle();
    await _tap(tester, threadToggle);
    expect(_replyRow(4), findsNothing);
    expect(tester.widget<ReplyItemGrpc>(_replyRow(3)).depth, 0);
    expect(requests, [GrpcUrl.detailList, GrpcUrl.detailList]);
  });
}
