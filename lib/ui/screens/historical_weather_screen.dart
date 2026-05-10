import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:weather/data/weather_providers.dart';

// ─── Color helpers ────────────────────────────────────────────────────────────

Color _temperatureColor(num value, num min, num max) {
  if (max == min) return Colors.grey;
  final t = (value - min) / (max - min);
  if (t < 0.25) {
    return Color.lerp(const Color(0xFF1E88E5), const Color(0xFF00BCD4), t * 4)!;
  }
  if (t < 0.5) {
    return Color.lerp(
        const Color(0xFF00BCD4), const Color(0xFFFDD835), (t - 0.25) * 4)!;
  }
  if (t < 0.75) {
    return Color.lerp(
        const Color(0xFFFDD835), const Color(0xFFFF9800), (t - 0.5) * 4)!;
  }
  return Color.lerp(
      const Color(0xFFFF9800), const Color(0xFFD32F2F), (t - 0.75) * 4)!;
}

Color _precipitationColor(num value, num min, num max) {
  if (value == 0) return Colors.white10;
  if (max == min) return const Color(0xFF1976D2);
  final t = (value - min) / (max - min);
  return Color.lerp(const Color(0xFF81D4FA), const Color(0xFF0D47A1), t)!;
}

// ─── Shared chart config ──────────────────────────────────────────────────────

FlGridData _histGridData() => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 5,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: Colors.white.withAlpha(13), strokeWidth: 1),
    );

AxisTitles _histHidden() =>
    const AxisTitles(sideTitles: SideTitles(showTitles: false));

AxisTitles _histDateAxis(List<String> times) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: (times.length / 6).ceil().toDouble(),
        getTitlesWidget: (value, _) {
          final i = value.toInt();
          if (i >= times.length) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              DateFormat('MMM d').format(DateTime.parse(times[i])),
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );

AxisTitles _histValueAxis() => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, _) => Text(
          value.toInt().toString(),
          style: const TextStyle(
              color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );

// ─── Chart Models ─────────────────────────────────────────────────────────────

class ChartDataset {
  final String label;
  final List<num> values;
  final Color color;
  const ChartDataset(this.label, this.values, this.color);
}

// ─── Chart Builders ──────────────────────────────────────────────────────────

Widget buildMultiLineChart({
  required List<String> times,
  required List<ChartDataset> datasets,
}) {
  if (times.isEmpty || datasets.isEmpty) return const SizedBox();
  return LineChart(LineChartData(
    gridData: _histGridData(),
    titlesData: FlTitlesData(
      rightTitles: _histHidden(),
      topTitles: _histHidden(),
      bottomTitles: _histDateAxis(times),
      leftTitles: _histValueAxis(),
    ),
    borderData: FlBorderData(show: false),
    lineBarsData: datasets
        .map((d) => LineChartBarData(
              spots: d.values
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                  .toList(),
              isCurved: true,
              color: d.color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: d.color.withAlpha(26)),
            ))
        .toList(),
  ));
}

Widget buildBarChart(List<String> times, List<num> values, Color color) {
  if (times.isEmpty || values.isEmpty) return const SizedBox();
  return BarChart(BarChartData(
    alignment: BarChartAlignment.spaceAround,
    maxY: values.map((v) => v.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
    barTouchData: BarTouchData(enabled: false),
    titlesData: FlTitlesData(
      rightTitles: _histHidden(),
      topTitles: _histHidden(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, _) {
            final i = value.toInt();
            final interval = (times.length / 6).ceil();
            if (i % interval != 0 || i >= times.length) {
              return const SizedBox();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                DateFormat('MMM d').format(DateTime.parse(times[i])),
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
      leftTitles: _histValueAxis(),
    ),
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 10,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: Colors.white.withAlpha(13), strokeWidth: 1),
    ),
    borderData: FlBorderData(show: false),
    barGroups: values
        .asMap()
        .entries
        .map((e) => BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                  toY: e.value.toDouble(),
                  color: color,
                  width: 6,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2)))
            ]))
        .toList(),
  ));
}

Widget buildAreaChart(List<String> times, List<num> values, Color color) {
  if (times.isEmpty || values.isEmpty) return const SizedBox();
  return LineChart(LineChartData(
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 10,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: Colors.white.withAlpha(13), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      rightTitles: _histHidden(),
      topTitles: _histHidden(),
      bottomTitles: _histDateAxis(times),
      leftTitles: _histValueAxis(),
    ),
    borderData: FlBorderData(show: false),
    lineBarsData: [
      LineChartBarData(
        spots: values
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
            .toList(),
        isCurved: true,
        color: color,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [color.withAlpha(77), color.withAlpha(0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ],
  ));
}

// ─── _GraphCard ───────────────────────────────────────────────────────────────
// Wraps a chart in a tappable card that pushes a fullscreen view on tap.

class _GraphCard extends StatelessWidget {
  final String title;
  final String unit;
  final Widget child;

  const _GraphCard(
      {required this.title, required this.unit, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => Scaffold(
                    backgroundColor: const Color(0xFF131A1F),
                    appBar: AppBar(
                        backgroundColor: Colors.black,
                        elevation: 0,
                        title: Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5))),
                    body: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(20), child: child)),
                  ))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFF1F2A31),
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                Row(children: [
                  Text(unit,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11, letterSpacing: 1.0)),
                  const SizedBox(width: 8),
                  const Icon(Icons.fullscreen, color: Colors.white54, size: 16),
                ]),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}

// ─── _HeatmapCard ─────────────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  final String title;
  final String unit;
  final List<String> times;
  final List<num> values;
  final Color Function(num, num, num) getColor;
  final String Function(num) formatValue;

  const _HeatmapCard({
    required this.title,
    required this.unit,
    required this.times,
    required this.values,
    required this.getColor,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1F2A31),
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              Text(unit,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 20),
          WeatherHeatmap(
              times: times,
              values: values,
              getColor: getColor,
              formatValue: formatValue),
        ],
      ),
    );
  }
}

// ─── HistoricalWeatherScreen ──────────────────────────────────────────────────

class HistoricalWeatherScreen extends ConsumerWidget {
  final City city;
  const HistoricalWeatherScreen({super.key, required this.city});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historicalAsync = ref.watch(historicalWeatherProvider(city));
    final selectedDuration = ref.watch(selectedDurationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131A1F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HISTORICAL DATA',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            Text(city.name.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration:
                BoxDecoration(border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(4)),
            child: DropdownButton<HistoricalDuration>(
              value: selectedDuration,
              dropdownColor: const Color(0xFF1F2A31),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0),
              items: HistoricalDuration.values
                  .map((d) =>
                      DropdownMenuItem(value: d, child: Text(d.label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(selectedDurationProvider.notifier).state = value;
                }
              },
            ),
          ),
        ],
      ),
      body: historicalAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF6E8473)),
              SizedBox(height: 20),
              Text('LOADING HISTORICAL DATA...',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        error: (err, _) => _HistoricalErrorView(message: err.toString()),
        data: (data) {
          final daily = data['daily'] as Map?;
          if (daily == null) {
            return const _HistoricalErrorView(
                message: 'No historical data available');
          }
          return _HistoricalChartList(daily: daily);
        },
      ),
    );
  }
}

// ─── _HistoricalChartList ────────────────────────────────────────────────────

class _HistoricalChartList extends StatelessWidget {
  final Map daily;
  const _HistoricalChartList({required this.daily});

  List<String> _times() => List<String>.from(daily['time'] ?? []);
  List<num> _nums(String key) => List<num>.from(daily[key] ?? []);

  @override
  Widget build(BuildContext context) {
    final times = _times();
    if (times.isEmpty) return const SizedBox();

    return SingleChildScrollView(
      child: Column(
        children: [
          _HeatmapCard(
            title: 'TEMPERATURE HEATMAP',
            unit: '°C',
            times: times,
            values: _nums('temperature_2m_mean'),
            getColor: _temperatureColor,
            formatValue: (v) => '${v.round()}°',
          ),
          _HeatmapCard(
            title: 'PRECIPITATION HEATMAP',
            unit: 'mm',
            times: times,
            values: _nums('precipitation_sum'),
            getColor: _precipitationColor,
            formatValue: (v) => '${v.toStringAsFixed(1)}mm',
          ),
          _GraphCard(
            title: 'TEMPERATURE',
            unit: '°C',
            child: buildMultiLineChart(times: times, datasets: [
              ChartDataset('MAX', _nums('temperature_2m_max'), const Color(0xFFA6755B)),
              ChartDataset('MEAN', _nums('temperature_2m_mean'), const Color(0xFF9B7D5D)),
              ChartDataset('MIN', _nums('temperature_2m_min'), const Color(0xFF6B8193)),
            ]),
          ),
          _GraphCard(
            title: 'PRECIPITATION',
            unit: 'mm',
            child: buildBarChart(times, _nums('precipitation_sum'), const Color(0xFF6B8193)),
          ),
          _GraphCard(
            title: 'FEELS LIKE TEMPERATURE',
            unit: '°C',
            child: buildMultiLineChart(times: times, datasets: [
              ChartDataset('MAX', _nums('apparent_temperature_max'), const Color(0xFFA6755B)),
              ChartDataset('MEAN', _nums('apparent_temperature_mean'), const Color(0xFF9B7D5D)),
              ChartDataset('MIN', _nums('apparent_temperature_min'), const Color(0xFF6E8473)),
            ]),
          ),
          _GraphCard(
            title: 'WIND SPEED',
            unit: 'km/h',
            child: buildMultiLineChart(times: times, datasets: [
              ChartDataset('GUSTS', _nums('wind_gusts_10m_max'), const Color(0xFF7B6E7C)),
              ChartDataset('SUSTAINED', _nums('wind_speed_10m_max'), const Color(0xFF4E6373)),
            ]),
          ),
          _GraphCard(
            title: 'SOLAR RADIATION',
            unit: 'MJ/m²',
            child: buildAreaChart(
                times, _nums('shortwave_radiation_sum'), const Color(0xFFB49B6B)),
          ),
          _GraphCard(
            title: 'SUNSHINE DURATION',
            unit: 'hours',
            child: buildBarChart(
              times,
              _nums('sunshine_duration').map((v) => v / 3600).toList(),
              const Color(0xFF9B7D5D),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── _HistoricalErrorView ────────────────────────────────────────────────────

class _HistoricalErrorView extends StatelessWidget {
  final String message;
  const _HistoricalErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF9C5E5E), width: 2),
            borderRadius: BorderRadius.circular(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF9C5E5E), size: 48),
            const SizedBox(height: 16),
            const Text('ERROR',
                style: TextStyle(
                    color: Color(0xFF9C5E5E),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── WeatherHeatmap ───────────────────────────────────────────────────────────

class WeatherHeatmap extends StatelessWidget {
  final List<String> times;
  final List<num> values;
  final Color Function(num value, num min, num max) getColor;
  final String Function(num value) formatValue;

  const WeatherHeatmap({
    super.key,
    required this.times,
    required this.values,
    required this.getColor,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    if (times.isEmpty || values.isEmpty) return const SizedBox();

    final minVal = values.reduce((a, b) => a < b ? a : b).toDouble();
    final maxVal = values.reduce((a, b) => a > b ? a : b).toDouble();

    final Map<int, List<MapEntry<DateTime, num>>> monthlyData = {};
    for (int i = 0; i < times.length; i++) {
      final date = DateTime.parse(times[i]);
      monthlyData.putIfAbsent(date.month, () => []).add(MapEntry(date, values[i]));
    }
    final sortedMonths = monthlyData.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...sortedMonths.map((month) {
            final monthData = monthlyData[month]!;
            final monthName = DateFormat('MMM')
                .format(monthData.first.key)
                .toUpperCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 35,
                    child: Text(monthName,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                  ...monthData.map((entry) => Tooltip(
                        message:
                            '${DateFormat('MMM d').format(entry.key)}: ${formatValue(entry.value)}',
                        preferBelow: false,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1F2A31),
                            border: Border.all(color: const Color(0xFF6E8473))),
                        textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        child: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: getColor(entry.value, minVal, maxVal),
                            border: Border.all(
                                color: Colors.white.withAlpha(26), width: 0.5),
                          ),
                        ),
                      )),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 35),
              const Text('LESS',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              ...List.generate(
                  5,
                  (i) => Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: getColor(
                              minVal + (maxVal - minVal) * (i / 4), minVal, maxVal),
                          border: Border.all(
                              color: Colors.white.withAlpha(26), width: 0.5),
                        ),
                      )),
              const SizedBox(width: 8),
              const Text('MORE',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}