// controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiController extends ChangeNotifier {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _modelName = 'gemini-2.5-flash';

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // STT & TTS 객체
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentRecognizedWords = ""; // 음성 인식 중인 텍스트

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String get currentRecognizedWords => _currentRecognizedWords;

  GeminiController() {
    _initTTS();
    _initSTT();
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setPitch(1.0);
  }

  void _initSTT() async {
    await _speech.initialize();
  }

  // [기능 1] 메시지 전송 및 Gemini 호출
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    _messages.add(ChatMessage(role: 'user', content: userMessage));
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$_modelName:generateContent',
        {'key': _apiKey},
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": userMessage}]}]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String botReply = data['candidates'][0]['content']['parts'][0]['text'];

        _messages.add(ChatMessage(role: 'model', content: botReply));

        // AI 응답을 TTS로 읽어주기
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

  // [기능 2] TTS 말하기
  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  // [기능 3] STT 듣기 시작
  Future<void> startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      _isListening = true;
      notifyListeners();
      _speech.listen(
        onResult: (val) {
          _currentRecognizedWords = val.recognizedWords;
          notifyListeners();
        },
        localeId: "ko_KR",
      );
    }
  }

  // [기능 4] STT 듣기 멈춤 및 전송
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    notifyListeners();

    if (_currentRecognizedWords.isNotEmpty) {
      // 음성 인식된 텍스트로 메시지 전송
      await sendMessage(_currentRecognizedWords);
      _currentRecognizedWords = ""; // 초기화
    }
  }
}