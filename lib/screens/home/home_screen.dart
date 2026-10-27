import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../analysis/analysis_screen.dart';
import '../auth/login_screen.dart';
import '../task/task_add_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  String _userName = '사용자';
  bool _showAll = false;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _todosStream;

  static const int _previewCount = 5;
  static const Color _primary = Color(0xFF2F6BFF);

  @override
  void initState() {
    super.initState();

    if (_uid != null) {
      _todosStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('todos')
          .snapshots();
      _loadUser();
    }
  }

  /// 유저 이름 한 번만 가져오기 (실패해도 화면은 정상 표시)
  Future<void> _loadUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      final name = doc.data()?['name'];
      if (name is String && name.isNotEmpty && mounted) {
        setState(() => _userName = name);
      }
    } catch (_) {
      // 이름을 못 가져와도 기본값 '사용자'로 계속 진행
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// 'date' 필드가 있으면 오늘 것만, 없으면 모두 포함
  bool _isToday(Map<String, dynamic> data) {
    final d = data['date'];
    final now = DateTime.now();

    if (d is Timestamp) {
      final dt = d.toDate();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }

    if (d is String) {
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      return d.startsWith(today);
    }

    return true;
  }

  /// 완료 토글
  Future<void> _toggleDone(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    try {
      final current = doc.data()['isDone'] == true;
      await doc.reference.update({'isDone': !current});
    } catch (e) {
      _showMessage("변경 실패: $e");
    }
  }

  /// 삭제
  Future<void> _delete(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    try {
      await doc.reference.delete();
    } catch (e) {
      _showMessage("삭제 실패: $e");
    }
  }

  /// 진행률에 따른 추천 메시지
  String _recommendMessage(int total, int percent) {
    if (total == 0) return "오늘 할 일을 추가해보세요 ✍️";
    if (percent == 100) return "오늘 할 일을 모두 끝냈어요! 대단해요 🎉";
    if (percent >= 60) return "거의 다 왔어요, 조금만 더 힘내세요 💪";
    if (percent > 0) return "좋은 시작이에요, 이 흐름을 이어가세요 👍";
    return "첫 번째 할 일부터 시작해볼까요? 🚀";
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("로그아웃"),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _goAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TaskAddScreen()),
    );
  }

  /// 분석 화면으로 이동
  void _goAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalysisScreen()),
    );
  }

  /// 상단 인사말 + 알림 + 아바타
  Widget _buildHeader() {
    final initial = _userName.isNotEmpty ? _userName.characters.first : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  children: [
                    const TextSpan(text: "안녕하세요, "),
                    TextSpan(
                      text: _userName,
                      style: const TextStyle(color: _primary),
                    ),
                    const TextSpan(text: "님 👋"),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "오늘도 생산적인 하루 보내세요!",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () => _showMessage("알림 기능은 준비 중입니다"),
        ),
        CircleAvatar(
          radius: 18,
          backgroundColor: _primary.withOpacity(0.15),
          child: Text(
            initial,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 원형 진행률 카드
  Widget _buildProgressCard(int total, int completed, int percent) {
    final remain = total - completed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "오늘의 진행률",
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: total == 0 ? 0 : completed / total,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(_primary),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      "$percent%",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$completed / $total 완료",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "남은 할 일 $remain개",
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 할 일 한 줄
  Widget _buildTodoItem(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final isDone = data['isDone'] == true;
    final title = (data['title'] ?? '').toString();
    final time = (data['time'] ?? '').toString();

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.horizontal,
      background: _dismissBackground(Alignment.centerLeft),
      secondaryBackground: _dismissBackground(Alignment.centerRight),
      onDismissed: (_) => _delete(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          onTap: () => _toggleDone(doc),
          leading: Icon(
            isDone ? Icons.check_box : Icons.check_box_outline_blank,
            color: isDone ? _primary : Colors.grey,
            size: 28,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? Colors.grey : Colors.black,
            ),
          ),
          trailing: Text(
            time,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _dismissBackground(Alignment alignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  /// 하단 네비게이션 아이템
  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final color = selected ? _primary : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 체크
    if (_uid == null || _todosStream == null) {
      return const Scaffold(
        body: Center(child: Text("로그인이 필요합니다")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      /// ➕ 가운데 추가 버튼
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        shape: const CircleBorder(),
        onPressed: _goAddTask,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// 하단 네비게이션
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              icon: Icons.home,
              label: "홈",
              selected: true,
              onTap: () {},
            ),
            _navItem(
              icon: Icons.bar_chart,
              label: "분석",
              onTap: _goAnalysis,
            ),
            const SizedBox(width: 48), // FAB 자리
            _navItem(
              icon: Icons.calendar_today_outlined,
              label: "캘린더",
              onTap: () => _showMessage("캘린더 화면은 준비 중입니다"),
            ),
            _navItem(
              icon: Icons.settings_outlined,
              label: "설정",
              onTap: _openSettings,
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _todosStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "데이터를 불러오지 못했습니다\n${snapshot.error}",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = (snapshot.data?.docs ?? [])
                .where((d) => _isToday(d.data()))
                .toList();

            final total = docs.length;
            final completed =
                docs.where((d) => d.data()['isDone'] == true).length;
            final percent =
            total == 0 ? 0 : ((completed / total) * 100).round();

            final visibleDocs = _showAll || docs.length <= _previewCount
                ? docs
                : docs.take(_previewCount).toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),

                  _buildProgressCard(total, completed, percent),
                  const SizedBox(height: 24),

                  /// 오늘 할 일 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "오늘 할 일",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (docs.length > _previewCount)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showAll = !_showAll),
                          child: Text(_showAll ? "접기 ˄" : "전체 보기 ˃"),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  /// 할 일 리스트
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(child: Text("할 일이 없습니다 🎉"))
                        : ListView.builder(
                      itemCount: visibleDocs.length,
                      itemBuilder: (context, index) =>
                          _buildTodoItem(visibleDocs[index]),
                    ),
                  ),

                  /// 추천 메시지
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_recommendMessage(total, percent)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}