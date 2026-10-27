import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final autoLogin = prefs.getBool('auto_login') ?? false;

  // 저장된 로그인 세션이 복원될 때까지 기다림
  final user = await FirebaseAuth.instance.authStateChanges().first;

  // 자동 로그인이 꺼져 있으면 남아있는 세션 제거
  if (!autoLogin && user != null) {
    await FirebaseAuth.instance.signOut();
  }

  final startLoggedIn = autoLogin && user != null;

  runApp(MyApp(startLoggedIn: startLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool startLoggedIn;

  const MyApp({super.key, this.startLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: startLoggedIn ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}