import 'package:flutter/material.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int page = 0;

  final data = [
    ["할 일을 관리하세요", "체계적으로 관리"],
    ["행동을 분석하세요", "데이터 기반 분석"],
    ["더 나은 하루", "추천 제공"],
  ];

  void next() {
    if (page == data.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => page = i),
              itemCount: data.length,
              itemBuilder: (_, i) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_graph,
                      size: 120, color: Colors.blue),
                  const SizedBox(height: 40),
                  Text(data[i][0],
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(data[i][1]),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: next,
            child: Text(page == data.length - 1 ? "시작하기" : "다음"),
          ),
          const SizedBox(height: 40)
        ],
      ),
    );
  }
}