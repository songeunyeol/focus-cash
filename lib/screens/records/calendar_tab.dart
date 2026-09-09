import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/ds.dart';
import '../../models/focus_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/focus_service.dart';
import '../../services/note_service.dart';
import '../../widgets/common/ds_button.dart';
import '../../widgets/common/ds_pressable.dart';
import 'records_shared.dart';

/// 캘린더 탭 — 월별 히트맵. 날짜를 누르면 그날 세션 목록 + 메모.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab>
    with AutomaticKeepAliveClientMixin {
  final FocusService _focusService = FocusService();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, int> _minutes = <String, int>{};
  bool _loading = true;
  bool _failed = false;
  String _userId = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    if (_userId != uid) {
      _userId = uid;
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted || _userId.isEmpty) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await _focusService.getMonthlyMinutes(_userId, _month);
      if (mounted) setState(() => _minutes = result);
    } catch (e) {
      debugPrint('월별 기록 로드 실패: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _load();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final DsColors c = context.ds;
    final int total = _minutes.values.fold(0, (a, b) => a + b);
    final int activeDays = _minutes.values.where((m) => m > 0).length;

    return RefreshIndicator(
      color: c.flame,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x12),
        children: <Widget>[
          _MonthHeader(
            month: _month,
            canGoNext: !_isCurrentMonth,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const SizedBox(height: Sp.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: RecordFact(
                  label: '이달 집중',
                  value: total == 0 ? '0' : '${total ~/ 60}',
                  unit: total == 0 ? '분' : (total % 60 == 0 ? '시간' : '시간 ${total % 60}분'),
                  accent: total > 0,
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: RecordFact(
                  label: '집중한 날',
                  value: '$activeDays',
                  unit: '일',
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x4),
          Container(
            padding: const EdgeInsets.fromLTRB(Sp.x2, Sp.x3, Sp.x2, Sp.x3),
            decoration: DsSurface.e1(c),
            child: _loading
                ? const SizedBox(
                    height: 280,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _failed
                    ? const SizedBox(
                        height: 280,
                        child: RecordEmpty('기록을 불러오지 못했습니다.\n아래로 당겨 다시 시도해 주세요.'),
                      )
                    : Column(
                        children: <Widget>[
                          const _WeekdayLabels(),
                          const SizedBox(height: Sp.x2),
                          _Grid(
                            month: _month,
                            minutes: _minutes,
                            onTapDay: _openDay,
                          ),
                        ],
                      ),
          ),
          const SizedBox(height: Sp.x3),
          const _Legend(),
        ],
      ),
    );
  }

  void _openDay(DateTime date, int minutes) {
    final DsColors c = context.ds;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: R.rSheet),
      builder: (_) => _DaySheet(
        date: date,
        totalMinutes: minutes,
        userId: _userId,
        focusService: _focusService,
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        DsPressable(
          onTap: onPrev,
          child: Padding(
            padding: const EdgeInsets.all(Sp.x2),
            child: Icon(Icons.chevron_left_rounded, color: c.textSecondary),
          ),
        ),
        Text(
          '${month.year}년 ${month.month}월',
          style: DsType.subhead.on(c.textPrimary).tnum,
        ),
        DsPressable(
          onTap: canGoNext ? onNext : null,
          child: Padding(
            padding: const EdgeInsets.all(Sp.x2),
            child: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext ? c.textSecondary : c.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels();

  static const List<String> _days = <String>['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Row(
      children: _days
          .map((d) => Expanded(
                child: Center(
                  child: Text(d, style: DsType.micro.on(c.textTertiary)),
                ),
              ))
          .toList(),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.month,
    required this.minutes,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<String, int> minutes;
  final void Function(DateTime date, int minutes) onTapDay;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final DateTime first = DateTime(month.year, month.month, 1);
    final int offset = first.weekday - 1;
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final int rows = ((offset + daysInMonth) / 7).ceil();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return Column(
      children: List<Widget>.generate(rows, (row) {
        return Row(
          children: List<Widget>.generate(7, (col) {
            final int day = row * 7 + col - offset + 1;
            if (day < 1 || day > daysInMonth) {
              return const Expanded(child: SizedBox(height: 48));
            }
            final DateTime date = DateTime(month.year, month.month, day);
            final int m = minutes[dateKeyOf(date)] ?? 0;
            final bool isToday = date == today;
            final bool isFuture = date.isAfter(today);

            return Expanded(
              child: DsPressable(
                onTap: isFuture ? null : () => onTapDay(date, m),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isToday ? c.flameTint : Colors.transparent,
                    borderRadius: R.rSm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '$day',
                        style: DsType.caption
                            .on(isFuture
                                ? c.textDisabled
                                : isToday
                                    ? c.accentText
                                    : c.textPrimary)
                            .tnum,
                      ),
                      const SizedBox(height: 3),
                      _Dot(minutes: isFuture ? 0 : m),
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
}

/// 집중량 점. 색은 등급 규칙처럼 무채색→액센트로 옮겨간다.
class _Dot extends StatelessWidget {
  const _Dot({required this.minutes});

  final int minutes;

  static Color colorFor(DsColors c, int minutes) {
    if (minutes >= 60) return c.flame;
    if (minutes >= 30) return c.flameDim;
    return c.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    if (minutes <= 0) return const SizedBox(height: 6);
    final DsColors c = context.ds;
    final double size = minutes >= 60 ? 7 : (minutes >= 30 ? 6 : 5);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorFor(c, minutes),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    Widget item(int minutes, String label) => Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _Dot.colorFor(c, minutes),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Sp.x1 + 2),
            Text(label, style: DsType.micro.on(c.textTertiary)),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        item(10, '~30분'),
        const SizedBox(width: Sp.x4),
        item(30, '30~60분'),
        const SizedBox(width: Sp.x4),
        item(60, '60분+'),
      ],
    );
  }
}

// ───────────────────────────────────────────
// 하루 상세 시트
// ───────────────────────────────────────────

class _DaySheet extends StatefulWidget {
  const _DaySheet({
    required this.date,
    required this.totalMinutes,
    required this.userId,
    required this.focusService,
  });

  final DateTime date;
  final int totalMinutes;
  final String userId;
  final FocusService focusService;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  final TextEditingController _note = TextEditingController();
  late final Future<List<FocusSession>> _sessions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sessions = widget.totalMinutes > 0
        ? widget.focusService.getSessionsOnDay(widget.userId, widget.date)
        : Future<List<FocusSession>>.value(const <FocusSession>[]);
    _loadNote();
  }

  Future<void> _loadNote() async {
    final note = await NoteService.instance.getNote(widget.userId, widget.date);
    if (mounted && note != null) _note.text = note.memo;
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    try {
      await NoteService.instance
          .saveNote(widget.userId, widget.date, _note.text.trim());
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('메모를 저장했습니다'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('메모 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모를 저장하지 못했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime d) {
    const List<String> w = <String>['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일 (${w[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final String timeStr = widget.totalMinutes == 0
        ? '집중 기록 없음'
        : formatMinutesKo(widget.totalMinutes);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Sp.x6, Sp.x3, Sp.x6, MediaQuery.of(context).viewInsets.bottom + Sp.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHandle(),
          const SizedBox(height: Sp.x4),
          Text(_dateLabel(widget.date),
              style: DsType.caption.on(c.textTertiary)),
          const SizedBox(height: Sp.x1),
          Text(
            timeStr,
            style: DsType.title
                .on(widget.totalMinutes > 0 ? c.accentText : c.textSecondary)
                .tnum,
          ),
          const SizedBox(height: Sp.x4),
          if (widget.totalMinutes > 0)
            FutureBuilder<List<FocusSession>>(
              future: _sessions,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(Sp.x3),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final sessions = snap.data ?? const <FocusSession>[];
                return Column(
                  children: sessions.map((s) => _SessionRow(s)).toList(),
                );
              },
            ),
          const SizedBox(height: Sp.x3),
          Text('하루 메모', style: DsType.caption.on(c.textTertiary)),
          const SizedBox(height: Sp.x2),
          TextField(
            controller: _note,
            maxLines: 2,
            maxLength: 100,
            style: DsType.body.on(c.textPrimary),
            decoration: InputDecoration(
              hintText: '오늘 집중하면서 느낀 점을 남겨 두세요',
              hintStyle: DsType.body.on(c.textTertiary),
              counterStyle: DsType.micro.on(c.textTertiary),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: R.rSm,
                borderSide: BorderSide(color: c.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: R.rSm,
                borderSide: BorderSide(color: c.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: R.rSm,
                borderSide: BorderSide(color: c.flame, width: Stroke.hairline),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Sp.x3, vertical: Sp.x3),
            ),
          ),
          const SizedBox(height: Sp.x3),
          DsButton(
            label: _saving ? '저장 중…' : '저장',
            variant: DsButtonVariant.quiet,
            onPressed: _saving ? null : _saveNote,
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow(this.session);

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final DateTime s = session.startedAt;
    final String time =
        '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2 + 2),
      decoration: DsSurface.e1(c, radius: R.rSm),
      child: Row(
        children: <Widget>[
          Icon(Icons.timer_outlined, size: 16, color: c.textTertiary),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: Text(
              session.tag.isNotEmpty ? session.tag : '집중 세션',
              style: DsType.caption.on(c.textPrimary),
            ),
          ),
          Text(
            '$time · ${session.actualMinutes}분',
            style: DsType.caption.on(c.textSecondary).tnum,
          ),
        ],
      ),
    );
  }
}
