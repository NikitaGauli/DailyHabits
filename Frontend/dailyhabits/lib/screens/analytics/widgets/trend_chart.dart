import 'package:dailyhabits/models/analytics_summary.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrendChart extends StatelessWidget {
  final List<WeeklyDataPoint> weeklyData;

  const TrendChart({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return AspectRatio(
      aspectRatio: 1.70,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          color: tc.bg,
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            right: 18.0,
            left: 12.0,
            top: 24,
            bottom: 12,
          ),
          child: LineChart(mainData(tc)),
        ),
      ),
    );
  }

  LineChartData mainData(ThemeColors tc) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 25, // Percentage
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: tc.surface, strokeWidth: 1);
        },
        getDrawingVerticalLine: (value) {
          return FlLine(color: tc.surface, strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) => bottomTitleWidgets(value, meta, tc),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 25,
            getTitlesWidget: (value, meta) => leftTitleWidgets(value, meta, tc),
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: tc.surface),
      ),
      minX: 0,
      maxX: (weeklyData.length - 1).toDouble(),
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: _getSpots(),
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              tc.accent,
              AppColors.warning,
            ].map((color) => color).toList(),
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                tc.accent,
                AppColors.warning,
              ].map((color) => color.withValues(alpha: 0.3)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta, ThemeColors tc) {
    final style = TextStyle(
      color: tc.textMuted,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    int index = value.toInt();
    Widget text;
    if (index >= 0 && index < weeklyData.length) {
      // Use the day name from data, e.g., 'Mon'
      text = Text(weeklyData[index].day, style: style);
    } else {
      text = Text('', style: style);
    }

    return SideTitleWidget(axisSide: meta.axisSide, child: text);
  }

  Widget leftTitleWidgets(double value, TitleMeta meta, ThemeColors tc) {
    final style = TextStyle(
      color: tc.textMuted,
      fontWeight: FontWeight.bold,
      fontSize: 15,
    );
    String text;
    switch (value.toInt()) {
      case 0:
        text = '0%';
        break;
      case 50:
        text = '50%';
        break;
      case 100:
        text = '100%';
        break;
      default:
        return Container();
    }

    return Text(text, style: style, textAlign: TextAlign.center);
  }

  List<FlSpot> _getSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < weeklyData.length; i++) {
      spots.add(FlSpot(i.toDouble(), weeklyData[i].rate));
    }
    return spots;
  }
}
