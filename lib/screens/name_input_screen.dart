import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class NameInputScreen extends StatefulWidget {
  const NameInputScreen({super.key});

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // ✅ FIX 1: mounted 체크 추가 → 딜레이 중 위젯이 dispose돼도 안전
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      focusNode.requestFocus();
    });
  }

  void save() {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(userName: name),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  // ✅ FIX 2: async 제거 + mounted 체크 추가
  //    → 비동기 gap 없이 context를 안전하게 사용
  void _onBackPressed() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX 3: WillPopScope → PopScope 로 교체
    //    canPop: false  → 기본 뒤로가기 동작 차단
    //    onPopInvokedWithResult: 직접 네비게이션 처리
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _onBackPressed,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "이름을 알려주세요",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "프로필에 표시됩니다",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => save(),
                  decoration: InputDecoration(
                    hintText: "이름 입력",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("완료"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}