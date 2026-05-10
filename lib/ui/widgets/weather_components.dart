import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather/core/weather_mapper.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:weather/ui/screens/hourly_detail_screen.dart';

// ─── Shared chart helpers ───────────────────────────────────────────────────

FlGridData _horizontalGridOnly() => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: Colors.white10, strokeWidth: 1),
    );

AxisTitles _hidden() =>
    const AxisTitles(sideTitles: SideTitles(showTitles: false));

AxisTitles _timeAxis(List<String> labels, {int interval = 4}) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        getTitlesWidget: (value, _) {
          final i = value.toInt();
          if (i < 0 || i >= labels.length || i % interval != 0) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(labels[i],
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          );
        },
      ),
    );

AxisTitles _degreeAxis() => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        getTitlesWidget: (value, _) => Text('${value.toInt()}°',
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ),
    );

// ─── TechnicalCard ──────────────────────────────────────────────────────────

class TechnicalCard extends StatelessWidget {
  final String title;
  final Widget child;

  const TechnicalCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(102),
        border: Border.all(color: Colors.white.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF6E8473), width: 2)),
            ),
            child: Row(children: [
              Container(
                  width: 4,
                  height: 14,
                  color: const Color(0xFF6E8473),
                  margin: const EdgeInsets.only(right: 8)),
              Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── TechnicalDataRow ───────────────────────────────────────────────────────

class TechnicalDataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const TechnicalDataRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF6E8473), size: 16),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

// ─── HourlyForecastList ─────────────────────────────────────────────────────

class HourlyForecastList extends StatelessWidget {
  final Map hourly;
  final Map current;
  final int startHour;
  final int itemCount;
  final double height;
  final String cityName; // ← ADD THIS

  const HourlyForecastList({
    super.key,
    required this.hourly,
    required this.current,
    this.startHour = 0,
    this.itemCount = 24,
    this.height = 127,
    this.cityName = '',
  });

  @override
  Widget build(BuildContext context) {
    final times = hourly['time'] as List;
    final now = DateTime.parse(current['time']);

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white10),
        itemBuilder: (context, index) {
          final targetIndex = startHour + index;
          if (targetIndex >= times.length) return const SizedBox.shrink();

          final time = DateTime.parse(times[targetIndex]);
          final hCode = hourly['weather_code'][targetIndex];
          final isDay = hourly['is_day'][targetIndex] == 1;
          final temp = hourly['temperature_2m'][targetIndex];
          
          final isNow = startHour == 0 && index == 0 && targetIndex == now.hour;
          final timeLabel = isNow ? 'NOW' : DateFormat('HH:mm').format(time);

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HourlyDetailScreen(
                    hourly: Map<String, dynamic>.from(hourly),
                    index: targetIndex,
                    cityName: cityName,
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(timeLabel,
                      style: TextStyle(
                          color: isNow ? const Color(0xFF6E8473) : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  BoxedIcon(WeatherMapper.getIcon(hCode, isDay),
                      color: Colors.white, size: 28),
                  const SizedBox(height: 8),
                  Text('${temp.round()}°',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w300)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── HourlyChartsSection ────────────────────────────────────────────────────

class HourlyChartsSection extends StatelessWidget {
  final Map hourly;
  final Map current;

  const HourlyChartsSection(
      {super.key, required this.hourly, required this.current});

  @override
  Widget build(BuildContext context) {
    final times = List<String>.from(hourly['time']);
    final now = DateTime.parse(current['time']);

    int startIdx = times.indexWhere((t) {
      final dt = DateTime.parse(t);
      return dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day &&
          dt.hour == now.hour;
    });
    if (startIdx < 0) startIdx = 0;

    final endIdx = (startIdx + 24).clamp(0, times.length);
    final timeLabels = <String>[];
    final temps = <FlSpot>[];
    final appTemps = <FlSpot>[];
    final precip = <BarChartGroupData>[];

    for (int i = 0; i < endIdx - startIdx; i++) {
      final index = startIdx + i;
      timeLabels.add(DateFormat('HH:mm').format(DateTime.parse(times[index])));
      temps.add(FlSpot(
          i.toDouble(), (hourly['temperature_2m'][index] as num).toDouble()));
      appTemps.add(FlSpot(i.toDouble(),
          (hourly['apparent_temperature'][index] as num).toDouble()));
      precip.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: (hourly['precipitation'][index] as num).toDouble(),
          color: const Color(0xFF6E8473),
          width: 6,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        )
      ]));
    }

    if (timeLabels.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      TechnicalCard(
        title: '24H TEMPERATURE TREND (°C)',
        child: SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            gridData: _horizontalGridOnly(),
            titlesData: FlTitlesData(
              bottomTitles: _timeAxis(timeLabels),
              leftTitles: _hidden(),
              topTitles: _hidden(),
              rightTitles: _degreeAxis(),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: temps,
                color: const Color(0xFFA6755B),
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true, color: const Color(0xFFA6755B).withAlpha(26)),
              ),
              LineChartBarData(
                spots: appTemps,
                color: const Color(0xFF9B7D5D),
                barWidth: 2,
                dashArray: const [5, 5],
                dotData: const FlDotData(show: false),
              ),
            ],
          )),
        ),
      ),
      TechnicalCard(
        title: '24H RAINFALL (MM)',
        child: SizedBox(
          height: 150,
          child: BarChart(BarChartData(
            gridData: _horizontalGridOnly(),
            titlesData: FlTitlesData(
              bottomTitles: _timeAxis(timeLabels),
              leftTitles: _hidden(),
              topTitles: _hidden(),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, _) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(value.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: precip,
          )),
        ),
      ),
    ]);
  }
}

// ─── WeatherTelemetryCluster ─────────────────────────────────────────────────

class WeatherTelemetryCluster extends StatelessWidget {
  final double aqi;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime now;
  final double windDirection;
  final double windSpeed;

  const WeatherTelemetryCluster({
    super.key,
    required this.aqi,
    required this.sunrise,
    required this.sunset,
    required this.now,
    required this.windDirection,
    required this.windSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final aqiColor = _aqiColor(aqi);
    final sunPercent =
        _sunProgressPercent(sunrise: sunrise, sunset: sunset, now: now);
    final windLabel = _windDirectionLabel(windDirection);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.black.withAlpha(77),
          border: Border.all(color: Colors.white12)),
      child: Row(children: [
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${aqi.round()}',
                style: TextStyle(
                    color: aqiColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_aqiLabel(aqi),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: aqiColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ]),
        ),
        Container(width: 1, height: 28, color: Colors.white12),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
                width: 30,
                height: 15,
                child:
                    CustomPaint(painter: _SunArcPainter(percent: sunPercent))),
            const SizedBox(height: 6),
            const Text('SOLAR',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ]),
        ),
        Container(width: 1, height: 28, color: Colors.white12),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Transform.rotate(
                angle: windDirection * pi / 180,
                child: const Icon(Icons.navigation,
                    color: Color(0xFF6E8473), size: 18)),
            const SizedBox(height: 4),
            Text('${windSpeed.round()}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(windLabel,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ]),
        ),
      ]),
    );
  }

  static Color _aqiColor(double v) {
    if (v > 150) return const Color(0xFF9C5E5E);
    if (v > 100) return const Color(0xFFA97A55);
    if (v > 50) return const Color(0xFFB49B6B);
    return const Color(0xFF7A8E78);
  }

  static String _aqiLabel(double v) {
    if (v > 150) return 'POOR';
    if (v > 100) return 'UNHEALTHY';
    if (v > 50) return 'MODERATE';
    return 'GOOD';
  }

  static double _sunProgressPercent(
      {required DateTime sunrise,
      required DateTime sunset,
      required DateTime now}) {
    if (now.isBefore(sunrise)) return 0;
    if (now.isAfter(sunset)) return 1;
    final total = sunset.difference(sunrise).inMinutes;
    final passed = now.difference(sunrise).inMinutes;
    return total == 0 ? 0.0 : (passed / total).clamp(0.0, 1.0);
  }

  static String _windDirectionLabel(double direction) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((direction + 22.5) % 360 / 45).floor() % 8];
  }
}

// ─── _SunArcPainter ─────────────────────────────────────────────────────────

class _SunArcPainter extends CustomPainter {
  final double percent;
  const _SunArcPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);

    canvas.drawArc(
        rect,
        pi,
        pi,
        false,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    canvas.drawArc(
        rect,
        pi,
        pi * percent,
        false,
        Paint()
          ..color = const Color(0xFF9B7D5D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    final angle = pi + (pi * percent);
    final radius = size.width / 2;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2 + radius * cos(angle),
              size.height + radius * sin(angle)),
          width: 6,
          height: 6),
      Paint()..color = const Color(0xFF9B7D5D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}
