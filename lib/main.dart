// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ★ .env 패키지
import 'view.dart'; // ★ 화면(HomeScreen) 불러오기

void main() async { // ★ [중요] async 키워드가 꼭 있어야 합니다!

  // ★ [중요] Flutter 엔진을 미리 초기화해야 .env를 읽을 수 있음
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // .env 파일 불러오기
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // 만약 .env 파일이 없거나 에러가 나면 콘솔에 출력
    print("WARNING: .env 파일을 찾을 수 없거나 로딩 실패. ($e)");
  }

  runApp(const MyGeminiApp());
}

class MyGeminiApp extends StatelessWidget {
  const MyGeminiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Gemini Project 12',
      debugShowCheckedModeBanner: false,

      // 나만의 UI 테마 (흰색 & 연두색)
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF81C784),
        scaffoldBackgroundColor: Colors.white,
      ),

      // 첫 화면을 HomeScreen으로 설정
      home: const HomeScreen(),
    );
  }
}