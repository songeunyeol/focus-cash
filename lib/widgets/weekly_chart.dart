import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../utils/responsive_utils.dart';

class WeeklyChart extends StatelessWidget {
  final List<int>? data;

  const WeeklyChart({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final chartData = data ?? List.filled(7, 0);
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    final maxY = chartData.reduce((a, b) => a > b ? a : b).toDouble();

    final chartHeight = context.isTablet ? 260.0 : 200.0;

    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY > 0 ? maxY * 1.2 : 60,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.of(context).surface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final minutes = chartData[group.x.toInt()];
                return BarTooltipItem(
                  '${minutes ~/ 60}시간 ${minutes % 60}분',
                  TextStyle(color: AppTheme.of(context).textPrimary, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        days[index],
                        style: TextStyle(
                          color: AppTheme.of(context).textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(chartData.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: chartData[index].toDouble(),
                  color: index == DateTime.now().weekday - 1
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withAlpha(100),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
