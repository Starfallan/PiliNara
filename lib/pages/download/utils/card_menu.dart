import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/flutter/popup_menu.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/pages/download/utils/cache_export.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 一次放进菜单的文件夹快捷项上限，其余走选择器。
const _quickAddLimit = 5;

/// 菜单里的「添加到文件夹」：一个选择器入口，加几个常用文件夹的快捷项。
///
/// [items] 是这次要加进去的条目，粒度已由调用点按「勾选发生在哪一层」定好：
/// 整张合集卡 / 视频页卡是一个聚合条目，分组内部勾选的条目是各自独立的条目。
List<PopupMenuEntry<void>> buildAddToFolderMenuItems({
  required BuildContext context,
  required Iterable<DownloadFolderItem> items,
}) {
  final list = items.toList(growable: false);
  if (list.isEmpty) {
    return const <PopupMenuEntry<void>>[];
  }
  final folderService = Get.find<DownloadFolderService>();
  return [
    CustomPopupMenuItem<void>(
      height: 38,
      child: const Text('添加到文件夹…', style: TextStyle(fontSize: 13)),
      onTap: () async {
        final selected = await showDownloadFolderPickerDialog(
          context: context,
        );
        if (selected == null || selected.isEmpty) {
          return;
        }
        await folderService.addItemsToFolders(list, selected);
        SmartDialog.showToast('已添加到文件夹');
      },
    ),
    for (final folder in folderService.folders.take(_quickAddLimit))
      CustomPopupMenuItem<void>(
        height: 38,
        child: Text(
          '添加到「${folder.title}」',
          style: const TextStyle(fontSize: 13),
        ),
        onTap: () async {
          await folderService.addItemsToFolders(list, [folder.id]);
          SmartDialog.showToast('已添加到「${folder.title}」');
        },
      ),
  ];
}

/// 同上，调用点手里只有条目时用（条目菜单、条目列表的多选）。
List<PopupMenuEntry<void>> buildAddEntriesToFolderMenuItems({
  required BuildContext context,
  required Iterable<BiliDownloadEntryInfo> entries,
}) => buildAddToFolderMenuItems(
  context: context,
  items: DownloadFolderItem.ofEntries(entries),
);

/// 分组卡片（合集卡、视频页卡）菜单的附加项：导出整张卡片 + 把整张卡片加进文件夹。
///
/// 两者都作用于卡片代表的整组缓存；[item] 是这张卡片在文件夹里的聚合形态，所以
/// 把整个合集放进来之后，新缓存的集数会自己跟上来。
List<PopupMenuEntry<void>> buildGroupCardMenuItems({
  required BuildContext context,
  required Iterable<BiliDownloadEntryInfo> entries,
  required DownloadFolderItem item,
}) {
  final list = entries.toList(growable: false);
  if (list.isEmpty) {
    return const <PopupMenuEntry<void>>[];
  }
  return [
    if (Platform.isAndroid)
      CustomPopupMenuItem<void>(
        height: 38,
        child: const Text('导出', style: TextStyle(fontSize: 13)),
        onTap: () => exportDownloadEntries(list),
      ),
    ...buildAddToFolderMenuItems(context: context, items: [item]),
  ];
}
