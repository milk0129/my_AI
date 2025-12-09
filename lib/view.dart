import 'dart:io'; // 파일 이미지 표시용
import 'package:flutter/material.dart';
import 'controller.dart';
import 'model.dart';

// [1] 첫 화면: 모드 선택
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
            const Icon(Icons.smart_toy_rounded, size: 80, color: Color(0xFF81C784)),
            const SizedBox(height: 20),
            const Text(
              'My Gemini',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 60),
            _buildModeButton(context, icon: Icons.keyboard, label: '텍스트 대화', isVoiceMode: false),
            const SizedBox(height: 20),
            _buildModeButton(context, icon: Icons.mic, label: '음성 대화', isVoiceMode: true),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(BuildContext context, {required IconData icon, required String label, required bool isVoiceMode}) {
    return SizedBox(
      width: 250, height: 60,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(isVoiceMode: isVoiceMode))),
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF81C784),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
        ),
      ),
    );
  }
}

// [2] 채팅 화면
class ChatScreen extends StatefulWidget {
  final bool isVoiceMode;
  const ChatScreen({super.key, required this.isVoiceMode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final GeminiController _controller = GeminiController();
  final ScrollController _scrollController = ScrollController();
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller.addListener(_updateView);
    // 텍스트 모드일 때만 키보드 자동 올림
    if (!widget.isVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_focusNode));
    }
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
      // 메시지가 추가되면 스크롤을 맨 아래로 이동
      if (_controller.messages.isNotEmpty && !_controller.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut
            );
          }
        });
      }
      // 음성 인식 중이면 텍스트 필드에 실시간 반영
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
        title: Text(
            widget.isVoiceMode ? '음성 대화 (사진)' : '텍스트 대화 (사진)',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))
        ),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)
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
                return _buildMessageBubble(_controller.messages[index]);
              },
            ),
          ),
          if (_controller.isLoading)
            const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF81C784))),

          _buildInputArea(),
        ],
      ),
    );
  }

  // 말풍선 UI
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF81C784) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진이 있으면 표시
            if (message.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(message.imagePath!), fit: BoxFit.cover),
                ),
              ),
            // 텍스트 내용
            if (message.content.isNotEmpty)
              Text(
                  message.content,
                  style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 16)
              ),
          ],
        ),
      ),
    );
  }

  // 입력창 UI (여기가 수정됨)
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // 사진 미리보기 영역
          if (_controller.selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_controller.selectedImage!.path),
                          width: 80, height: 80, fit: BoxFit.cover,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _controller.cancelImage(),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Row(
            children: [
              // 갤러리 버튼
              IconButton(
                icon: const Icon(Icons.image, color: Colors.grey),
                onPressed: () => _controller.pickImage(),
              ),

              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    // 힌트 텍스트 변경: 터치 방식에 맞게 수정
                    hintText: widget.isVoiceMode
                        ? (_controller.isListening ? '듣고 있어요...' : '마이크 터치하여 말하기')
                        : '메시지 입력...',
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) {
                    _controller.sendMessage(_textController.text);
                    _textController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),

              // [수정된 부분] 전송 or 마이크 토글 버튼
              if (widget.isVoiceMode)
              // ★ 음성 모드: 터치해서 켜고 끄기 (Toggle)
                InkWell(
                  onTap: () {
                    if (_controller.isListening) {
                      // 듣고 있었다면 -> 멈추고 전송
                      _controller.stopListening();
                      _textController.clear();
                    } else {
                      // 안 듣고 있었다면 -> 듣기 시작
                      _controller.startListening();
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    // 듣는 중이면 빨간색, 아니면 초록색
                    backgroundColor: _controller.isListening ? Colors.redAccent : const Color(0xFF4CAF50),
                    radius: 24,
                    child: Icon(
                      // 듣는 중이면 정지 아이콘, 아니면 마이크 아이콘
                      _controller.isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                )
              else
              // ★ 텍스트 모드: 전송 버튼
                CircleAvatar(
                  backgroundColor: const Color(0xFF81C784),
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () {
                      _controller.sendMessage(_textController.text);
                      _textController.clear();
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}