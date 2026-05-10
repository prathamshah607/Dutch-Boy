import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:intl/intl.dart';

import 'package:weather/ui/screens/weather_map_screen.dart';
import 'package:weather/data/weather_providers.dart';
import 'package:weather/core/weather_mapper.dart';
import 'package:weather/ui/screens/city_search_screen.dart';
import 'package:weather/ui/widgets/weather_components.dart';
import 'package:weather/ui/screens/historical_weather_screen.dart';
import 'package:weather/ui/screens/daily_detail_screen.dart';

class WeatherHomeScreen extends ConsumerWidget {
  const WeatherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherRequestProvider);
    final currentCity = ref.watch(currentCityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF152A38),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Stack(children: [
          weatherAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF6E8473))),
            error: (err, _) => Center(
                child: Text('ERROR: $err',
                    style: const TextStyle(color: Colors.red))),
            data: (data) =>
                _WeatherBody(data: data, cityName: currentCity.name),
          ),
          SafeArea(child: _TopControls(currentCity: currentCity)),
        ]),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _WeatherBody extends StatelessWidget {
  final Map data;
  final String cityName;

  const _WeatherBody({required this.data, required this.cityName});

  @override
  Widget build(BuildContext context) {
    final current = data['current'];
    final daily = data['daily'];
    final hourly = data['hourly'];
    final aqiData = data['air_quality']?['current'];
    final double aqi =
        (aqiData?['us_aqi'] ?? aqiData?['european_aqi'] ?? 0).toDouble();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _WeatherHeader(
              current: current, daily: daily, cityName: cityName),
        ),
        SliverToBoxAdapter(
          child: TechnicalCard(
            title: 'HOURLY FORECAST',
            child: HourlyForecastList(
              hourly: hourly,
              current: current,
              startHour: DateTime.parse(current['time']).hour,
              itemCount: 24,
              cityName: cityName,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TechnicalCard(
            title: '16-DAY FORECAST',
            child: _DailyForecastList(
              daily: daily,
              hourly: hourly,
              current: current,
              cityName: cityName,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TechnicalCard(
            title: 'ENVIRONMENTAL TELEMETRY',
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  BoxedIcon(
                    WeatherMapper.getIcon(
                        current['weather_code'], current['is_day'] == 1),
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  const Text('VISUAL',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: WeatherTelemetryCluster(
                  aqi: aqi,
                  sunrise: DateTime.parse(daily['sunrise'][0]),
                  sunset: DateTime.parse(daily['sunset'][0]),
                  now: DateTime.parse(current['time']),
                  windDirection:
                      (current['wind_direction_10m'] as num).toDouble(),
                  windSpeed: (current['wind_speed_10m'] as num).toDouble(),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: HourlyChartsSection(hourly: hourly, current: current),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _WeatherHeader extends StatelessWidget {
  final Map current;
  final Map daily;
  final String cityName;

  const _WeatherHeader(
      {required this.current, required this.daily, required this.cityName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100, bottom: 20, left: 24, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cityName.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text("${current['temperature_2m'].round()}°",
                    style: const TextStyle(
                        fontSize: 96,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -4)),
                Text(
                    WeatherMapper.getDescription(current['weather_code'])
                        .toUpperCase(),
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6E8473),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                              color: Colors.black87,
                              blurRadius: 8,
                              offset: Offset(0, 1))
                        ])),
                const SizedBox(height: 6),
                Row(children: [
                  _hiLoText("H ${daily['temperature_2m_max'][0].round()}°"),
                  Container(
                      width: 2,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white24),
                  _hiLoText("L ${daily['temperature_2m_min'][0].round()}°"),
                ]),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.white12))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CompactStat('FEELS LIKE',
                      "${current['apparent_temperature'].round()}°"),
                  const SizedBox(height: 12),
                  _CompactStat('PRECIP', "${current['precipitation']} mm"),
                  const SizedBox(height: 12),
                  _CompactStat(
                      'WIND', "${current['wind_speed_10m'].round()} km/h"),
                  const SizedBox(height: 12),
                  _CompactStat(
                      'HUMIDITY', "${current['relative_humidity_2m']}%"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _hiLoText(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1))
          ]));
}

// ─── _CompactStat ─────────────────────────────────────────────────────────────

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  const _CompactStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6E8473),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                      color: Colors.black87,
                      blurRadius: 8,
                      offset: Offset(0, 1))
                ])),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                      color: Colors.black87,
                      blurRadius: 8,
                      offset: Offset(0, 1))
                ])),
      ],
    );
  }
}

// ─── _DailyForecastList ───────────────────────────────────────────────────────

class _DailyForecastList extends StatelessWidget {
  final Map daily;
  final Map hourly;
  final Map current;
  final String cityName;

  const _DailyForecastList({
    required this.daily,
    required this.hourly,
    required this.current,
    required this.cityName,
  });

  @override
  Widget build(BuildContext context) {
    final int dayCount = ((daily['time'] as List?)?.length ?? 14).clamp(1, 16);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: dayCount,
      separatorBuilder: (_, __) => Container(height: 1, color: Colors.white10),
      itemBuilder: (context, index) => _DailyForecastTile(
        index: index,
        daily: daily,
        hourly: hourly,
        current: current,
        cityName: cityName,
      ),
    );
  }
}

// ─── _DailyForecastTile ───────────────────────────────────────────────────────

class _DailyForecastTile extends StatelessWidget {
  final int index;
  final Map daily;
  final Map hourly;
  final Map current;
  final String cityName;

  const _DailyForecastTile({
    required this.index,
    required this.daily,
    required this.hourly,
    required this.current,
    required this.cityName,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(daily['time'][index]);
    final min = daily['temperature_2m_min'][index];
    final max = daily['temperature_2m_max'][index];
    final dCode = daily['weather_code'][index];
    final precipSum = (daily['precipitation_sum'][index] as num).toDouble();
    final precipProb = daily['precipitation_probability_max'][index];
    final windMax = daily['wind_speed_10m_max'][index];
    final humidMax = daily['relative_humidity_2m_max']?[index] ?? 0;
    final pressure = daily['surface_pressure_mean']?[index]?.round() ?? 1013;
    final sunrise =
        DateFormat('HH:mm').format(DateTime.parse(daily['sunrise'][index]));
    final sunset =
        DateFormat('HH:mm').format(DateTime.parse(daily['sunset'][index]));
    final dayLabel =
        index == 0 ? 'NOW' : DateFormat('EEE').format(date).toUpperCase();

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(vertical: 2),
      childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
      iconColor: const Color(0xFF6E8473),
      collapsedIconColor: Colors.white54,
      title: Row(children: [
        SizedBox(
          width: 55,
          child: Text(dayLabel,
              style: TextStyle(
                  color: index == 0 ? const Color(0xFF6E8473) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(children: [
            BoxedIcon(WeatherMapper.getIcon(dCode, true),
                color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                WeatherMapper.getDescription(dCode).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        _TileQuickStats(
          precipSum: precipSum,
          precipProb: precipProb,
          humidMax: humidMax,
          pressure: pressure,
          min: min,
          max: max,
        ),
      ]),
      children: [
        _DailyExpandedContent(
          index: index,
          daily: daily,
          hourly: hourly,
          current: current,
          cityName: cityName,
          sunrise: sunrise,
          sunset: sunset,
          windMax: windMax,
          min: min,
          max: max,
        ),
      ],
    );
  }
}

// ─── _TileQuickStats ──────────────────────────────────────────────────────────

class _TileQuickStats extends StatelessWidget {
  final double precipSum;
  final dynamic precipProb;
  final dynamic humidMax;
  final int pressure;
  final dynamic min;
  final dynamic max;

  const _TileQuickStats({
    required this.precipSum,
    required this.precipProb,
    required this.humidMax,
    required this.pressure,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (precipSum > 0) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${precipSum.toStringAsFixed(1)}mm',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text('$precipProb%',
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          _divider(),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$humidMax%',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text('${pressure}hPa',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        _divider(),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${max.round()}°',
                style: const TextStyle(
                    color: Color(0xFFA6755B),
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            Text('${min.round()}°',
                style: const TextStyle(
                    color: Color(0xFF7E97A8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  static Widget _divider() => Container(
      width: 1,
      height: 26,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 10));
}

// ─── _DailyExpandedContent ────────────────────────────────────────────────────

class _DailyExpandedContent extends StatelessWidget {
  final int index;
  final Map daily;
  final Map hourly;
  final Map current;
  final String cityName;
  final String sunrise;
  final String sunset;
  final dynamic windMax;
  final dynamic min;
  final dynamic max;

  const _DailyExpandedContent({
    required this.index,
    required this.daily,
    required this.hourly,
    required this.current,
    required this.cityName,
    required this.sunrise,
    required this.sunset,
    required this.windMax,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF6E8473)),
          color: Colors.black26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HOURLY BREAKDOWN LABEL ───────────────────────────────────────
          Row(children: [
            Container(
                width: 3,
                height: 12,
                color: const Color(0xFF6E8473),
                margin: const EdgeInsets.only(right: 8)),
            const Text('HOURLY BREAKDOWN',
                style: TextStyle(
                    color: Color(0xFF6E8473),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 6),

          // ── HOURLY STRIP ─────────────────────────────────────────────────
          HourlyForecastList(
            hourly: hourly,
            current: current,
            startHour: index * 24,
            itemCount: 24,
            height: 120,
            cityName: cityName,
          ),

          const SizedBox(height: 8),
          const Divider(color: Color(0xFF6E8473), height: 1),
          const SizedBox(height: 8),

          // ── QUICK STATS ──────────────────────────────────────────────────
          _ExpandedRow(
              Icons.wb_twilight, 'SUNRISE / SUNSET', '$sunrise / $sunset'),
          const SizedBox(height: 4),
          _ExpandedRow(Icons.air, 'MAX WIND SPEED', '${windMax.round()} km/h'),
          const SizedBox(height: 4),
          _ExpandedRow(Icons.thermostat, 'TEMP RANGE',
              '${min.round()}° — ${max.round()}°'),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),

          // ── FULL DAY DETAILS BUTTON ──────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DailyDetailScreen(
                  daily: daily,
                  hourly: hourly,
                  current: current,
                  index: index,
                  cityName: cityName,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'FULL DAY DETAILS',
                  style: TextStyle(
                    color: Color(0xFF6E8473),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: Color(0xFF6E8473), size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _ExpandedRow ─────────────────────────────────────────────────────────────

class _ExpandedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ExpandedRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF6E8473), size: 14),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 10, letterSpacing: 0.5)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ─── _TopControls ─────────────────────────────────────────────────────────────

class _TopControls extends ConsumerWidget {
  final dynamic currentCity;
  const _TopControls({required this.currentCity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.black.withAlpha(41),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10)),
        child: Row(children: [
          IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CitySearchScreen())),
              icon: const Icon(Icons.search, color: Colors.white)),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1F2A31),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'units',
                  child: Text('CHANGE UNITS',
                      style: TextStyle(color: Colors.white))),
              PopupMenuItem(
                  value: 'graph',
                  child: Text('VIEW HISTORICAL GRAPH',
                      style: TextStyle(color: Colors.white))),
              PopupMenuItem(
                  value: 'map',
                  child: Text('WEATHER MAP',
                      style: TextStyle(color: Colors.white))),
            ],
            onSelected: (value) {
              if (value == 'map') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WeatherMapScreen()));
              }
              if (value == 'units') _showUnitsDialog(context, ref);
              if (value == 'graph') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            HistoricalWeatherScreen(city: currentCity)));
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showUnitsDialog(BuildContext context, WidgetRef ref) {
    final currentTempUnit = ref.read(temperatureUnitProvider);
    final currentSpeedUnit = ref.read(speedUnitProvider);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2A31),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: Color(0xFF6E8473), width: 2)),
        title: Row(children: [
          Container(
              width: 4,
              height: 20,
              color: const Color(0xFF6E8473),
              margin: const EdgeInsets.only(right: 12)),
          const Text('UNIT PREFERENCES',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TEMPERATURE',
                style: TextStyle(
                    color: Color(0xFF6E8473),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            ...TemperatureUnit.values.map((unit) => RadioListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF6E8473),
                  title: Text('${unit.label} (${unit.symbol})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  value: unit,
                  groupValue: currentTempUnit,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(temperatureUnitProvider.notifier).state = value;
                      Navigator.pop(context);
                    }
                  },
                )),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF6E8473), height: 1),
            const SizedBox(height: 20),
            const Text('WIND SPEED',
                style: TextStyle(
                    color: Color(0xFF6E8473),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            ...SpeedUnit.values.map((unit) => RadioListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF6E8473),
                  title: Text('${unit.label} (${unit.symbol})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  value: unit,
                  groupValue: currentSpeedUnit,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(speedUnitProvider.notifier).state = value;
                      Navigator.pop(context);
                    }
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6E8473)),
              child: const Text('CLOSE',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
