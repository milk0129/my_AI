// model.dart
class ChatMessage {
  final String role;    // 'user' or 'model'
  final String content; // 텍스트 내용
  final String? imagePath;

  ChatMessage({
    required this.role,
    required this.content,
    this.imagePath, // 생성자에 추가
  });
}