import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'model.dart';

class GeminiController extends ChangeNotifier {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _modelName = 'gemini-2.5-flash';

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _picker = ImagePicker();

  bool _isListening = false;
  String _currentRecognizedWords = "";
  XFile? _selectedImage;

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String get currentRecognizedWords => _currentRecognizedWords;
  XFile? get selectedImage => _selectedImage;

  GeminiController() {
    _initTTS();
    _initSTT();
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("ko-KR");
  }

  // ★ [수정됨] STT 상태 변화 감지 로직 추가
  void _initSTT() async {
    await requestPermission(); // 권한 요청

    try {
      await _speech.initialize(
        onStatus: (status) {
          // 상태가 변할 때마다 로그 출력
          print('[STT 상태] $status');

          // 만약 STT가 스스로 종료되거나(done), 듣지 않는 상태(notListening)가 되면
          // 버튼 색깔도 원래대로(초록색) 돌려놓기
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners(); // 화면 갱신
          }
        },
        onError: (errorNotification) {
          print('[STT 에러] $errorNotification');
          _isListening = false;
          notifyListeners();
        },
      );
    } catch (e) {
      print('[STT 초기화 에러] $e');
    }
  }

  Future<void> requestPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _selectedImage = image;
        notifyListeners();
      }
    } catch (e) {
      print("사진 선택 에러: $e");
    }
  }

  void cancelImage() {
    _selectedImage = null;
    notifyListeners();
  }

  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty && _selectedImage == null) return;

    _messages.add(ChatMessage(
      role: 'user',
      content: userMessage,
      imagePath: _selectedImage?.path,
    ));

    final String? imageToSendPath = _selectedImage?.path;
    _selectedImage = null;

    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$_modelName:generateContent',
        {'key': _apiKey},
      );

      List<Map<String, dynamic>> parts = [];
      if (userMessage.isNotEmpty) parts.add({"text": userMessage});

      if (imageToSendPath != null) {
        final File imageFile = File(imageToSendPath);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);
          parts.add({
            "inline_data": { "mime_type": "image/jpeg", "data": base64Image }
          });
        }
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({ "contents": [ { "parts": parts } ] }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String botReply = data['candidates'][0]['content']['parts'][0]['text'];
        _messages.add(ChatMessage(role: 'model', content: botReply));
        speak(botReply);
      } else {
        _messages.add(ChatMessage(role: 'model', content: 'Error: ${response.statusCode}'));
      }
    } catch (e) {
      _messages.add(ChatMessage(role: 'model', content: 'Error: $e'));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> speak(String text) async => await _flutterTts.speak(text);

  Future<void> startListening() async {
    // 권한 다시 체크
    if (await Permission.microphone.isDenied) {
      await requestPermission();
    }

    // STT가 초기화되어 있고 사용 가능한지 확인
    bool available = await _speech.initialize();

    if (available) {
      _isListening = true;
      notifyListeners();
      _speech.listen(
        onResult: (val) {
          // 실시간으로 인식된 단어 업데이트
          _currentRecognizedWords = val.recognizedWords;
          notifyListeners();
        },
        localeId: "ko_KR",
      );
    } else {
      print("STT 초기화 실패 또는 마이크 사용 불가");
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    notifyListeners();

    // 멈췄을 때 인식된 글자가 있으면 전송
    if (_currentRecognizedWords.isNotEmpty) {
      await sendMessage(_currentRecognizedWords);
      _currentRecognizedWords = ""; // 전송 후 초기화
    }
  }
}