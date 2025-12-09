// model.dart
class ChatMessage {
  final String role; // 'user' (나) 또는 'model' (AI)
  final String content;

  ChatMessage({required this.role, required this.content});
}