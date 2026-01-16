class InteractStatus {
  bool canModify;
  int status;

  InteractStatus({
    required this.canModify,
    required this.status,
  });

  factory InteractStatus.fromJson(Map<String, dynamic> json) => InteractStatus(
    canModify: json["can_modify"],
    status: json["status"],
  );
}
