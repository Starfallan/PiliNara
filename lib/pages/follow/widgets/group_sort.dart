import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/models/member/tags.dart';
import 'package:PiliPlus/pages/follow/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class FollowGroupSortPage extends StatefulWidget {
  const FollowGroupSortPage({
    super.key,
    required this.followController,
  });

  final FollowController followController;

  @override
  State<FollowGroupSortPage> createState() => _FollowGroupSortPageState();
}

class _FollowGroupSortPageState extends State<FollowGroupSortPage> {
  FollowController get _followController => widget.followController;

  bool _isCustomTag(int? tagid) =>
      tagid != null && tagid != 0 && tagid != -10 && tagid != -2;

  late List<MemberTagItemModel> sortList = _followController.tabs
      .where((e) => _isCustomTag(e.tagid))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('分组排序'),
        actions: [
          TextButton(
            onPressed: _onSave,
            child: const Text('完成'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: sortList.isEmpty
          ? const Center(child: Text('暂无自定义分组'))
          : ReorderableListView.builder(
              onReorder: _onReorder,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: MediaQuery.viewPaddingOf(context).copyWith(top: 0),
              itemCount: sortList.length,
              itemBuilder: (context, index) {
                final item = sortList[index];
                return ListTile(
                  key: Key('${item.tagid}'),
                  leading: const Icon(Icons.group_outlined),
                  title: Text(
                    '${item.name}${item.count != null ? ' (${item.count})' : ''}',
                  ),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                );
              },
            ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = sortList.removeAt(oldIndex);
    sortList.insert(newIndex, item);
    setState(() {});
  }

  Future<void> _onSave() async {
    final tagids = sortList.map((e) => e.tagid).join(',');
    final res = await MemberHttp.sortFollowTag(tagids);
    if (res.isSuccess) {
      SmartDialog.showToast('排序完成');
      _followController.queryFollowUpTags();
      Get.back();
    } else {
      res.toast();
    }
  }
}
