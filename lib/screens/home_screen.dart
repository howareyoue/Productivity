import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Query<Map<String, dynamic>>? get _todosRef {
    if (_uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('todos')
        .orderBy('time');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$userName님 👋"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: _todosRef == null
          ? const Center(child: Text("로그인이 필요합니다"))
          : StreamBuilder<QuerySnapshot>(
        stream: _todosRef!.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("오류가 발생했습니다"));
          }

          final docs = snapshot.data?.docs ?? [];
          final total = docs.length;
          final completed =
              docs.where((d) => d['isDone'] == true).length;
          final percent =
          total == 0 ? 0 : ((completed / total) * 100).round();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// 진행률 카드
                Card(
                  child: ListTile(
                    title: const Text("오늘 진행률"),
                    subtitle: Text("$completed / $total 완료"),
                    trailing: Text("$percent%"),
                  ),
                ),

                const SizedBox(height: 20),

                /// 할 일 목록
                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text("할 일이 없습니다 🎉"))
                      : ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data()
                      as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['title'] ?? ''),
                        subtitle: Text(data['time'] ?? ''),
                        leading: Icon(
                          data['isDone'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: data['isDone'] == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                      );
                    },
                  ),
                ),

                /// 추천
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("오전에 집중도가 높습니다 👍"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}