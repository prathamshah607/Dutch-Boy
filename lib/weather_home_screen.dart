import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:intl/intl.dart';

// LOCAL IMPORTS
import 'riverpod_interface.dart';
import 'weather_background.dart';
import 'weather_mapper.dart';
import 'city_search_screen.dart';

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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.white),
          )
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
                    style: const TextStyle(
                        color: Colors.red,
                        fontFamily: 'monospace',
                        fontSize: 12))),
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
                      padding: const EdgeInsets.only(top: 100, bottom: 30),
                      child: Column(
                        children: [
                          Text(
                            currentCity.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${current['temperature_2m'].round()}°",
                            style: const TextStyle(
                              fontSize: 110,
                              fontWeight: FontWeight.w100,
                              color: Colors.white,
                              height: 0.9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            WeatherMapper.getDescription(
                                    current['weather_code'])
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "H ${daily['temperature_2m_max'][0].round()}°",
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              Container(
                                width: 2,
                                height: 14,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                color: Colors.white30,
                              ),
                              Text(
                                "L ${daily['temperature_2m_min'][0].round()}°",
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // === WARNING ===
                  if (warning != null)
                    SliverToBoxAdapter(
                        child: TechnicalWarningCard(message: warning)),

                  // === HOURLY ===
                  SliverToBoxAdapter(
                    child: TechnicalCard(
                      title: "HOURLY FORECAST",
                      child: SizedBox(
                        height: 127,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: 24,
                          separatorBuilder: (_, __) => Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: Colors.white10,
                          ),
                          itemBuilder: (context, index) {
                            final times = hourly['time'] as List;
                            final now = DateTime.parse(current['time']);
                            final targetIndex = now.hour + index;

                            if (targetIndex >= times.length)
                              return const SizedBox();

                            final time = DateTime.parse(times[targetIndex]);
                            final hCode = hourly['weather_code'][targetIndex];
                            final isDay = hourly['is_day'][targetIndex] == 1;
                            final temp = hourly['temperature_2m'][targetIndex];

                            final precipProb =
                                (hourly['precipitation_probability']
                                        [targetIndex] as num)
                                    .toDouble();
                            final windSpeed =
                                hourly['wind_speed_10m'][targetIndex];
                            final humidity =
                                hourly['relative_humidity_2m'][targetIndex];
                            final uv = hourly['uv_index'][targetIndex];
                            final feelsLike =
                                hourly['apparent_temperature'][targetIndex];

                            String timeLabel = (index == 0)
                                ? "NOW"
                                : DateFormat('HH:mm').format(time);

                            return InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF0A0A0A),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(0)),
                                    side: BorderSide(
                                        color: Color(0xFF00D9FF), width: 2),
                                  ),
                                  builder: (context) => Container(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          WeatherMapper.getDescription(hCode)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12),
                                        ),
                                        const Divider(
                                            color: Color(0xFF00D9FF),
                                            height: 30),
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
                                          value: "${windSpeed.round()} KM/H",
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
                                        color: index == 0
                                            ? const Color(0xFF00D9FF)
                                            : Colors.white,
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
                      ),
                    ),
                  ),

                  // === DAILY ===
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
                          color: Colors.white10,
                        ),
                        itemBuilder: (context, index) {
                          final min = daily['temperature_2m_min'][index];
                          final max = daily['temperature_2m_max'][index];
                          final dCode = daily['weather_code'][index];
                          final date = DateTime.parse(daily['time'][index]);
                          String dayLabel = (index == 0)
                              ? "NOW"
                              : DateFormat('EEE').format(date).toUpperCase();

                          final rainSum = daily['rain_sum'][index];
                          final uvMax = daily['uv_index_max'][index];
                          final windMax = daily['wind_speed_10m_max'][index];
                          final sunrise = DateFormat('HH:mm')
                              .format(DateTime.parse(daily['sunrise'][index]));
                          final sunset = DateFormat('HH:mm')
                              .format(DateTime.parse(daily['sunset'][index]));

                          return ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding:
                                const EdgeInsets.only(top: 8, bottom: 4),
                            iconColor: const Color(0xFF00D9FF),
                            collapsedIconColor: Colors.white54,
                            title: Row(
                              children: [
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    dayLabel,
                                    style: TextStyle(
                                      color: index == 0
                                          ? const Color(0xFF00D9FF)
                                          : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                BoxedIcon(
                                  WeatherMapper.getIcon(dCode, true),
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        WeatherMapper.getDescription(dCode)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.water_drop,
                                              size: 10, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${rainSum}MM",
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 10),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.wb_sunny,
                                              size: 10, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text(
                                            "UV $uvMax",
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    Text(
                                      "${min.round()}°",
                                      style: const TextStyle(
                                        color: Color(0xFF4FC3F7),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 2,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4FC3F7),
                                            Color(0xFFFF6B6B)
                                          ],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "${max.round()}°",
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFF00D9FF), width: 1),
                                  color: Colors.black26,
                                ),
                                child: Column(
                                  children: [
                                    _buildExpandedRow(
                                        Icons.wb_twilight,
                                        "SUNRISE / SUNSET",
                                        "$sunrise / $sunset"),
                                    const SizedBox(height: 6),
                                    _buildExpandedRow(
                                        Icons.air,
                                        "MAX WIND SPEED",
                                        "${windMax.round()} KM/H"),
                                    const SizedBox(height: 6),
                                    _buildExpandedRow(
                                        Icons.thermostat,
                                        "TEMP RANGE",
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

                  // === STATS GRID ===
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        // CONDITION
                        TechnicalDataCard(
                          label: "CONDITION",
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              BoxedIcon(
                                WeatherMapper.getIcon(current['weather_code'],
                                    current['is_day'] == 1),
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                WeatherMapper.getDescription(
                                        current['weather_code'])
                                    .toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),

                        // AQI
                        TechnicalDataCard(
                          label: "AIR QUALITY",
                          child: TechnicalAQIGauge(aqi: aqiValue),
                        ),

                        // SUN
                        TechnicalDataCard(
                          label: "SOLAR",
                          child: TechnicalSunPath(
                            sunrise: DateTime.parse(daily['sunrise'][0]),
                            sunset: DateTime.parse(daily['sunset'][0]),
                            currentTime: DateTime.parse(current['time']),
                          ),
                        ),

                        // WIND
                        TechnicalDataCard(
                          label: "WIND",
                          child: TechnicalWindCompass(
                            direction: (current['wind_direction_10m'] as num)
                                .toDouble(),
                            speed:
                                (current['wind_speed_10m'] as num).toDouble(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === NOW STATS ===
                  SliverToBoxAdapter(
                    child: TechnicalCard(
                      title: "CURRENT CONDITIONS",
                      child: Column(
                        children: [
                          TechnicalDataRow(
                            icon: Icons.thermostat,
                            label: "FEELS LIKE",
                            value:
                                "${current['apparent_temperature'].round()}°",
                          ),
                          TechnicalDataRow(
                            icon: Icons.water_drop,
                            label: "PRECIPITATION",
                            value: "${current['precipitation']}MM",
                          ),
                          TechnicalDataRow(
                            icon: Icons.air,
                            label: "WIND SPEED",
                            value: "${current['wind_speed_10m'].round()} KM/H",
                          ),
                          TechnicalDataRow(
                            icon: Icons.opacity,
                            label: "HUMIDITY",
                            value: "${current['relative_humidity_2m']}%",
                          ),
                          TechnicalDataRow(
                            icon: Icons.visibility,
                            label: "VISIBILITY",
                            value:
                                "${(hourly['visibility'][0] / 1000).round()} KM",
                          ),
                        ],
                      ),
                    ),
                  ),

                  // === TODAY OVERVIEW ===
                  SliverToBoxAdapter(
                    child: TechnicalCard(
                      title: "TODAY'S OVERVIEW",
                      child: Column(
                        children: [
                          TechnicalDataRow(
                            icon: Icons.wb_twilight,
                            label: "SUNRISE / SUNSET",
                            value:
                                "${DateFormat('HH:mm').format(DateTime.parse(daily['sunrise'][0]))} / ${DateFormat('HH:mm').format(DateTime.parse(daily['sunset'][0]))}",
                          ),
                          TechnicalDataRow(
                            icon: Icons.water_drop,
                            label: "TOTAL RAIN",
                            value: "${daily['rain_sum'][0]}MM",
                          ),
                          TechnicalDataRow(
                            icon: Icons.air,
                            label: "MAX WIND",
                            value:
                                "${daily['wind_speed_10m_max'][0].round()} KM/H",
                          ),
                          TechnicalDataRow(
                            icon: Icons.wb_sunny,
                            label: "MAX UV INDEX",
                            value: "${daily['uv_index_max'][0]}",
                          ),
                        ],
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

  Widget _buildExpandedRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00D9FF), size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 10, letterSpacing: 0.5),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TECHNICAL UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

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
          "${speed.round()} KM/H",
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
