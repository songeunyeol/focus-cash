import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../design/ds.dart';

/// 주간 집중 막대 차트. 월~일 7칸.
///
/// 계기판 문법: 막대는 무채색, 오늘만 액센트. 격자선 없음, 헤어라인 표면.
class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, this.data});

  final List<int>? data;

  static const List<String> _days = <String>['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final List<int> values = data ?? List<int>.filled(7, 0);
    final int maxValue = values.fold(0, (a, b) => a > b ? a : b);
    final int todayIndex = DateTime.now().weekday - 1;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(Sp.x3, Sp.x4, Sp.x3, Sp.x2),
      decoration: DsSurface.e1(c),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue > 0 ? maxValue * 1.2 : 60,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.surfaceOverlay,
              tooltipBorderRadius: R.rSm,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final int minutes = values[group.x.toInt()];
                return BarTooltipItem(
                  '${minutes ~/ 60}시간 ${minutes % 60}분',
                  DsType.caption.on(c.textPrimary).tnum,
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final int i = value.toInt();
                  final bool isToday = i == todayIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: Sp.x2),
                    child: Text(
                      _days[i],
                      style: DsType.micro
                          .on(isToday ? c.textPrimary : c.textTertiary),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List<BarChartGroupData>.generate(7, (i) {
            final bool isToday = i == todayIndex;
            return BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: values[i].toDouble(),
                  width: 18,
                  borderRadius: R.rSm,
                  color: isToday ? c.flame : c.textTertiary,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValue > 0 ? maxValue * 1.2 : 60,
                    color: c.surfaceRaised,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
