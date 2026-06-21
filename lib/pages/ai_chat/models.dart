class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  String content;
  bool isStreaming;
  String? templateName;
  final bool isDivider;
  int _updateCount = 0;

  ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.templateName,
    this.isDivider = false,
  });

  /// Incremented on each content update during streaming, used as animation trigger
  int get updateCount => _updateCount;

  void appendContent(String token) {
    content += token;
    _updateCount++;
  }
}
