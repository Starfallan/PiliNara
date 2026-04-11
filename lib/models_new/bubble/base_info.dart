import 'package:PiliPlus/models_new/bubble/tribee_info.dart';

class BaseInfo {
  TribeInfo? tribeInfo;
  bool? isJoined;

  BaseInfo({this.tribeInfo, this.isJoined});

  factory BaseInfo.fromJson(Map<String, dynamic> json) => BaseInfo(
    tribeInfo: json['tribee_info'] == null
        ? null
        : TribeInfo.fromJson(json['tribee_info'] as Map<String, dynamic>),
    isJoined: json['is_joined'] as bool?,
  );
}
