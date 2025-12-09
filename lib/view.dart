// view.dart
import 'package:flutter/material.dart';
import 'controller.dart';
import 'model.dart';

// [1] 첫 화면: 모드 선택 (새로 추가된 부분)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 또는 아이콘
            const Icon(Icons.smart_toy_rounded, size: 80, color: Color(0xFF81C784)),
            const SizedBox(height: 20),
            const Text(
              'My Gemini',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 60),

            // 텍스트 모드 버튼
            _buildModeButton(
              context,
              icon: Icons.keyboard,
              label: '텍스트 대화',
              isVoiceMode: false,
            ),
            const SizedBox(height: 20),

            // 음성 모드 버튼
            _buildModeButton(
              context,
              icon: Icons.mic,
              label: '음성 대화',
              isVoiceMode: true,
            ),
          ],
        ),
      ),
    );
  }

  // 버튼 디자인 위젯
  Widget _buildModeButton(BuildContext context, {required IconData icon, required String label, required bool isVoiceMode}) {
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(isVoiceMode: isVoiceMode),
            ),
          );
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81C784), // 연두색
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}

// [2] 채팅 화면 (기존 코드 수정: 모드 전달받음)
class ChatScreen extends StatefulWidget {
  final bool isVoiceMode; // 모드 확인 변수

  const ChatScreen({super.key, required this.isVoiceMode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final GeminiController _controller = GeminiController();
  final ScrollController _scrollController = ScrollController();
  late FocusNode _focusNode; // 키보드 포커스 제어용

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller.addListener(_updateView);

    // 텍스트 모드라면 자동으로 키보드 띄우기
    if (!widget.isVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_focusNode);
      });
    }

    // 음성 모드라면 (원한다면) 자동으로 듣기 시작하게 할 수도 있음
    // if (widget.isVoiceMode) { _controller.startListening(); }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _controller.removeListener(_updateView);
    super.dispose();
  }

  void _updateView() {
    if (mounted) {
      setState(() {});
      if (_controller.messages.isNotEmpty && !_controller.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
      if (_controller.isListening) {
        _textController.text = _controller.currentRecognizedWords;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        // 타이틀을 모드에 따라 다르게 표시
        title: Text(
          widget.isVoiceMode ? '음성 대화 모드' : '텍스트 대화 모드',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _controller.messages.length,
              itemBuilder: (context, index) {
                final message = _controller.messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_controller.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF81C784) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.circular(0),
            bottomRight: isUser ? Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode, // 포커스 제어
              decoration: InputDecoration(
                hintText: _controller.isListening ? '듣고 있어요...' : (widget.isVoiceMode ? '마이크를 눌러 말하세요' : '메시지 입력'),
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFF81C784)),
                ),
              ),
              onSubmitted: (_) {
                _controller.sendMessage(_textController.text);
                _textController.clear();
              },
            ),
          ),
          const SizedBox(width: 8),

          // [UI 분기] 음성 모드면 마이크가 메인, 텍스트 모드면 전송 버튼이 메인
          if (widget.isVoiceMode)
            GestureDetector(
              onLongPressStart: (_) => _controller.startListening(),
              onLongPressEnd: (_) {
                _controller.stopListening();
                _textController.clear();
              },
              child: CircleAvatar(
                backgroundColor: _controller.isListening ? Colors.redAccent : const Color(0xFF4CAF50),
                radius: 24,
                child: Icon(
                  _controller.isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
              ),
            )
          else
            CircleAvatar(
              backgroundColor: const Color(0xFF81C784),
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () {
                  if (_textController.text.isNotEmpty) {
                    _controller.sendMessage(_textController.text);
                    _textController.clear();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}