import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../task/task_add_screen.dart';

enum AnalysisPeriod { day, week, month }

/// 완료된 할 일 하나를 분석용으로 정리한 데이터
class _Entry {
  final DateTime date;
  final int minutes;
  final int? hour;

  const _Entry(this.date, this.minutes, this.hour);
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  static const Color _primary = Color(0xFF2F6BFF);

  /// 할 일에 duration(분)이 없을 때 사용하는 기본 집중 시간
  static const int _defaultMinutes = 60;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  AnalysisPeriod _period = AnalysisPeriod.week;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);

    if (_uid != null) {
      _stream = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('todos')
          .snapshots();
    }
  }

  // ───────────────────────── 데이터 변환 ─────────────────────────

  DateTime? _dateOf(dynamic d) {
    if (d is Timestamp) {
      final dt = d.toDate();
      return DateTime(dt.year, dt.month, dt.day);
    }
    if (d is String && d.length >= 10) {
      final dt = DateTime.tryParse(d.substring(0, 10));
      if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    }
    return null;
  }

  /// "오전 10:00", "오후 6:00", "14:30" 형식에서 시(hour) 추출
  int? _hourOf(dynamic t) {
    if (t is! String) return null;

    final match = RegExp(r'(\d{1,2})\s*:\s*(\d{2})').firstMatch(t);
    if (match == null) return null;

    var h = int.tryParse(match.group(1)!);
    if (h == null || h > 23) return null;

    final isPm = t.contains('오후') || t.toUpperCase().contains('PM');
    final isAm = t.contains('오전') || t.toUpperCase().contains('AM');

    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;

    return h;
  }

  List<_Entry> _toEntries(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final result = <_Entry>[];

    for (final doc in docs) {
      final data = doc.data();
      if (data['isDone'] != true) continue;

      final date = _dateOf(data['date']);
      if (date == null) continue;

      final dur = data['duration'];
      final minutes = dur is num && dur > 0 ? dur.toInt() : _defaultMinutes;

      result.add(_Entry(date, minutes, _hourOf(data['time'])));
    }

    return result;
  }

  // ───────────────────────── 기간 계산 ─────────────────────────

  /// [시작, 끝) 범위
  (DateTime, DateTime) _rangeOf(DateTime anchor) {
    switch (_period) {
      case AnalysisPeriod.day:
        return (anchor, DateTime(anchor.year, anchor.month, anchor.day + 1));
      case AnalysisPeriod.week:
        final start =
        DateTime(anchor.year, anchor.month, anchor.day - (anchor.weekday - 1));
        return (start, DateTime(start.year, start.month, start.day + 7));
      case AnalysisPeriod.month:
        return (
        DateTime(anchor.year, anchor.month, 1),
        DateTime(anchor.year, anchor.month + 1, 1),
        );
    }
  }

  DateTime _shifted(int dir) {
    switch (_period) {
      case AnalysisPeriod.day:
        return DateTime(_anchor.year, _anchor.month, _anchor.day + dir);
      case AnalysisPeriod.week:
        return DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir);
      case AnalysisPeriod.month:
        return DateTime(_anchor.year, _anchor.month + dir, 1);
    }
  }

  bool get _canGoNext {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final (_, end) = _rangeOf(_anchor);
    return end.isBefore(todayDate) || end.isAtSameMomentAs(todayDate);
  }

  String _rangeLabel() {
    final (start, end) = _rangeOf(_anchor);

    switch (_period) {
      case AnalysisPeriod.day:
        return '${start.month}월 ${start.day}일';
      case AnalysisPeriod.week:
        final last = end.subtract(const Duration(days: 1));
        return '${start.month}월 ${start.day}일 - ${last.month}월 ${last.day}일';
      case AnalysisPeriod.month:
        return '${start.year}년 ${start.month}월';
    }
  }

  String get _compareLabel {
    switch (_period) {
      case AnalysisPeriod.day:
        return '전일 대비';
      case AnalysisPeriod.week:
        return '지난주 대비';
      case AnalysisPeriod.month:
        return '지난달 대비';
    }
  }

  List<_Entry> _inRange(List<_Entry> all, DateTime start, DateTime end) {
    return all
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();
  }

  int _sum(List<_Entry> list) => list.fold(0, (s, e) => s + e.minutes);

  // ───────────────────────── 차트 데이터 ─────────────────────────

  (List<double>, List<String>) _buckets(List<_Entry> entries, DateTime start) {
    switch (_period) {
      case AnalysisPeriod.day:
        final values = List<double>.filled(8, 0);
        for (final e in entries) {
          if (e.hour == null) continue;
          values[e.hour! ~/ 3] += e.minutes;
        }
        return (values, ['0', '3', '6', '9', '12', '15', '18', '21']);

      case AnalysisPeriod.week:
        final values = List<double>.filled(7, 0);
        for (final e in entries) {
          final idx = e.date.weekday - 1;
          values[idx] += e.minutes;
        }
        return (values, ['월', '화', '수', '목', '금', '토', '일']);

      case AnalysisPeriod.month:
        final days = DateTime(start.year, start.month + 1, 0).day;
        final values = List<double>.filled(days, 0);
        for (final e in entries) {
          values[e.date.day - 1] += e.minutes;
        }
        final labels = List.generate(
          days,
              (i) => (i == 0 || (i + 1) % 5 == 0) ? '${i + 1}' : '',
        );
        return (values, labels);
    }
  }

  /// 시간대별(0~23시) 집중 분
  List<double> _hourly(List<_Entry> entries) {
    final values = List<double>.filled(24, 0);
    for (final e in entries) {
      if (e.hour == null) continue;
      values[e.hour!] += e.minutes;
    }
    return values;
  }

  /// 연속 3시간 중 가장 집중한 구간의 시작 시각 (없으면 null)
  int? _bestStartHour(List<double> hourly) {
    double best = 0;
    int? bestStart;

    for (var s = 0; s <= 21; s++) {
      final sum = hourly[s] + hourly[s + 1] + hourly[s + 2];
      if (sum > best) {
        best = sum;
        bestStart = s;
      }
    }
    return bestStart;
  }

  // ───────────────────────── 포맷 ─────────────────────────

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  String _fmtDiff(int diff) {
    final sign = diff >= 0 ? '+' : '-';
    return '$sign${_fmt(diff.abs())}';
  }

  String _hourText(int h) {
    final hh = h % 24;
    final display = hh % 12 == 0 ? 12 : hh % 12;
    return '$display${hh < 12 ? 'AM' : 'PM'}';
  }

  String _slotName(int startHour) {
    if (startHour < 12) return '오전 시간대';
    if (startHour < 18) return '오후 시간대';
    return '저녁 시간대';
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _changePeriod(AnalysisPeriod p) {
    if (p == _period) return;
    final now = DateTime.now();
    setState(() {
      _period = p;
      _anchor = DateTime(now.year, now.month, now.day);
    });
  }

  // ───────────────────────── 위젯 ─────────────────────────

  Widget _buildTabs() {
    Widget tab(String label, AnalysisPeriod p) {
      final selected = _period == p;
      return Expanded(
        child: GestureDetector(
          onTap: () => _changePeriod(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? _primary : Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('일간', AnalysisPeriod.day),
        tab('주간', AnalysisPeriod.week),
        tab('월간', AnalysisPeriod.month),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _anchor = _shifted(-1)),
        ),
        Text(
          _rangeLabel(),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _canGoNext ? () => setState(() => _anchor = _shifted(1)) : null,
        ),
      ],
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _buildFocusCard({
    required int total,
    required int prevTotal,
    required int doneCount,
    required List<double> values,
    required List<String> labels,
  }) {
    final diff = total - prevTotal;
    final maxV = values.fold<double>(0, math.max);
    const chartHeight = 130.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('집중 시간', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            _fmt(total),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(_compareLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 6),
              Text(
                _fmtDiff(diff),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: diff >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const Spacer(),
              Text('완료 $doneCount개',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: chartHeight + 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final ratio = maxV == 0 ? 0.0 : values[i] / maxV;
                final barH = values[i] > 0
                    ? math.max(6.0, ratio * chartHeight)
                    : 3.0;
                final isMax = maxV > 0 && values[i] == maxV;
                final narrow = values.length > 12;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: narrow ? 6 : 22,
                        height: barH,
                        decoration: BoxDecoration(
                          color: values[i] > 0
                              ? _primary.withOpacity(isMax ? 1 : 0.65)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(narrow ? 3 : 6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 16,
                        child: Text(
                          labels[i],
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestTimeCard(List<double> hourly) {
    final bestStart = _bestStartHour(hourly);

    // 6시~23시 구간을 3점 이동평균으로 부드럽게
    final raw = hourly.sublist(6, 24);
    final smooth = List<double>.generate(raw.length, (i) {
      final prev = i > 0 ? raw[i - 1] : raw[i];
      final next = i < raw.length - 1 ? raw[i + 1] : raw[i];
      return (prev + raw[i] + next) / 3;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('집중이 잘 되는 시간대',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (bestStart == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '이 기간에 시간이 기록된 완료 항목이 없어요',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _slotName(bestStart),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_hourText(bestStart)} - ${_hourText(bestStart + 3)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '집중도 높음',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              width: double.infinity,
              child: CustomPaint(
                painter: _CurvePainter(values: smooth, color: _primary),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('6시', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('12시', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('18시', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('23시', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
    if (_uid == null || _stream == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        shape: const CircleBorder(),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskAddScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              icon: Icons.home_outlined,
              label: '홈',
              onTap: () => Navigator.pop(context),
            ),
            _navItem(
              icon: Icons.bar_chart,
              label: '분석',
              selected: true,
              onTap: () {},
            ),
            const SizedBox(width: 48),
            _navItem(
              icon: Icons.calendar_today_outlined,
              label: '캘린더',
              onTap: () => _showMessage('캘린더 화면은 준비 중입니다'),
            ),
            _navItem(
              icon: Icons.settings_outlined,
              label: '설정',
              onTap: () => _showMessage('설정은 홈 화면에서 이용할 수 있습니다'),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '데이터를 불러오지 못했습니다\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = _toEntries(snapshot.data?.docs ?? []);

            final (start, end) = _rangeOf(_anchor);
            final current = _inRange(all, start, end);

            final prevAnchor = _shifted(-1);
            final (pStart, pEnd) = _rangeOf(prevAnchor);
            final previous = _inRange(all, pStart, pEnd);

            final (values, labels) = _buckets(current, start);
            final hourly = _hourly(current);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text(
                  '분석',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildTabs(),
                const SizedBox(height: 4),
                _buildRangeSelector(),
                const SizedBox(height: 8),
                _buildFocusCard(
                  total: _sum(current),
                  prevTotal: _sum(previous),
                  doneCount: current.length,
                  values: values,
                  labels: labels,
                ),
                const SizedBox(height: 16),
                _buildBestTimeCard(hourly),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 부드러운 곡선 + 그라데이션 영역 차트
class _CurvePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _CurvePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final maxV = values.fold<double>(0, math.max);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : i / (values.length - 1) * w;
      final y = maxV == 0 ? h - 2 : h - 4 - (values[i] / maxV) * (h - 12);
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      line.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.28), color.withOpacity(0.02)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.values != values || old.color != color;
}