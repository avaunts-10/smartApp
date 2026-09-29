import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'app_shell.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;
  bool _mid(BuildContext c) => MediaQuery.of(c).size.width >= 680;

  @override
  Widget build(BuildContext context) {
    final kpiCols = _wide(context) ? 4 : (_mid(context) ? 2 : 1);

    return AppShell(
      title: 'Analytics & Reports',
      subtitle: 'Insights and trends for classroom management',
      selectedRoute: '/analytics',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Grid(
            columns: kpiCols,
            children: const [
              _KpiCard(
                title: 'Avg.\nAttendance',
                value: '94.2%',
                note: '+2.3% from last\nmonth',
                noteColor: Color(0xFF16A34A),
              ),
              _KpiCard(
                title: 'Energy Saved',
                value: '18%',
                note: 'vs. last semester',
                noteColor: Color(0xFF16A34A),
              ),
              _KpiCard(
                title: 'Room\nUtilization',
                value: '87%',
                note: 'Optimal range',
                noteColor: Color(0xFF2563EB),
              ),
              _KpiCard(
                title: 'Cost Savings',
                value: '\$2,340',
                note: 'This month',
                noteColor: Color(0xFF16A34A),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TwoCardsRow(
            left: _CardSection(
              title: 'Weekly Energy Usage',
              child: SizedBox(height: 240, child: _WeeklyBarChart()),
            ),
            right: _CardSection(
              title: 'Classroom Utilization',
              child: SizedBox(height: 240, child: _UtilizationPie()),
            ),
          ),
          const SizedBox(height: 16),
          _CardSection(
            title: 'Attendance Trends',
            child: SizedBox(height: 260, child: _AttendanceLine()),
          ),
          const SizedBox(height: 16),
          _CardSection(
            title: 'Predictive Maintenance Alerts',
            child: Column(
              children: const [
                _AlertTile(
                  title: 'HVAC Filter Replacement',
                  subtitle: 'Recommended in 5 days based on usage patterns',
                  bg: Color(0xFFFFF7E6),
                  buttonColor: Color(0xFFEA7B00),
                ),
                SizedBox(height: 12),
                _AlertTile(
                  title: 'Projector Lamp Check',
                  subtitle: 'Approaching 80% of rated lifespan',
                  bg: Color(0xFFEFF6FF),
                  buttonColor: Color(0xFF2563EB),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- components ---------------- */

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final spacing = 14.0;
      final w = c.maxWidth;
      final itemW = (w - (columns - 1) * spacing) / columns;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children:
            children.map((e) => SizedBox(width: itemW, child: e)).toList(),
      );
    });
  }
}

class _TwoCardsRow extends StatelessWidget {
  const _TwoCardsRow({required this.left, required this.right});
  final Widget left;
  final Widget right;

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;

  @override
  Widget build(BuildContext context) {
    if (_wide(context)) {
      return Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      children: [
        left,
        const SizedBox(height: 14),
        right,
      ],
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 16),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.note,
    required this.noteColor,
  });

  final String title;
  final String value;
  final String note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.6),
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(note,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: noteColor)),
        ],
      ),
    );
  }
}

/* ---------------- charts ---------------- */

class _WeeklyBarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: 60,
        minY: 0,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.black.withOpacity(0.06), strokeWidth: 1),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.black.withOpacity(0.12)),
            bottom: BorderSide(color: Colors.black.withOpacity(0.12)),
            right: const BorderSide(color: Colors.transparent),
            top: const BorderSide(color: Colors.transparent),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 15,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(v.toStringAsFixed(0),
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.black.withOpacity(0.55))),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.black.withOpacity(0.55))),
                );
              },
            ),
          ),
        ),
        barGroups: [
          _bar(0, 45),
          _bar(1, 54),
          _bar(2, 48),
          _bar(3, 57),
          _bar(4, 42),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 22,
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFF2D66F6),
        ),
      ],
    );
  }
}

class _UtilizationPie extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        centerSpaceRadius: 0,
        sectionsSpace: 1,
        sections: [
          PieChartSectionData(
              value: 40, color: const Color(0xFF2D66F6), title: ''),
          PieChartSectionData(
              value: 40, color: const Color(0xFF10B981), title: ''),
          PieChartSectionData(
              value: 20, color: const Color(0xFFF59E0B), title: ''),
        ],
      ),
    );
  }
}

class _AttendanceLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minX: 1,
        maxX: 4,
        minY: 85,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 5,
          verticalInterval: 1,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.black.withOpacity(0.06), strokeWidth: 1),
          getDrawingVerticalLine: (v) =>
              FlLine(color: Colors.black.withOpacity(0.04), strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.black.withOpacity(0.12)),
            bottom: BorderSide(color: Colors.black.withOpacity(0.12)),
            right: const BorderSide(color: Colors.transparent),
            top: const BorderSide(color: Colors.transparent),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 4,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(v.toStringAsFixed(0),
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.black.withOpacity(0.55))),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 1 || i > 4) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Week $i',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.black.withOpacity(0.55))),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 2.5,
            color: const Color(0xFF10B981),
            dotData: const FlDotData(show: true),
            spots: const [
              FlSpot(1, 94),
              FlSpot(2, 96),
              FlSpot(3, 92),
              FlSpot(4, 95),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------- alerts ---------------- */

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.buttonColor,
  });

  final String title;
  final String subtitle;
  final Color bg;
  final Color buttonColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.black.withOpacity(0.55))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              child: const Text('Schedule'),
            ),
          ),
        ],
      ),
    );
  }
}
