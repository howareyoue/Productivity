import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'name_input_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isLoginMode = true; // true = 로그인, false = 회원가입
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// 유저 체크 후 분기
  Future<void> handleUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (int i = 0; i < 3; i++) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (doc.exists && doc.data() != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NameInputScreen()),
          );
        }
        return;
      } catch (e) {
        if (i == 2) {
          showMessage("서버 연결 실패: $e");
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  /// 로그인
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("이메일과 비밀번호를 입력해주세요");
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await handleUser();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          showMessage("등록되지 않은 이메일입니다");
          break;
        case 'wrong-password':
          showMessage("비밀번호가 틀렸습니다");
          break;
        case 'invalid-email':
          showMessage("이메일 형식이 올바르지 않습니다");
          break;
        case 'invalid-credential':
          showMessage("이메일 또는 비밀번호가 올바르지 않습니다");
          break;
        default:
          showMessage("로그인 실패: ${e.message}");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// 회원가입
  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("이메일과 비밀번호를 입력해주세요");
      return;
    }

    if (password.length < 6) {
      showMessage("비밀번호는 6자 이상이어야 합니다");
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await handleUser();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          showMessage("이미 사용 중인 이메일입니다");
          break;
        case 'invalid-email':
          showMessage("이메일 형식이 올바르지 않습니다");
          break;
        case 'weak-password':
          showMessage("비밀번호가 너무 짧습니다 (6자 이상)");
          break;
        default:
          showMessage("회원가입 실패: ${e.message}");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),

              const Icon(Icons.auto_graph, size: 100, color: Colors.blue),
              const SizedBox(height: 20),

              Text(
                isLoginMode ? "로그인" : "회원가입",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                isLoginMode ? "계정으로 로그인하세요" : "새 계정을 만들어보세요",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 40),

              /// 이메일 입력
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "이메일",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// 비밀번호 입력
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: "비밀번호",
                  prefixIcon: const Icon(Icons.lock_outlined),
                  helperText: isLoginMode ? null : "6자 이상 입력하세요",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => obscurePassword = !obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// 로그인 / 회원가입 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : (isLoginMode ? login : register),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    isLoginMode ? "로그인" : "회원가입",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// 모드 전환
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLoginMode ? "계정이 없으신가요?" : "이미 계정이 있으신가요?",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => isLoginMode = !isLoginMode);
                      emailController.clear();
                      passwordController.clear();
                    },
                    child: Text(isLoginMode ? "회원가입" : "로그인"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}