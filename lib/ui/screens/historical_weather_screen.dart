import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:weather/data/weather_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// COLOR HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

Color _tempColor(num value) {
  if (value >= 40) return const Color(0xFFFF3B3B);
  if (value >= 35) return const Color(0xFFFF6B35);
  if (value >= 30) return const Color(0xFFA6755B);
  if (value >= 20) return Colors.white;
  if (value >= 10) return const Color(0xFF7E97A8);
  return const Color(0xFF5B8FA6);
}

Color _tempGradient(num value, num min, num max) {
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

Color _precipGradient(num value, num min, num max) {
  if (value == 0) return Colors.white10;
  if (max == min) return const Color(0xFF1976D2);
  final t = (value - min) / (max - min);
  return Color.lerp(const Color(0xFF81D4FA), const Color(0xFF0D47A1), t)!;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED CHART HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

FlGridData _gridH(double interval) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: Colors.white.withAlpha(18), strokeWidth: 0.8),
    );

AxisTitles _hidden() =>
    const AxisTitles(sideTitles: SideTitles(showTitles: false));

AxisTitles _dateAxis(List<String> times) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: (times.length / 7).ceilToDouble().clamp(1, 9999),
        getTitlesWidget: (value, _) {
          final i = value.toInt();
          if (i < 0 || i >= times.length) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
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
    );

AxisTitles _valueAxis(String unit, {double reservedSize = 44}) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reservedSize,
        getTitlesWidget: (value, _) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            '${value.toInt()}$unit',
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );

FlTitlesData _titles(List<String> times, String unit) => FlTitlesData(
      rightTitles: _hidden(),
      topTitles: _hidden(),
      bottomTitles: _dateAxis(times),
      leftTitles: _valueAxis(unit),
    );

LineTouchData _lineTouchData(List<String> times) => LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => const Color(0xFF1F2A31),
        getTooltipItems: (spots) => spots.map((spot) {
          final i = spot.x.toInt();
          final date = (i >= 0 && i < times.length)
              ? DateFormat('MMM d').format(DateTime.parse(times[i]))
              : '';
          return LineTooltipItem(
            '$date\n${spot.y.toStringAsFixed(1)}',
            const TextStyle(color: Colors.white, fontSize: 10),
          );
        }).toList(),
      ),
    );

BarTouchData _barTouchData(List<String> times) => BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => const Color(0xFF1F2A31),
        getTooltipItem: (group, _, rod, __) {
          final i = group.x;
          final date = (i >= 0 && i < times.length)
              ? DateFormat('MMM d').format(DateTime.parse(times[i]))
              : '';
          return BarTooltipItem(
            '$date\n${rod.toY.toStringAsFixed(1)}',
            const TextStyle(color: Colors.white, fontSize: 10),
          );
        },
      ),
    );

List<FlSpot> _spots(List<num> values) => values
    .asMap()
    .entries
    .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
    .toList();

double _safeMin(List<num> values, {double fallback = 0}) {
  if (values.isEmpty) return fallback;
  return values.fold(values[0].toDouble(),
      (prev, e) => e.toDouble() < prev ? e.toDouble() : prev);
}

double _safeMax(List<num> values, {double fallback = 10}) {
  if (values.isEmpty) return fallback;
  return values.fold(values[0].toDouble(),
      (prev, e) => e.toDouble() > prev ? e.toDouble() : prev);
}
// ═══════════════════════════════════════════════════════════════════════════════
// CHART WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── 1. Temperature Band ──────────────────────────────────────────────────────
// Shaded region between min/max, mean line on top — meteorological standard

Widget buildTempBandChart({
  required List<String> times,
  required List<num> maxTemps,
  required List<num> minTemps,
  required List<num> meanTemps,
  required String unit,
}) {
  if (times.isEmpty) return const SizedBox();
  final minY = (_safeMin(minTemps) - 2).floorToDouble();
  final maxY = (_safeMax(maxTemps) + 2).ceilToDouble();
  final interval = ((maxY - minY) / 6).ceilToDouble().clamp(1.0, 9999.0);

  return LineChart(LineChartData(
    minY: minY,
    maxY: maxY,
    gridData: _gridH(interval),
    titlesData: _titles(times, unit),
    borderData: FlBorderData(show: false),
    lineTouchData: _lineTouchData(times),
    lineBarsData: [
      // Band: max line (top boundary)
      LineChartBarData(
        spots: _spots(maxTemps),
        isCurved: true,
        color: const Color(0xFFA6755B),
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          spotsLine: const BarAreaSpotsLine(show: false),
          // Shaded band between max and min
          color: const Color(0xFFA6755B).withAlpha(40),
          cutOffY: 0,
          applyCutOffY: false,
        ),
      ),
      // Mean line (most important — show prominently)
      LineChartBarData(
        spots: _spots(meanTemps),
        isCurved: true,
        color: Colors.white,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
      // Min line (bottom boundary)
      LineChartBarData(
        spots: _spots(minTemps),
        isCurved: true,
        color: const Color(0xFF5B8FA6),
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    ],
  ));
}

// ─── 2. Stacked Precipitation Bar ────────────────────────────────────────────
// Rain (blue) + Snowfall (white) stacked — shows composition, not just total

Widget buildPrecipStackedChart({
  required List<String> times,
  required List<num> rain,
  required List<num> snowfall,
}) {
  if (times.isEmpty) return const SizedBox();
  final combined = List.generate(
      rain.length, (i) => rain[i].toDouble() + snowfall[i].toDouble());
  final maxY = (_safeMax(combined) * 1.2).clamp(1.0, 9999.0);

  return BarChart(BarChartData(
    maxY: maxY,
    alignment: BarChartAlignment.spaceAround,
    barTouchData: _barTouchData(times),
    titlesData: _titles(times, 'mm'),
    gridData: _gridH(maxY / 5),
    borderData: FlBorderData(show: false),
    barGroups: List.generate(times.length, (i) {
      final r = rain[i].toDouble();
      final s = snowfall[i].toDouble();
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: r + s,
          color: Colors.transparent,
          width: times.length > 90 ? 2 : 5,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2), topRight: Radius.circular(2)),
          rodStackItems: [
            BarChartRodStackItem(0, r, const Color(0xFF5B8FA6)),
            BarChartRodStackItem(r, r + s, Colors.white70),
          ],
        ),
      ]);
    }),
  ));
}

// ─── 3. Wind: gust-wind gap shaded ───────────────────────────────────────────

Widget buildWindChart({
  required List<String> times,
  required List<num> windMax,
  required List<num> gusts,
}) {
  if (times.isEmpty) return const SizedBox();
  final minY = 0.0;
  final maxY = (_safeMax(gusts) * 1.1).ceilToDouble();
  final interval = (maxY / 5).ceilToDouble().clamp(1.0, 9999.0);

  return LineChart(LineChartData(
    minY: minY,
    maxY: maxY,
    gridData: _gridH(interval),
    titlesData: _titles(times, ' km/h'),
    borderData: FlBorderData(show: false),
    lineTouchData: _lineTouchData(times),
    lineBarsData: [
      // Gusts — top line, shaded above wind
      LineChartBarData(
        spots: _spots(gusts),
        isCurved: true,
        color: const Color(0xFF9B7D5D),
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFF9B7D5D).withAlpha(30),
        ),
      ),
      // Sustained wind — solid line
      LineChartBarData(
        spots: _spots(windMax),
        isCurved: true,
        color: const Color(0xFF6E8473),
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    ],
  ));
}

// ─── 4. Area Chart (solar, ET0, precip hours) ─────────────────────────────────

Widget buildAreaChart({
  required List<String> times,
  required List<num> values,
  required Color color,
  required String unit,
  double gridInterval = 10,
}) {
  if (times.isEmpty) return const SizedBox();
  final maxY = (_safeMax(values) * 1.15).ceilToDouble().clamp(1.0, 9999.0);
  final interval = (maxY / 5).ceilToDouble().clamp(1.0, 9999.0);

  return LineChart(LineChartData(
    minY: 0,
    maxY: maxY,
    gridData: _gridH(interval),
    titlesData: _titles(times, unit),
    borderData: FlBorderData(show: false),
    lineTouchData: _lineTouchData(times),
    lineBarsData: [
      LineChartBarData(
        spots: _spots(values),
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [color.withAlpha(80), color.withAlpha(0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ],
  ));
}

// ─── 5. Simple bar chart ──────────────────────────────────────────────────────

Widget buildBarChart({
  required List<String> times,
  required List<num> values,
  required Color color,
  required String unit,
}) {
  if (times.isEmpty) return const SizedBox();
  final maxY = (_safeMax(values) * 1.2).clamp(1.0, 9999.0);

  return BarChart(BarChartData(
    maxY: maxY,
    alignment: BarChartAlignment.spaceAround,
    barTouchData: _barTouchData(times),
    titlesData: _titles(times, unit),
    gridData: _gridH(maxY / 5),
    borderData: FlBorderData(show: false),
    barGroups: values
        .asMap()
        .entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  color: color,
                  width: times.length > 90 ? 2 : 5,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2)),
                ),
              ],
            ))
        .toList(),
  ));
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHART CARD WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final Widget chart;
  final List<_LegendItem>? legend;

  const _ChartCard({
    required this.title,
    required this.unit,
    required this.chart,
    this.legend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1217),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 3, height: 14, color: const Color(0xFF6E8473)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ]),
              Text(unit,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10, letterSpacing: 1.0)),
            ],
          ),
          if (legend != null) ...[
            const SizedBox(height: 8),
            Row(
              children: legend!
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 16, height: 2, color: l.color),
                          const SizedBox(width: 5),
                          Text(l.label,
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8)),
                        ]),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEATMAP (kept, improved)
// ═══════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF0D1217),
          border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 3, height: 14, color: const Color(0xFF6E8473)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ]),
              Text(unit,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
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

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class HistoricalWeatherScreen extends ConsumerStatefulWidget {
  final City city;
  const HistoricalWeatherScreen({super.key, required this.city});

  @override
  ConsumerState<HistoricalWeatherScreen> createState() =>
      _HistoricalWeatherScreenState();
}

class _HistoricalWeatherScreenState
    extends ConsumerState<HistoricalWeatherScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historicalAsync = ref.watch(historicalWeatherProvider(widget.city));
    final selectedDuration = ref.watch(selectedDurationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1217),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: Column(children: [
            // ── HEADER ─────────────────────────────────────────────────────
            _HistoricalHeader(
              city: widget.city,
              selectedDuration: selectedDuration,
              onDurationChanged: (d) {
                if (d != null) {
                  ref.read(selectedDurationProvider.notifier).state = d;
                }
              },
            ),

            // ── TAB BAR ────────────────────────────────────────────────────
            Container(
              color: Colors.black,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6E8473),
                indicatorWeight: 2,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2),
                tabs: const [
                  Tab(text: 'TABLE'),
                  Tab(text: 'GRAPHS'),
                ],
              ),
            ),

            // ── TAB VIEWS ──────────────────────────────────────────────────
            Expanded(
              child: historicalAsync.when(
                loading: () => const Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6E8473)),
                    SizedBox(height: 20),
                    Text('FETCHING HISTORICAL DATA...',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800)),
                  ],
                )),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (data) {
                  final daily = data['daily'] as Map?;
                  if (daily == null) {
                    return const _ErrorView(
                        message: 'No historical data available');
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _HistoricalTable(daily: daily),
                      _HistoricalGraphs(daily: daily),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoricalHeader extends StatelessWidget {
  final City city;
  final HistoricalDuration selectedDuration;
  final ValueChanged<HistoricalDuration?> onDurationChanged;

  const _HistoricalHeader({
    required this.city,
    required this.selectedDuration,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
          color: Colors.black,
          border:
              Border(bottom: BorderSide(color: Color(0xFF6E8473), width: 1))),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        Container(width: 3, height: 16, color: const Color(0xFF6E8473)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(city.name.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const Text('HISTORICAL WEATHER',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 9, letterSpacing: 1.5)),
            ],
          ),
        ),
        // Duration selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF6E8473)),
            color: const Color(0xFF6E8473).withAlpha(20),
          ),
          child: DropdownButton<HistoricalDuration>(
            value: selectedDuration,
            dropdownColor: const Color(0xFF111A20),
            underline: const SizedBox(),
            icon: const Icon(Icons.expand_more,
                color: Color(0xFF6E8473), size: 16),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1),
            items: HistoricalDuration.values
                .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                .toList(),
            onChanged: onDurationChanged,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1: DATA TABLE
// ═══════════════════════════════════════════════════════════════════════════════

// All 19 fields from the historical API
const _kHistCols = [
  ('time', 'DATE', '', 90.0),
  ('weather_code', 'COND', '', 110.0),
  ('temperature_2m_max', 'MAX', '°', 64.0),
  ('temperature_2m_min', 'MIN', '°', 64.0),
  ('temperature_2m_mean', 'MEAN', '°', 64.0),
  ('apparent_temperature_max', 'FEELS MAX', '°', 72.0),
  ('apparent_temperature_min', 'FEELS MIN', '°', 72.0),
  ('apparent_temperature_mean', 'FEELS MEAN', '°', 80.0),
  ('precipitation_sum', 'PRECIP', 'mm', 64.0),
  ('rain_sum', 'RAIN', 'mm', 64.0),
  ('snowfall_sum', 'SNOWFALL', 'cm', 70.0),
  ('precipitation_hours', 'PRECIP HRS', 'h', 78.0),
  ('wind_speed_10m_max', 'WIND MAX', 'km/h', 74.0),
  ('wind_gusts_10m_max', 'GUSTS MAX', 'km/h', 74.0),
  ('wind_direction_10m_dominant', 'WIND DIR', '°', 66.0),
  ('shortwave_radiation_sum', 'SOLAR RAD', 'MJ/m²', 78.0),
  ('et0_fao_evapotranspiration', 'ET0', 'mm', 60.0),
  ('sunrise', 'SUNRISE', '', 60.0),
  ('sunset', 'SUNSET', '', 60.0),
  ('sunshine_duration', 'SUNSHINE', 'h', 72.0),
];

class _HistoricalTable extends StatelessWidget {
  final Map daily;
  const _HistoricalTable({required this.daily});

  List<String> _times() => List<String>.from(daily['time'] ?? []);

  @override
  Widget build(BuildContext context) {
    final times = _times();
    if (times.isEmpty) return const SizedBox();

    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final totalDataWidth = _kHistCols.fold(0.0, (s, c) => s + c.$4);
      // Scale factor: stretch to fill screen if content is narrower
      final scale = (screenWidth / totalDataWidth).clamp(1.0, 2.0);

      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: screenWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Container(
                  color: Colors.black,
                  child: Row(
                    children: _kHistCols
                        .map((c) => _TCell(
                              text: c.$3.isNotEmpty ? '${c.$2}\n${c.$3}' : c.$2,
                              width: c.$4 * scale,
                              isHeader: true,
                            ))
                        .toList(),
                  ),
                ),
                Container(height: 1, color: const Color(0xFF6E8473)),
                // Data rows
                ...times.asMap().entries.map((entry) {
                  final i = entry.key;
                  return Container(
                    decoration: BoxDecoration(
                      color: i.isEven
                          ? Colors.white.withAlpha(4)
                          : Colors.transparent,
                      border: const Border(
                          bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: _kHistCols.map((c) {
                        final val = _getCellValue(daily, c.$1, i);
                        final display = _formatHistValue(c.$1, val);
                        final color = _colorHistValue(c.$1, val);
                        return _TCell(
                          text: display,
                          width: c.$4 * scale,
                          color: color,
                        );
                      }).toList(),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _TCell extends StatelessWidget {
  final String text;
  final double width;
  final bool isHeader;
  final Color? color;

  const _TCell({
    required this.text,
    required this.width,
    this.isHeader = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white10))),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.right : TextAlign.right,
        style: TextStyle(
          color: isHeader ? const Color(0xFF6E8473) : (color ?? Colors.white70),
          fontSize: isHeader ? 19 : 20,
          fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
          fontFamily: isHeader ? null : 'monospace',
          letterSpacing: isHeader ? 0.8 : 0.2,
          height: 1.3,
        ),
      ),
    );
  }
}

dynamic _getCellValue(Map daily, String key, int i) {
  if (key == 'time') {
    final t = daily['time'];
    return (t is List && i < t.length) ? t[i] : null;
  }
  final list = daily[key];
  if (list == null || i >= (list as List).length) return null;
  return list[i];
}

String _formatHistValue(String key, dynamic value) {
  if (value == null) return '—';
  try {
    if (key == 'time') {
      return DateFormat('EEE dd MMM')
          .format(DateTime.parse(value as String))
          .toUpperCase();
    }
    if (key == 'weather_code') {
      // Reuse WMO code mapping
      const wmo = {
        0: 'CLEAR',
        1: 'MAINLY CLEAR',
        2: 'PARTLY CLOUDY',
        3: 'OVERCAST',
        45: 'FOG',
        48: 'RIME FOG',
        51: 'LT DRIZZLE',
        53: 'DRIZZLE',
        55: 'HV DRIZZLE',
        61: 'LT RAIN',
        63: 'RAIN',
        65: 'HV RAIN',
        71: 'LT SNOW',
        73: 'SNOW',
        75: 'HV SNOW',
        77: 'SNOW GRAINS',
        80: 'LT SHOWER',
        81: 'SHOWER',
        82: 'HV SHOWER',
        85: 'SNOW SHOWER',
        86: 'HV SNOW SHWR',
        95: 'THUNDERSTORM',
        96: 'TS + HAIL',
        99: 'TS + HV HAIL',
      };
      return wmo[value as int] ?? 'CODE $value';
    }
    if (key == 'sunrise' || key == 'sunset') {
      return DateFormat('HH:mm').format(DateTime.parse(value as String));
    }
    if (key == 'sunshine_duration') {
      return ((value as num) / 3600).toStringAsFixed(1);
    }
    if (key == 'wind_direction_10m_dominant') {
      const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
      return dirs[((value as num).toDouble() + 22.5) ~/ 45 % 8];
    }
    if (value is num) {
      return value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1);
    }
    return value.toString();
  } catch (_) {
    return '—';
  }
}

Color _colorHistValue(String key, dynamic value) {
  if (value == null) return Colors.white24;
  if (key == 'time') return const Color(0xFF6E8473);
  if (key.contains('temperature') || key.contains('apparent')) {
    final v = (value as num).toDouble();
    return _tempColor(v);
  }
  if (key == 'precipitation_sum' || key == 'rain_sum') {
    final v = (value as num).toDouble();
    if (v > 20) return const Color(0xFF3B6BFF);
    if (v > 5) return Colors.blueAccent;
    if (v > 0) return const Color(0xFF7E97A8);
    return Colors.white24;
  }
  if (key == 'wind_speed_10m_max' || key == 'wind_gusts_10m_max') {
    final v = (value as num).toDouble();
    if (v > 60) return const Color(0xFFFF3B3B);
    if (v > 40) return const Color(0xFFFF6B35);
    if (v > 20) return const Color(0xFFA6755B);
    return Colors.white70;
  }
  if (key == 'shortwave_radiation_sum') {
    final v = (value as num).toDouble();
    if (v > 20) return const Color(0xFFD4A94B);
    if (v > 10) return const Color(0xFFB49B6B);
    return Colors.white54;
  }
  return Colors.white70;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2: GRAPHS
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoricalGraphs extends StatelessWidget {
  final Map daily;
  const _HistoricalGraphs({required this.daily});

  List<String> _times() => List<String>.from(daily['time'] ?? []);
  List<num> _nums(String key) =>
      List<num>.from((daily[key] ?? []).map((v) => v ?? 0));

  @override
  Widget build(BuildContext context) {
    final times = _times();
    if (times.isEmpty) return const SizedBox();

    final maxT = _nums('temperature_2m_max');
    final minT = _nums('temperature_2m_min');
    final meanT = _nums('temperature_2m_mean');
    final maxAT = _nums('apparent_temperature_max');
    final minAT = _nums('apparent_temperature_min');
    final meanAT = _nums('apparent_temperature_mean');
    final precip = _nums('precipitation_sum');
    final rain = _nums('rain_sum');
    final snow = _nums('snowfall_sum');
    final precipH = _nums('precipitation_hours');
    final windMax = _nums('wind_speed_10m_max');
    final gusts = _nums('wind_gusts_10m_max');
    final solar = _nums('shortwave_radiation_sum');
    final et0 = _nums('et0_fao_evapotranspiration');
    final sunshine =
        _nums('sunshine_duration').map((v) => v.toDouble() / 3600).toList();

    return SingleChildScrollView(
      child: Column(children: [
        // 1. Temperature band
        _ChartCard(
          title: 'TEMPERATURE',
          unit: '°C',
          legend: [
            _LegendItem('MAX', const Color(0xFFA6755B)),
            _LegendItem('MEAN', Colors.white),
            _LegendItem('MIN', const Color(0xFF5B8FA6)),
          ],
          chart: buildTempBandChart(
            times: times,
            maxTemps: maxT,
            minTemps: minT,
            meanTemps: meanT,
            unit: '°',
          ),
        ),

        // 2. Feels like band
        _ChartCard(
          title: 'APPARENT TEMPERATURE',
          unit: '°C',
          legend: [
            _LegendItem('FEELS MAX', const Color(0xFFA6755B)),
            _LegendItem('FEELS MEAN', Colors.white),
            _LegendItem('FEELS MIN', const Color(0xFF5B8FA6)),
          ],
          chart: buildTempBandChart(
            times: times,
            maxTemps: maxAT,
            minTemps: minAT,
            meanTemps: meanAT,
            unit: '°',
          ),
        ),

        // 3. Precipitation stacked
        _ChartCard(
          title: 'PRECIPITATION',
          unit: 'mm',
          legend: [
            _LegendItem('RAIN', const Color(0xFF5B8FA6)),
            _LegendItem('SNOWFALL', Colors.white70),
          ],
          chart: buildPrecipStackedChart(
            times: times,
            rain: rain,
            snowfall: snow,
          ),
        ),

        // 4. Precipitation hours
        _ChartCard(
          title: 'PRECIPITATION HOURS',
          unit: 'h/day',
          chart: buildAreaChart(
            times: times,
            values: precipH,
            color: const Color(0xFF5B8FA6),
            unit: 'h',
          ),
        ),

        // 5. Wind
        _ChartCard(
          title: 'WIND SPEED',
          unit: 'km/h',
          legend: [
            _LegendItem('GUSTS', const Color(0xFF9B7D5D)),
            _LegendItem('SUSTAINED', const Color(0xFF6E8473)),
          ],
          chart: buildWindChart(
            times: times,
            windMax: windMax,
            gusts: gusts,
          ),
        ),

        // 6. Solar radiation
        _ChartCard(
          title: 'SHORTWAVE SOLAR RADIATION',
          unit: 'MJ/m²',
          chart: buildAreaChart(
            times: times,
            values: solar,
            color: const Color(0xFFD4A94B),
            unit: '',
          ),
        ),

        // 7. Sunshine duration
        _ChartCard(
          title: 'SUNSHINE DURATION',
          unit: 'h/day',
          chart: buildBarChart(
            times: times,
            values: sunshine,
            color: const Color(0xFFB49B6B),
            unit: 'h',
          ),
        ),

        // 8. Evapotranspiration
        _ChartCard(
          title: 'EVAPOTRANSPIRATION (ET₀)',
          unit: 'mm',
          chart: buildBarChart(
            times: times,
            values: et0,
            color: const Color(0xFF6E8473),
            unit: 'mm',
          ),
        ),

        // 9. Heatmaps
        _HeatmapCard(
          title: 'TEMPERATURE HEATMAP',
          unit: '°C',
          times: times,
          values: meanT,
          getColor: _tempGradient,
          formatValue: (v) => '${v.round()}°',
        ),

        _HeatmapCard(
          title: 'PRECIPITATION HEATMAP',
          unit: 'mm',
          times: times,
          values: precip,
          getColor: _precipGradient,
          formatValue: (v) => '${v.toStringAsFixed(1)}mm',
        ),

        const SizedBox(height: 40),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR VIEW
// ═══════════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF9C5E5E), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF9C5E5E), size: 40),
            const SizedBox(height: 16),
            const Text('ERROR',
                style: TextStyle(
                    color: Color(0xFF9C5E5E),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEATHER HEATMAP (unchanged, kept from original)
// ═══════════════════════════════════════════════════════════════════════════════

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
      monthlyData
          .putIfAbsent(date.month, () => [])
          .add(MapEntry(date, values[i]));
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
            final monthName =
                DateFormat('MMM').format(monthData.first.key).toUpperCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(monthName,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
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
                          width: 11,
                          height: 11,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: getColor(entry.value, minVal, maxVal),
                            border: Border.all(
                                color: Colors.white.withAlpha(20), width: 0.5),
                          ),
                        ),
                      )),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 32),
              const Text('LOW',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              ...List.generate(
                  5,
                  (i) => Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: getColor(minVal + (maxVal - minVal) * (i / 4),
                              minVal, maxVal),
                          border: Border.all(
                              color: Colors.white.withAlpha(20), width: 0.5),
                        ),
                      )),
              const SizedBox(width: 6),
              const Text('HIGH',
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
