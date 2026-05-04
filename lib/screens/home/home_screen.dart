import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../task/task_add_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// 🔥 유저 정보 가져오기
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .get();
  }

  /// 🔥 todo 스트림 (null-safe 처리)
  Stream<QuerySnapshot<Map<String, dynamic>>> get _todosStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('todos')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 체크
    if (_uid == null) {
      return const Scaffold(
        body: Center(
          child: Text("로그인이 필요합니다"),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: getUser(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnap.data!.data();
        final userName = userData?['name'] ?? '사용자';

        return Scaffold(
          appBar: AppBar(
            title: Text("$userName님 👋"),
          ),

          /// ➕ 추가 버튼
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TaskAddScreen(),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),

          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _todosStream,
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
                    /// 📊 진행률 카드
                    Card(
                      child: ListTile(
                        title: const Text("오늘 진행률"),
                        subtitle: Text("$completed / $total 완료"),
                        trailing: Text("$percent%"),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// 📋 할 일 리스트
                    Expanded(
                      child: docs.isEmpty
                          ? const Center(
                        child: Text("할 일이 없습니다 🎉"),
                      )
                          : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();

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

                    /// 💡 추천 메시지
                    if (docs.isNotEmpty)
                      Container(
                        width: double.infinity,
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
      },
    );
  }
}