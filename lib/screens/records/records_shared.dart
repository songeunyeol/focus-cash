import 'package:flutter/material.dart';

import '../../design/ds.dart';
import '../../domain/goal_rules.dart';

/// 기록 탭들이 공유하는 작은 조각. 숫자 하나를 보여주는 계기판 타일과 섹션 제목.

/// 라벨 + 큰 숫자 + 단위. 값이 강조 대상이면 [accent] 로 액센트를 준다 (한 화면에 하나).
class RecordFact extends StatelessWidget {
  const RecordFact({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.accent = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Container(
      padding: Sp.card,
      decoration: DsSurface.e1(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: DsType.caption.on(c.textTertiary)),
          const SizedBox(height: Sp.x2),
          RichText(
            text: TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: value,
                  style: DsType.title
                      .on(accent ? c.accentText : c.textPrimary)
                      .tnum,
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: DsType.caption.on(c.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecordSectionTitle extends StatelessWidget {
  const RecordSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title, style: DsType.subhead.on(c.textPrimary)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 빈 상태·오류 안내 한 줄.
class RecordEmpty extends StatelessWidget {
  const RecordEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x8),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: DsType.body.on(c.textTertiary),
        ),
      ),
    );
  }
}

/// 바텀시트 상단 손잡이
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: c.borderStrong,
          borderRadius: R.rPill,
        ),
      ),
    );
  }
}

/// "1시간 30분" 표기. 목표 규칙과 같은 포맷을 쓴다.
String formatMinutesKo(int minutes) => GoalRules.label(minutes);

String dateKeyOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
