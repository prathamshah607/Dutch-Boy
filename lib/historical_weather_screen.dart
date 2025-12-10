import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'riverpod_interface.dart';

class HistoricalWeatherScreen extends ConsumerWidget {
  final City city;

  const HistoricalWeatherScreen({super.key, required this.city});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historicalAsync = ref.watch(historicalWeatherProvider(city));
    final selectedDuration = ref.watch(selectedDurationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HISTORICAL DATA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              city.name.toUpperCase(),
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          // Duration Dropdown
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<HistoricalDuration>(
              value: selectedDuration,
              dropdownColor: const Color(0xFF1D1E33),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
              items: HistoricalDuration.values.map((duration) {
                return DropdownMenuItem(
                  value: duration,
                  child: Text(duration.label),
                );
              }).toList(),
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
        data: (data) {
          final daily = data['daily'] as Map<String, dynamic>?;
          if (daily == null) {
            return _buildError('No historical data available');
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildTemperatureHeatmap(daily),
                _buildPrecipitationHeatmap(daily),
                _buildTemperatureGraph(daily),
                _buildPrecipitationGraph(daily),
                _buildApparentTempGraph(daily),
                _buildWindSpeedGraph(daily),
                _buildSolarRadiationGraph(daily),
                _buildSunshineDurationGraph(daily),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.cyanAccent),
              const SizedBox(height: 20),
              Text(
                'LOADING HISTORICAL DATA...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        error: (err, _) => _buildError(err.toString()),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'ERROR',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TEMPERATURE GRAPH ====================
  Widget _buildTemperatureGraph(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final maxTemps = List<num>.from(daily['temperature_2m_max'] ?? []);
    final minTemps = List<num>.from(daily['temperature_2m_min'] ?? []);
    final meanTemps = List<num>.from(daily['temperature_2m_mean'] ?? []);

    if (times.isEmpty) return const SizedBox();

    return _buildGraphCard(
      title: 'TEMPERATURE',
      unit: '°C',
      child: _buildMultiLineChart(
        times: times,
        datasets: [
          ChartDataset('MAX', maxTemps, Colors.red.shade400),
          ChartDataset('MEAN', meanTemps, Colors.orange.shade300),
          ChartDataset('MIN', minTemps, Colors.blue.shade400),
        ],
      ),
    );
  }

  // ==================== PRECIPITATION GRAPH ====================
  Widget _buildPrecipitationGraph(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final precip = List<num>.from(daily['precipitation_sum'] ?? []);

    if (times.isEmpty) return const SizedBox();

    return _buildGraphCard(
      title: 'PRECIPITATION',
      unit: 'mm',
      child: _buildBarChart(times, precip, Colors.blue.shade300),
    );
  }

  // ==================== APPARENT TEMPERATURE GRAPH ====================
  Widget _buildApparentTempGraph(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final maxApparent = List<num>.from(daily['apparent_temperature_max'] ?? []);
    final minApparent = List<num>.from(daily['apparent_temperature_min'] ?? []);
    final meanApparent =
        List<num>.from(daily['apparent_temperature_mean'] ?? []);

    if (times.isEmpty) return const SizedBox();

    return _buildGraphCard(
      title: 'FEELS LIKE TEMPERATURE',
      unit: '°C',
      child: _buildMultiLineChart(
        times: times,
        datasets: [
          ChartDataset('MAX', maxApparent, Colors.deepOrange.shade300),
          ChartDataset('MEAN', meanApparent, Colors.amber.shade300),
          ChartDataset('MIN', minApparent, Colors.cyan.shade300),
        ],
      ),
    );
  }

  // ==================== WIND SPEED GRAPH ====================
  Widget _buildWindSpeedGraph(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final windMax = List<num>.from(daily['wind_speed_10m_max'] ?? []);
    final gustsMax = List<num>.from(daily['wind_gusts_10m_max'] ?? []);

    if (times.isEmpty) return const SizedBox();

    return _buildGraphCard(
      title: 'WIND SPEED',
      unit: 'km/h',
      child: _buildMultiLineChart(
        times: times,
        datasets: [
          ChartDataset('GUSTS', gustsMax, Colors.purple.shade300),
          ChartDataset('SUSTAINED', windMax, Colors.indigo.shade300),
        ],
      ),
    );
  }

  // ==================== SOLAR RADIATION GRAPH ====================
  Widget _buildSolarRadiationGraph(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final radiation = List<num>.from(daily['shortwave_radiation_sum'] ?? []);

    if (times.isEmpty) return const SizedBox();

    return _buildGraphCard(
      title: 'SOLAR RADIATION',
      unit: 'MJ/m²',
      child: _buildAreaChart(times, radiation, Colors.yellow.shade600),
    );
  }

  // ==================== SUNSHINE DURATION GRAPH ====================
  Widget _buildSunshineDurationGraph(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final sunshine = List<num>.from(daily['sunshine_duration'] ?? []);

    // Convert seconds to hours
    final sunshineHours = sunshine.map((s) => s / 3600).toList();

    if (times.isEmpty) return const SizedBox();

    return _buildGraphCard(
      title: 'SUNSHINE DURATION',
      unit: 'hours',
      child: _buildBarChart(times, sunshineHours, Colors.amber.shade400),
    );
  }

  // ==================== GRAPH CARD WRAPPER ====================
// ==================== GRAPH CARD WRAPPER ====================
  Widget _buildGraphCard({
    required String title,
    required String unit,
    required Widget child,
  }) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: const Color(0xFF0A0E21),
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  title: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            border: Border.all(color: Colors.white12, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        unit,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.fullscreen,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(height: 200, child: child),
            ],
          ),
        ),
      ),
    );
  }

// ==================== TEMPERATURE HEATMAP ====================
  Widget _buildTemperatureHeatmap(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final meanTemps = List<num>.from(daily['temperature_2m_mean'] ?? []);

    if (times.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        border: Border.all(color: Colors.white12, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TEMPERATURE HEATMAP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Text(
                '°C',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // NO SizedBox constraint - let it expand naturally
          WeatherHeatmap(
            times: times,
            values: meanTemps,
            getColor: _getTemperatureColor,
            formatValue: (val) => '${val.round()}°',
          ),
        ],
      ),
    );
  }

// ==================== PRECIPITATION HEATMAP ====================
  Widget _buildPrecipitationHeatmap(Map<String, dynamic> daily) {
    final times = List<String>.from(daily['time'] ?? []);
    final precip = List<num>.from(daily['precipitation_sum'] ?? []);

    if (times.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        border: Border.all(color: Colors.white12, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PRECIPITATION HEATMAP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Text(
                'mm',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // NO SizedBox constraint - let it expand naturally
          WeatherHeatmap(
            times: times,
            values: precip,
            getColor: _getPrecipitationColor,
            formatValue: (val) => '${val.toStringAsFixed(1)}mm',
          ),
        ],
      ),
    );
  }

// ==================== COLOR MAPPERS ====================
  Color _getTemperatureColor(num value, num min, num max) {
    if (max == min) return Colors.grey;

    final normalized = (value - min) / (max - min);

    // Cold to Hot: Blue -> Cyan -> Yellow -> Orange -> Red
    if (normalized < 0.25) {
      return Color.lerp(
        const Color(0xFF1E88E5), // Cold Blue
        const Color(0xFF00BCD4), // Cyan
        normalized * 4,
      )!;
    } else if (normalized < 0.5) {
      return Color.lerp(
        const Color(0xFF00BCD4), // Cyan
        const Color(0xFFFDD835), // Yellow
        (normalized - 0.25) * 4,
      )!;
    } else if (normalized < 0.75) {
      return Color.lerp(
        const Color(0xFFFDD835), // Yellow
        const Color(0xFFFF9800), // Orange
        (normalized - 0.5) * 4,
      )!;
    } else {
      return Color.lerp(
        const Color(0xFFFF9800), // Orange
        const Color(0xFFD32F2F), // Hot Red
        (normalized - 0.75) * 4,
      )!;
    }
  }

  Color _getPrecipitationColor(num value, num min, num max) {
    if (value == 0) return Colors.white10;
    if (max == min) return const Color(0xFF1976D2);

    final normalized = (value - min) / (max - min);

    // Dry to Wet: Light Blue -> Deep Blue
    return Color.lerp(
      const Color(0xFF81D4FA), // Light Blue
      const Color(0xFF0D47A1), // Deep Blue
      normalized,
    )!;
  }

  // ==================== MULTI-LINE CHART ====================
  Widget _buildMultiLineChart({
    required List<String> times,
    required List<ChartDataset> datasets,
  }) {
    if (times.isEmpty || datasets.isEmpty) return const SizedBox();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (times.length / 6).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= times.length) return const SizedBox();
                final date = DateTime.parse(times[value.toInt()]);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('MMM d').format(date),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: datasets.map((dataset) {
          return LineChartBarData(
            spots: dataset.values.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.toDouble());
            }).toList(),
            isCurved: true,
            color: dataset.color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: dataset.color.withOpacity(0.1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== BAR CHART ====================
  // ==================== BAR CHART (FIXED) ====================
  Widget _buildBarChart(List<String> times, List<num> values, Color color) {
    if (times.isEmpty || values.isEmpty) return const SizedBox();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (values.isEmpty
                ? 10.0
                : values
                    .map((v) => v.toDouble())
                    .reduce((a, b) => a > b ? a : b)) *
            1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              // REMOVE interval parameter for bar charts
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                // Manual filtering: show ~6 labels
                final interval = (times.length / 6).ceil();
                if (index % interval != 0 || index >= times.length) {
                  return const SizedBox();
                }

                final date = DateTime.parse(times[index]);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('MMM d').format(date),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: values.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: color,
                width: 6,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==================== AREA CHART ====================
  Widget _buildAreaChart(List<String> times, List<num> values, Color color) {
    if (times.isEmpty || values.isEmpty) return const SizedBox();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (times.length / 6).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= times.length) return const SizedBox();
                final date = DateTime.parse(times[value.toInt()]);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('MMM d').format(date),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: values.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.toDouble());
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== HELPER CLASS ====================
class ChartDataset {
  final String label;
  final List<num> values;
  final Color color;

  ChartDataset(this.label, this.values, this.color);
}

// ==================== WEATHER HEATMAP WIDGET ====================
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

    final minValue = values.reduce((a, b) => a < b ? a : b).toDouble();
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();

    // Group by month
    final Map<int, List<MapEntry<DateTime, num>>> monthlyData = {};

    for (int i = 0; i < times.length; i++) {
      final date = DateTime.parse(times[i]);
      final month = date.month;

      if (!monthlyData.containsKey(month)) {
        monthlyData[month] = [];
      }
      monthlyData[month]!.add(MapEntry(date, values[i]));
    }

    // Sort months
    final sortedMonths = monthlyData.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Important: don't expand unnecessarily
        children: [
          // Month rows
          ...sortedMonths.map((month) {
            final monthData = monthlyData[month]!;
            final monthName =
                DateFormat('MMM').format(monthData.first.key).toUpperCase();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month label
                  SizedBox(
                    width: 35,
                    child: Text(
                      monthName,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Day cells
                  ...monthData.map((entry) {
                    final date = entry.key;
                    final value = entry.value;
                    final color = getColor(value, minValue, maxValue);

                    return Tooltip(
                      message:
                          '${DateFormat('MMM d').format(date)}: ${formatValue(value)}',
                      preferBelow: false,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        border: Border.all(color: const Color(0xFF00D9FF)),
                      ),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      child: Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 35),
              const Text(
                'LESS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (index) {
                final value = minValue + (maxValue - minValue) * (index / 4);
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: getColor(value, minValue, maxValue),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              const Text(
                'MORE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
