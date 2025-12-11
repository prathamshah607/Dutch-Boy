import 'dart:math';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED: Add fl_chart to pubspec.yaml
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:intl/intl.dart';

// LOCAL IMPORTS
import 'riverpod_interface.dart';
import 'weather_background.dart';
import 'weather_mapper.dart';
import 'city_search_screen.dart';
import 'llm.dart';
import 'historical_weather_screen.dart';

class WeatherHomeScreen extends ConsumerWidget {
  const WeatherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherRequestProvider);
    final currentCity = ref.watch(currentCityProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CitySearchScreen()),
            );
          },
          icon: const Icon(Icons.search, color: Colors.white),
        ),
        actions: [
          weatherAsync.when(
            data: (data) => OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon:
                  const Icon(Icons.thunderstorm_outlined, color: Colors.white),
              label: Text("MODELLER",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClimateAssistantPage(
                      city: currentCity,
                      weatherData: data,
                    ),
                  ),
                );
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // ... (Existing popup menu code) ...
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1D1E33),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'units',
                  child: Text('CHANGE UNITS',
                      style: TextStyle(color: Colors.white))),
              const PopupMenuItem(
                  value: 'graph',
                  child: Text('VIEW HISTORICAL GRAPH',
                      style: TextStyle(color: Colors.white))),
            ],
            onSelected: (value) {
              if (value == 'units') _showUnitsDialog(context, ref);
              if (value == 'graph')
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            HistoricalWeatherScreen(city: currentCity)));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // BACKGROUND
          weatherAsync.when(
            data: (data) {
              final current = data['current'];
              return WeatherBackground(
                code: current['weather_code'],
                isDay: current['is_day'] == 1,
                currentTimeString: current['time'],
              );
            },
            loading: () => Container(color: const Color(0xFF000000)),
            error: (_, __) => Container(color: const Color(0xFF000000)),
          ),

          // CONTENT
          weatherAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D9FF))),
            error: (err, stack) => Center(
                child: Text('ERROR: $err',
                    style: const TextStyle(color: Colors.red))),
            data: (data) {
              final current = data['current'];
              final daily = data['daily'];
              final hourly = data['hourly'];

              final aqiData = data['air_quality']?['current'];
              final double aqiValue =
                  (aqiData?['us_aqi'] ?? aqiData?['european_aqi'] ?? 0)
                      .toDouble();
              final int code = current['weather_code'];

              String? warning;
              if (code >= 95)
                warning = "THUNDERSTORM WARNING";
              else if (code == 75 || code == 77)
                warning = "HEAVY SNOWFALL";
              else if (code == 66 || code == 67)
                warning = "FREEZING RAIN ALERT";

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // === HEADER ===
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.only(
                          top: 100, bottom: 20, left: 24, right: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.7)
                          ],
                          stops: const [0.0, 0.9],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentCity.name.toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${current['temperature_2m'].round()}°",
                                      style: const TextStyle(
                                          fontSize: 96,
                                          fontWeight: FontWeight.w200,
                                          color: Colors.white,
                                          height: 1.0,
                                          letterSpacing: -4),
                                    ),
                                    Text(
                                      WeatherMapper.getDescription(
                                              current['weather_code'])
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF00D9FF),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                            "H ${daily['temperature_2m_max'][0].round()}°",
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white70)),
                                        Container(
                                            width: 2,
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            color: Colors.white24),
                                        Text(
                                            "L ${daily['temperature_2m_min'][0].round()}°",
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white70)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.only(
                                      left: 16, bottom: 8),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          left: BorderSide(
                                              color: Colors.white12,
                                              width: 1))),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _buildCompactStat("FEELS LIKE",
                                          "${current['apparent_temperature'].round()}°"),
                                      const SizedBox(height: 12),
                                      _buildCompactStat("PRECIP",
                                          "${current['precipitation']}MM"),
                                      const SizedBox(height: 12),
                                      _buildCompactStat("WIND",
                                          "${current['wind_speed_10m'].round()}"),
                                      const SizedBox(height: 12),
                                      _buildCompactStat("HUMIDITY",
                                          "${current['relative_humidity_2m']}%"),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                                color: const Color(0xFF0A0A0A).withOpacity(0.8),
                                border: Border.all(
                                    color: Colors.white12, width: 1)),
                            child: Column(
                              children: [
                                const Text("ENVIRONMENTAL TELEMETRY",
                                    style: TextStyle(
                                        color: Color(0xFF00D9FF),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                        child: Column(children: [
                                      BoxedIcon(
                                          WeatherMapper.getIcon(
                                              current['weather_code'],
                                              current['is_day'] == 1),
                                          size: 20,
                                          color: Colors.white),
                                      const SizedBox(height: 6),
                                      const Text("VISUAL",
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700))
                                    ])),
                                    Expanded(
                                        child: _CondensedAQI(aqi: aqiValue)),
                                    Expanded(
                                        child: _CondensedSun(
                                            sunrise: DateTime.parse(
                                                daily['sunrise'][0]),
                                            sunset: DateTime.parse(
                                                daily['sunset'][0]),
                                            now: DateTime.parse(
                                                current['time']))),
                                    Expanded(
                                        child: _CondensedWind(
                                            dir: (current['wind_direction_10m']
                                                    as num)
                                                .toDouble(),
                                            speed: (current['wind_speed_10m']
                                                    as num)
                                                .toDouble())),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (warning != null)
                    SliverToBoxAdapter(
                        child: TechnicalWarningCard(message: warning)),

                  // === HOURLY LIST ===
                  SliverToBoxAdapter(
                    child: TechnicalCard(
                      title: "HOURLY FORECAST",
                      child: HourlyForecastList(
                        hourly: hourly,
                        current: current,
                        startHour: DateTime.parse(current['time']).hour,
                        itemCount: 24,
                      ),
                    ),
                  ),

                  // === NEW: 24H CHARTS ===
                  SliverToBoxAdapter(
                    child:
                        _HourlyChartsSection(hourly: hourly, current: current),
                  ),

                  // === DAILY LIST ===
                  SliverToBoxAdapter(
                    child: TechnicalCard(
                      title: "10-DAY FORECAST",
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: 10,
                        separatorBuilder: (_, __) => Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.white10),
                        itemBuilder: (context, index) {
  final min = daily['temperature_2m_min'][index];
  final max = daily['temperature_2m_max'][index];
  final dCode = daily['weather_code'][index];
  final date = DateTime.parse(daily['time'][index]);

  final rainSum = daily['rain_sum'][index];
  final uvMax = daily['uv_index_max'][index];
  final windMax = daily['wind_speed_10m_max'][index];
  final sunrise = DateFormat('HH:mm')
      .format(DateTime.parse(daily['sunrise'][index]));
  final sunset = DateFormat('HH:mm')
      .format(DateTime.parse(daily['sunset'][index]));

  String dayLabel = (index == 0)
      ? "NOW"
      : DateFormat('EEE').format(date).toUpperCase();

  return ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
    iconColor: const Color(0xFF00D9FF),
    collapsedIconColor: Colors.white54,

    // =============================
    //            TITLE ROW
    // =============================
    title: Row(
      children: [
        // DAY LABEL (fixed width)
        SizedBox(
          width: 45,
          child: Text(
            dayLabel,
            style: TextStyle(
              color:
                  index == 0 ? const Color(0xFF00D9FF) : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ===== LEFT SECTION (FLEXIBLE) =====
        Flexible(
          child: Row(
            children: [
              BoxedIcon(
                WeatherMapper.getIcon(dCode, true),
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DESCRIPTION TEXT (truncates when needed)
                    Text(
                      WeatherMapper.getDescription(dCode).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // SMALL METRICS ROW (shrinks gracefully)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          children: [
                            Icon(Icons.water_drop,
                                size: 10, color: Colors.white54),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                "${rainSum}MM",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.wb_sunny,
                                size: 10, color: Colors.white54),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                "UV $uvMax",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // ===== RIGHT SECTION (ALWAYS VISIBLE) =====
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${min.round()}° ",
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              " ${max.round()}°",
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),

    // =============================
    //         EXPANDED CONTENT
    // =============================
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF00D9FF), width: 1),
          color: Colors.black26,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  color: const Color(0xFF00D9FF),
                  margin: const EdgeInsets.only(right: 8),
                ),
                const Text(
                  'HOURLY BREAKDOWN',
                  style: TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            HourlyForecastList(
              hourly: hourly,
              current: current,
              startHour: index * 24,
              itemCount: 24,
              height: 130,
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF00D9FF), height: 1),
            const SizedBox(height: 12),

            _buildExpandedRow(Icons.wb_twilight, "SUNRISE / SUNSET",
                "$sunrise / $sunset"),
            const SizedBox(height: 6),
            _buildExpandedRow(Icons.air, "MAX WIND SPEED",
                "${windMax.round()} units"),
            const SizedBox(height: 6),
            _buildExpandedRow(Icons.thermostat, "TEMP RANGE",
                "${min.round()}° - ${max.round()}°"),
          ],
        ),
      ),
    ],
  );
},

                        ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ... (Keep existing helpers like _buildCompactStat, _buildExpandedRow, _showUnitsDialog) ...
  Widget _buildCompactStat(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildExpandedRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00D9FF), size: 14),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10, letterSpacing: 0.5)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _showUnitsDialog(BuildContext context, WidgetRef ref) {
    final currentTempUnit = ref.read(temperatureUnitProvider);
    final currentSpeedUnit = ref.read(speedUnitProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: Color(0xFF00D9FF), width: 2),
        ),
        title: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              color: const Color(0xFF00D9FF),
              margin: const EdgeInsets.only(right: 12),
            ),
            const Text(
              'UNIT PREFERENCES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Temperature Unit Section
            const Text(
              'TEMPERATURE',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ...TemperatureUnit.values.map((unit) {
              return RadioListTile<TemperatureUnit>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF00D9FF),
                title: Text(
                  '${unit.label} (${unit.symbol})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: unit,
                groupValue: currentTempUnit,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(temperatureUnitProvider.notifier).state = value;
                    Navigator.pop(
                        context); // Close dialog immediately on selection
                  }
                },
              );
            }),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFF00D9FF), height: 1),
            const SizedBox(height: 20),

            // Speed Unit Section
            const Text(
              'WIND SPEED',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ...SpeedUnit.values.map((unit) {
              return RadioListTile<SpeedUnit>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF00D9FF),
                title: Text(
                  '${unit.label} (${unit.symbol})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: unit,
                groupValue: currentSpeedUnit,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(speedUnitProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00D9FF),
            ),
            child: const Text('CLOSE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEW: HOURLY CHARTS SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _HourlyChartsSection extends StatelessWidget {
  final Map<String, dynamic> hourly;
  final Map<String, dynamic> current;

  const _HourlyChartsSection({required this.hourly, required this.current});

  @override
  Widget build(BuildContext context) {
    final times = List<String>.from(hourly['time']);
    // Find current index
    final now = DateTime.parse(current['time']);
    int startIdx = times.indexWhere((t) {
      final tDate = DateTime.parse(t);
      return tDate.year == now.year &&
          tDate.month == now.month &&
          tDate.day == now.day &&
          tDate.hour == now.hour;
    });
    if (startIdx < 0) startIdx = 0;

    // Get next 24 hours of data
    final range = 24;
    final endIdx = (startIdx + range).clamp(0, times.length);

    // Prepare Data for Charts
    final timeLabels = <String>[];
    final temps = <FlSpot>[];
    final appTemps = <FlSpot>[];
    final precip = <BarChartGroupData>[];

    for (int i = 0; i < (endIdx - startIdx); i++) {
      int idx = startIdx + i;
      final tStr = times[idx];
      final timeObj = DateTime.parse(tStr);
      timeLabels.add(DateFormat('HH:mm').format(timeObj));

      // Temperature Lines
      final tVal = (hourly['temperature_2m'][idx] as num).toDouble();
      final aVal = (hourly['apparent_temperature'][idx] as num).toDouble();
      temps.add(FlSpot(i.toDouble(), tVal));
      appTemps.add(FlSpot(i.toDouble(), aVal));

      // Precip Bars
      final pVal = (hourly['precipitation'][idx] as num).toDouble();
      precip.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pVal,
              color: const Color(0xFF00D9FF),
              width: 6,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ],
        ),
      );
    }

    if (timeLabels.isEmpty) return const SizedBox();

    return Column(
      children: [
        // 1. TEMPERATURE CHART
        TechnicalCard(
          title: "24H TEMPERATURE TREND (°C)",
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4, // Show label every 4 hours
                      getTitlesWidget: (val, meta) {
                        int index = val.toInt();
                        if (index >= 0 && index < timeLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(timeLabels[index],
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) => Text("${val.toInt()}°",
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Actual Temp
                  LineChartBarData(
                    spots: temps,
                    isCurved: true,
                    color: const Color(0xFFFF6B6B),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFFF6B6B).withOpacity(0.1)),
                  ),
                  // Apparent Temp (Dashed-ish look via simpler color)
                  LineChartBarData(
                    spots: appTemps,
                    isCurved: true,
                    color: const Color(0xFFFFAA00),
                    barWidth: 2,
                    dashArray: [5, 5], // Dashed line
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
        TechnicalCard(
          title: "24H RAINFALL (MM)",
          child: SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // Do NOT rely on interval here for BarChart
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();

                        // Safety check: valid index
                        if (index < 0 || index >= timeLabels.length) {
                          return const SizedBox.shrink();
                        }

                        // Show only every 4th hour
                        if (index % 4 != 0) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            timeLabels[index],
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox.shrink();
                        return Text(
                          val.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: precip,
              ),
            ),
          ),
        )
      ],
    );
  }
}

// === EXISTING CONDENSED WIDGETS ===
// (Keep _CondensedAQI, _CondensedSun, _CondensedWind, TechnicalCard, etc.)
// ... (Paste your existing Condensed widgets here) ...
// === CONDENSED WIDGETS ===

class _CondensedAQI extends StatelessWidget {
  final double aqi;
  const _CondensedAQI({required this.aqi});

  @override
  Widget build(BuildContext context) {
    Color color = aqi > 100
        ? Colors.red
        : aqi > 50
            ? Colors.orange
            : Colors.green;
    return Column(
      children: [
        Text("${aqi.round()}",
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text("AQI",
            style: TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CondensedSun extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime now;
  const _CondensedSun(
      {required this.sunrise, required this.sunset, required this.now});

  @override
  Widget build(BuildContext context) {
    int total = sunset.difference(sunrise).inMinutes;
    int passed = now.difference(sunrise).inMinutes;
    double pct = (total == 0) ? 0 : (passed / total).clamp(0.0, 1.0);
    if (now.isBefore(sunrise)) pct = 0;
    if (now.isAfter(sunset)) pct = 1;

    return Column(
      children: [
        SizedBox(
          width: 30,
          height: 15,
          child: CustomPaint(
            painter: TechnicalSunArcPainter(percent: pct),
          ),
        ),
        const SizedBox(height: 6),
        const Text("SOLAR",
            style: TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CondensedWind extends StatelessWidget {
  final double dir;
  final double speed;
  const _CondensedWind({required this.dir, required this.speed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Transform.rotate(
            angle: dir * pi / 180,
            child: const Icon(Icons.navigation,
                color: Color(0xFF00D9FF), size: 16)),
        const SizedBox(height: 4),
        Text("${speed.round()}",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TECHNICAL UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// REUSABLE HOURLY FORECAST WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class HourlyForecastList extends StatelessWidget {
  final Map<String, dynamic> hourly;
  final Map<String, dynamic> current;
  final int startHour;
  final int itemCount;
  final double height;

  const HourlyForecastList({
    super.key,
    required this.hourly,
    required this.current,
    this.startHour = 0,
    this.itemCount = 24,
    this.height = 127,
  });

  @override
  Widget build(BuildContext context) {
    final times = hourly['time'] as List;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => Container(
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Colors.white10,
        ),
        itemBuilder: (context, index) {
          final targetIndex = startHour + index;

          if (targetIndex >= times.length) return const SizedBox();

          final time = DateTime.parse(times[targetIndex]);
          final hCode = hourly['weather_code'][targetIndex];
          final isDay = hourly['is_day'][targetIndex] == 1;
          final temp = hourly['temperature_2m'][targetIndex];

          final precipProb =
              (hourly['precipitation_probability'][targetIndex] as num)
                  .toDouble();
          final windSpeed = hourly['wind_speed_10m'][targetIndex];
          final humidity = hourly['relative_humidity_2m'][targetIndex];
          final uv = hourly['uv_index'][targetIndex];
          final feelsLike = hourly['apparent_temperature'][targetIndex];

          final now = DateTime.parse(current['time']);
          final isNow =
              (startHour == 0 && index == 0 && targetIndex == now.hour);
          String timeLabel = isNow ? "NOW" : DateFormat('HH:mm').format(time);

          return InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF0A0A0A),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
                  side: BorderSide(color: Color(0xFF00D9FF), width: 2),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$timeLabel FORECAST",
                        style: const TextStyle(
                          color: Color(0xFF00D9FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        WeatherMapper.getDescription(hCode).toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const Divider(color: Color(0xFF00D9FF), height: 30),
                      TechnicalDataRow(
                        icon: Icons.thermostat,
                        label: "FEELS LIKE",
                        value: "${feelsLike.round()}°",
                      ),
                      TechnicalDataRow(
                        icon: Icons.water_drop,
                        label: "PRECIPITATION",
                        value: "${precipProb.round()}%",
                      ),
                      TechnicalDataRow(
                        icon: Icons.air,
                        label: "WIND SPEED",
                        value: "${windSpeed.round()} units",
                      ),
                      TechnicalDataRow(
                        icon: Icons.opacity,
                        label: "HUMIDITY",
                        value: "${humidity.round()}%",
                      ),
                      TechnicalDataRow(
                        icon: Icons.wb_sunny,
                        label: "UV INDEX",
                        value: uv.toStringAsFixed(1),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: isNow ? const Color(0xFF00D9FF) : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BoxedIcon(
                    WeatherMapper.getIcon(hCode, isDay),
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${temp.round()}°",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TechnicalCard extends StatelessWidget {
  final String title;
  final Widget child;

  const TechnicalCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF00D9FF), width: 2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  color: const Color(0xFF00D9FF),
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class TechnicalDataCard extends StatelessWidget {
  final String label;
  final Widget child;

  const TechnicalDataCard(
      {super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF00D9FF), width: 1)),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }
}

class TechnicalDataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const TechnicalDataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 16),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class TechnicalWarningCard extends StatelessWidget {
  final String message;

  const TechnicalWarningCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000).withOpacity(0.2),
        border: Border.all(color: const Color(0xFFFF0000), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Color(0xFFFF0000), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "⚠ ALERT",
                  style: TextStyle(
                    color: Color(0xFFFF0000),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TechnicalAQIGauge extends StatelessWidget {
  final double aqi;

  const TechnicalAQIGauge({super.key, required this.aqi});

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFF00FF00);
    String label = "GOOD";
    if (aqi > 50) {
      color = const Color(0xFFFFFF00);
      label = "MODERATE";
    }
    if (aqi > 100) {
      color = const Color(0xFFFF9800);
      label = "UNHEALTHY";
    }
    if (aqi > 150) {
      color = const Color(0xFFFF0000);
      label = "POOR";
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white10, width: 3),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 3),
                ),
              ),
              Text(
                "${aqi.round()}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class TechnicalSunPath extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime currentTime;

  const TechnicalSunPath({
    super.key,
    required this.sunrise,
    required this.sunset,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    int dayLength = sunset.difference(sunrise).inMinutes;
    int timePassed = currentTime.difference(sunrise).inMinutes;
    double percent =
        (dayLength == 0) ? 0 : (timePassed / dayLength).clamp(0.0, 1.0);

    if (currentTime.isBefore(sunrise)) percent = 0.0;
    if (currentTime.isAfter(sunset)) percent = 1.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 40,
          child: CustomPaint(
            painter: TechnicalSunArcPainter(percent: percent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('HH:mm').format(sunrise),
              style: const TextStyle(
                  color: Color(0xFFFFAA00),
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
            const Text(" → ",
                style: TextStyle(color: Colors.white54, fontSize: 10)),
            Text(
              DateFormat('HH:mm').format(sunset),
              style: const TextStyle(
                  color: Color(0xFFFF6B00),
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class TechnicalSunArcPainter extends CustomPainter {
  final double percent;

  TechnicalSunArcPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    canvas.drawArc(rect, pi, pi, false, paint);

    // Progress line
    final progressPaint = Paint()
      ..color = const Color(0xFFFFAA00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawArc(rect, pi, pi * percent, false, progressPaint);

    // Sun position
    double angle = pi + (pi * percent);
    double r = size.width / 2;
    double cx = size.width / 2 + r * cos(angle);
    double cy = size.height + r * sin(angle);

    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 6),
      Paint()..color = const Color(0xFFFFAA00),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TechnicalWindCompass extends StatelessWidget {
  final double direction;
  final double speed;

  const TechnicalWindCompass({
    super.key,
    required this.direction,
    required this.speed,
  });

  @override
  Widget build(BuildContext context) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    String dirLabel = dirs[((direction + 22.5) % 360 / 45).floor() % 8];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: (direction * pi / 180),
          child:
              const Icon(Icons.navigation, color: Color(0xFF00D9FF), size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          "${speed.round()} units",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dirLabel,
          style: const TextStyle(
            color: Color(0xFF00D9FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
