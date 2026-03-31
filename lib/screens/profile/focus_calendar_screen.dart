import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/focus_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/focus_service.dart';
import '../../services/note_service.dart';

class FocusCalendarScreen extends StatefulWidget {
  const FocusCalendarScreen({super.key});

  @override
  State<FocusCalendarScreen> createState() => _FocusCalendarScreenState();
}

class _FocusCalendarScreenState extends State<FocusCalendarScreen> {
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  final FocusService _focusService = FocusService();
  Map<String, int> _minuteMap = {};
  bool _isLoading = true;
  String _userId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    if (_userId != uid) {
      _userId = uid;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final start = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final end = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      final snap = await db
          .collection('focus_sessions')
          .where('userId', isEqualTo: _userId)
          .where('completed', isEqualTo: true)
          .where('startedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startedAt', isLessThan: Timestamp.fromDate(end))
          .get();

      final result = <String, int>{};
      for (final doc in snap.docs) {
        final session = FocusSession.fromMap(doc.data());
        final dateKey = _dateKey(session.startedAt);
        result[dateKey] = (result[dateKey] ?? 0) + session.actualMinutes;
      }
      if (mounted) setState(() { _minuteMap = result; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _focusedMonth = next);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _minuteMap.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            '집중 캘린더',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMonthSummary(totalMinutes),
                  const SizedBox(height: 20),
                  _buildCalendarHeader(),
                  const SizedBox(height: 12),
                  _buildWeekdayLabels(),
                  const SizedBox(height: 8),
                  _buildCalendarGrid(context, _minuteMap, _userId),
                  const SizedBox(height: 20),
                  _buildLegend(),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSummary(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final timeStr = h > 0 ? '$h시간 $m분' : '$m분';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_focusedMonth.year}년 ${_focusedMonth.month}월',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            totalMinutes == 0 ? '집중 기록 없음' : '총 $timeStr 집중',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final now = DateTime.now();
    final isCurrentMonth = _focusedMonth.year == now.year &&
        _focusedMonth.month == now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _prevMonth,
          icon: Icon(Icons.chevron_left_rounded,
              color: AppTheme.of(context).textSecondary),
        ),
        Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월',
          style: TextStyle(
            color: AppTheme.of(context).textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        IconButton(
          onPressed: isCurrentMonth ? null : _nextMonth,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: isCurrentMonth ? AppTheme.of(context).textMuted : AppTheme.of(context).textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      color: AppTheme.of(context).textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(
      BuildContext context, Map<String, int> minuteMap, String userId) {
    final firstDay =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // weekday: 1=Mon, 7=Sun → offset = weekday-1
    final startOffset = firstDay.weekday - 1;
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final day = cellIndex - startOffset + 1;
            if (day < 1 || day > daysInMonth) {
              return const Expanded(child: SizedBox(height: 48));
            }
            final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
            final key = _dateKey(date);
            final minutes = minuteMap[key] ?? 0;
            final isToday = _isToday(date);
            final isFuture = date.isAfter(DateTime.now());

            return Expanded(
              child: GestureDetector(
                onTap: isFuture
                    ? null
                    : () => _showDaySheet(context, date, minutes, userId),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday
                        ? Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isFuture
                              ? AppTheme.of(context).textMuted
                              : isToday
                                  ? AppTheme.primaryColor
                                  : AppTheme.of(context).textPrimary,
                          fontSize: 13,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _buildDot(minutes, isFuture),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildDot(int minutes, bool isFuture) {
    if (isFuture || minutes == 0) {
      return const SizedBox(height: 6);
    }

    Color color;
    double size;
    if (minutes >= 60) {
      color = AppTheme.creditGold;
      size = 7;
    } else if (minutes >= 30) {
      color = AppTheme.primaryColor;
      size = 6;
    } else {
      color = AppTheme.primaryColor.withValues(alpha: 0.4);
      size = 5;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: minutes >= 60
            ? [
                BoxShadow(
                  color: AppTheme.creditGold.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(AppTheme.primaryColor.withValues(alpha: 0.4), '~30분'),
        const SizedBox(width: 16),
        _legendItem(AppTheme.primaryColor, '30~60분'),
        const SizedBox(width: 16),
        _legendItem(AppTheme.creditGold, '60분+'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: AppTheme.of(context).textMuted, fontSize: 12)),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showDaySheet(
      BuildContext context, DateTime date, int minutes, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DayDetailSheet(
        date: date,
        totalMinutes: minutes,
        userId: userId,
        focusService: _focusService,
      ),
    );
  }
}

class _DayDetailSheet extends StatefulWidget {
  final DateTime date;
  final int totalMinutes;
  final String userId;
  final FocusService focusService;

  const _DayDetailSheet({
    required this.date,
    required this.totalMinutes,
    required this.userId,
    required this.focusService,
  });

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  final _noteController = TextEditingController();
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final note =
        await NoteService.instance.getNote(widget.userId, widget.date);
    if (mounted && note != null) {
      _noteController.text = note.memo;
    }
  }

  Future<void> _saveNote() async {
    setState(() => _savingNote = true);
    await NoteService.instance.saveNote(
      widget.userId,
      widget.date,
      _noteController.text.trim(),
    );
    if (mounted) {
      setState(() => _savingNote = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메모가 저장되었어요'),
          backgroundColor: AppTheme.of(context).surface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${dt.month}월 ${dt.day}일 (${weekdays[dt.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.totalMinutes ~/ 60;
    final m = widget.totalMinutes % 60;
    final timeStr = widget.totalMinutes == 0
        ? '집중 기록 없음'
        : h > 0
            ? '$h시간 $m분'
            : '$m분';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.of(context).textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            _formatDate(widget.date),
            style: TextStyle(
              color: AppTheme.of(context).textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sessions list
          if (widget.totalMinutes > 0)
            FutureBuilder<List<FocusSession>>(
              future: _loadDaySessions(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                final sessions = snap.data ?? [];
                return Column(
                  children: sessions
                      .map((s) => _SessionRow(session: s))
                      .toList(),
                );
              },
            ),

          SizedBox(height: 16),

          // Memo
          Text(
            '하루 메모',
            style: TextStyle(
              color: AppTheme.of(context).textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 2,
            maxLength: 100,
            style: TextStyle(color: AppTheme.of(context).textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '오늘 집중하면서 느낀 점을 기록해보세요',
              hintStyle: TextStyle(
                  color: AppTheme.of(context).textMuted, fontSize: 13),
              counterStyle:
                  TextStyle(color: AppTheme.of(context).textMuted, fontSize: 11),
              filled: true,
              fillColor: AppTheme.of(context).card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.primaryColor, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: AppTheme.glowButton,
              child: ElevatedButton(
                onPressed: _savingNote ? null : _saveNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 46),
                ),
                child: _savingNote
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('저장'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<FocusSession>> _loadDaySessions() async {
    try {
      final db = FirebaseFirestore.instance;
      final start = DateTime(widget.date.year, widget.date.month, widget.date.day);
      final end = start.add(const Duration(days: 1));
      final snap = await db
          .collection('focus_sessions')
          .where('userId', isEqualTo: widget.userId)
          .where('completed', isEqualTo: true)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startedAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('startedAt', descending: false)
          .get();
      return snap.docs
          .map((d) => FocusSession.fromMap(d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class _SessionRow extends StatelessWidget {
  final FocusSession session;

  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final start = session.startedAt;
    final timeStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined,
              color: AppTheme.primaryColor, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              session.tag.isNotEmpty ? session.tag : '집중 세션',
              style: TextStyle(
                color: AppTheme.of(context).textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$timeStr · ${session.actualMinutes}분',
            style: TextStyle(
              color: AppTheme.of(context).textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
