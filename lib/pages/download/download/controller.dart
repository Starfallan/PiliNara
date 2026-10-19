import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show BaseMultiSelectMixin;
import 'package:PiliPlus/pages/download/utils/cache_delete_confirm.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:PiliPlus/services/download/download_library_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:get/get.dart';

/// 离线缓存首页的多选态与删除。
///
/// 分组结果由 [DownloadLibraryService] 持有，这里不再自己算，避免出现第二份
/// 需要在删除后同步的分组数据。
class DownloadController extends GetxController
    with BaseMultiSelectMixin<DownloadSeasonInfo> {
  final downloadService = Get.find<DownloadService>();
  final libraryService = Get.find<DownloadLibraryService>();
  final folderService = Get.find<DownloadFolderService>();

  RxList<DownloadSeasonInfo> get seasons => libraryService.seasons;

  RxList<DownloadFolder> get folders => folderService.folders;

  @override
  List<DownloadSeasonInfo> get list => seasons;

  @override
  RxList<DownloadSeasonInfo> get state => seasons;

  @override
  void onRemove() {
    final checked = allChecked.toList();
    if (checked.isEmpty) {
      return;
    }
    confirmDeletePages(
      context: Get.context!,
      downloadService: downloadService,
      pages: [for (final season in checked) ...season.pages],
    ).then((deleted) {
      if (deleted) {
        rxCount.value = 0;
        enableMultiSelect.value = false;
      }
    });
  }
}
