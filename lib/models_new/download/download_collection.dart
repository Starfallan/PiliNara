import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show MultiSelectData;

class DownloadFolder with MultiSelectData {
  final String id;
  String title;
  final int createdAt;
  final String? sourceKey;
  final List<int> videoCids;

  DownloadFolder({
    required this.id,
    required this.title,
    required this.createdAt,
    this.sourceKey,
    required this.videoCids,
  });

  factory DownloadFolder.fromJson(Map<String, dynamic> json) => DownloadFolder(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    createdAt: json['createdAt'] as int? ?? 0,
    sourceKey: json['sourceKey'] as String?,
    videoCids: (json['videoCids'] as List? ?? const <dynamic>[])
        .whereType<int>()
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt,
    'sourceKey': sourceKey,
    'videoCids': videoCids,
  };
}

enum DownloadPlaylistScope {
  all,
  folder,
}

class DownloadVideoPlayContext {
  final DownloadPlaylistScope scope;
  final String? folderId;

  const DownloadVideoPlayContext._({
    required this.scope,
    this.folderId,
  });

  const DownloadVideoPlayContext.all()
    : this._(scope: DownloadPlaylistScope.all);

  const DownloadVideoPlayContext.folder(String folderId)
    : this._(
        scope: DownloadPlaylistScope.folder,
        folderId: folderId,
      );

  Map<String, dynamic> toArguments() => {
    'downloadPlaylistScope': scope.name,
    if (folderId != null) 'downloadFolderId': folderId,
  };

  static DownloadVideoPlayContext? fromArguments(Map args) {
    final scopeName = args['downloadPlaylistScope'];
    if (scopeName is! String) {
      return null;
    }
    try {
      final scope = DownloadPlaylistScope.values.byName(scopeName);
      return switch (scope) {
        DownloadPlaylistScope.all => const DownloadVideoPlayContext.all(),
        DownloadPlaylistScope.folder =>
          args['downloadFolderId'] is String
              ? DownloadVideoPlayContext.folder(
                  args['downloadFolderId'] as String,
                )
              : null,
      };
    } catch (_) {
      return null;
    }
  }
}

typedef DownloadEntryMap = Map<int, BiliDownloadEntryInfo>;
