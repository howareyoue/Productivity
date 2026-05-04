import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskAddScreen extends StatefulWidget {
  const TaskAddScreen({super.key});

  @override
  State<TaskAddScreen> createState() => _TaskAddScreenState();
}

class _TaskAddScreenState extends State<TaskAddScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController timeController = TextEditingController();

  bool isLoading = false;

  /// 🔥 할 일 저장
  Future<void> addTask() async {
    final title = titleController.text.trim();
    final time = timeController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("할 일을 입력하세요")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .add({
        'title': title,
        'time': time,
        'isDone': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// 🔥 시간 선택
  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      timeController.text = picked.format(context);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("할 일 추가"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 📝 할 일 입력
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "할 일",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            /// ⏰ 시간 입력
            TextField(
              controller: timeController,
              readOnly: true,
              onTap: pickTime,
              decoration: const InputDecoration(
                labelText: "시간 (선택)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            /// 💾 저장 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : addTask,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(
                  color: Colors.white,
                )
                    : const Text("저장"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}