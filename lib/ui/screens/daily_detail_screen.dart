import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:weather/core/weather_mapper.dart';
import 'package:weather/ui/widgets/weather_components.dart';

class DailyDetailScreen extends StatelessWidget {
  final Map daily;    // full daily map
  final Map hourly;   // full hourly map (for embedded 24h breakdown)
  final Map current;  // current conditions (passed through for HourlyForecastList)
  final int index;    // day index (0 = today)
  final String cityName;

  const DailyDetailScreen({
    super.key,
    required this.daily,
    required this.hourly,
    required this.current,
    required this.index,
    required this.cityName,
  });

  T? _get<T>(String key) {
    final list = daily[key];
    if (list == null || index >= (list as List).length) return null;
    final val = list[index];
    if (val == null) return null;
    return val as T;
  }

  double? _d(String key) => (_get<num>(key))?.toDouble();
  int?    _i(String key) => (_get<num>(key))?.round();
  String? _s(String key) => _get<String>(key);

  String _fmt(String? iso, String format) {
    if (iso == null) return '--';
    return DateFormat(format).format(DateTime.parse(iso));
  }

  @override
  Widget build(BuildContext context) {
    final dateIso = _s('time') ?? '';
    final dt = dateIso.isNotEmpty ? DateTime.parse(dateIso) : DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d').format(dt).toUpperCase();
    final hCode = _i('weather_code') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B24),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cityName.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5),
            ),
            Text(
              dateLabel,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── IDENTITY BANNER ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: Colors.black26,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BoxedIcon(
                    WeatherMapper.getIcon(hCode, true),
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        WeatherMapper.getDescription(hCode).toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF6E8473),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text(
                          '${_i('temperature_2m_max') ?? '--'}°',
                          style: const TextStyle(
                              color: Color(0xFFA6755B),
                              fontSize: 38,
                              fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 28, color: Colors.white24),
                        const SizedBox(width: 12),
                        Text(
                          '${_i('temperature_2m_min') ?? '--'}°',
                          style: const TextStyle(
                              color: Color(0xFF7E97A8),
                              fontSize: 38,
                              fontWeight: FontWeight.w300),
                        ),
                      ]),
                      Text(
                        'FEELS  ${_i('apparent_temperature_max') ?? '--'}° / ${_i('apparent_temperature_min') ?? '--'}°',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── HOURLY BREAKDOWN (embedded, same as home screen dropdown) ───
            TechnicalCard(
              title: 'HOURLY BREAKDOWN',
              child: HourlyForecastList(
                hourly: hourly,
                current: current,
                startHour: index * 24,
                itemCount: 24,
                height: 127,
              ),
            ),

            // ── SUN & DAYLIGHT ───────────────────────────────────────────────
            _Section(title: 'SUN & DAYLIGHT', rows: [
              _Row(Icons.wb_twilight,   'SUNRISE',              _fmt(_s('sunrise'), 'HH:mm')),
              _Row(Icons.nights_stay,   'SUNSET',               _fmt(_s('sunset'), 'HH:mm')),
              _Row(Icons.schedule,      'DAYLIGHT DURATION',    _duration(_i('daylight_duration'))),
              _Row(Icons.wb_sunny,      'SUNSHINE DURATION',    _duration(_i('sunshine_duration'))),
              _Row(Icons.solar_power,   'UV INDEX MAX',         _d('uv_index_max')?.toStringAsFixed(1) ?? '--'),
              _Row(Icons.wb_sunny_outlined, 'UV MAX (CLEAR SKY)', _d('uv_index_clear_sky_max')?.toStringAsFixed(1) ?? '--'),
              _Row(Icons.flash_on,      'SOLAR RADIATION SUM',  '${_d('shortwave_radiation_sum')?.toStringAsFixed(1) ?? '--'} MJ/m²'),
            ]),

            // ── TEMPERATURE ──────────────────────────────────────────────────
            _Section(title: 'TEMPERATURE', rows: [
              _Row(Icons.thermostat,        'MAX',                  '${_i('temperature_2m_max') ?? '--'}°'),
              _Row(Icons.thermostat,        'MEAN',                 '${_i('temperature_2m_mean') ?? '--'}°'),
              _Row(Icons.thermostat,        'MIN',                  '${_i('temperature_2m_min') ?? '--'}°'),
              _Row(Icons.device_thermostat, 'FEELS LIKE MAX',       '${_i('apparent_temperature_max') ?? '--'}°'),
              _Row(Icons.device_thermostat, 'FEELS LIKE MEAN',      '${_i('apparent_temperature_mean') ?? '--'}°'),
              _Row(Icons.device_thermostat, 'FEELS LIKE MIN',       '${_i('apparent_temperature_min') ?? '--'}°'),
            ]),

            // ── PRECIPITATION ─────────────────────────────────────────────────
            _Section(title: 'PRECIPITATION', rows: [
              _Row(Icons.water_drop,    'TOTAL SUM',            '${_d('precipitation_sum')?.toStringAsFixed(1) ?? '--'} mm'),
              _Row(Icons.grain,         'RAIN SUM',             '${_d('rain_sum')?.toStringAsFixed(1) ?? '--'} mm'),
              _Row(Icons.shower,        'SHOWERS SUM',          '${_d('showers_sum')?.toStringAsFixed(1) ?? '--'} mm'),
              _Row(Icons.ac_unit,       'SNOWFALL SUM',         '${_d('snowfall_sum')?.toStringAsFixed(1) ?? '--'} cm'),
              _Row(Icons.schedule,      'PRECIPITATION HOURS',  '${_d('precipitation_hours')?.toStringAsFixed(1) ?? '--'} h'),
              _Row(Icons.percent,       'PROBABILITY MAX',      '${_i('precipitation_probability_max') ?? '--'}%'),
              _Row(Icons.percent,       'PROBABILITY MEAN',     '${_i('precipitation_probability_mean') ?? '--'}%'),
              _Row(Icons.percent,       'PROBABILITY MIN',      '${_i('precipitation_probability_min') ?? '--'}%'),
            ]),

            // ── WIND ─────────────────────────────────────────────────────────
            _Section(title: 'WIND', rows: [
              _Row(Icons.air,           'MAX SPEED @ 10 m',     '${_i('wind_speed_10m_max') ?? '--'} km/h'),
              _Row(Icons.storm,         'MAX GUSTS @ 10 m',     '${_i('wind_gusts_10m_max') ?? '--'} km/h'),
              _Row(Icons.explore,       'DOMINANT DIRECTION',   _windDir(_d('wind_direction_10m_dominant'))),
            ]),

            // ── HUMIDITY & ATMOSPHERE ─────────────────────────────────────────
            _Section(title: 'HUMIDITY & ATMOSPHERE', rows: [
              _Row(Icons.water,         'HUMIDITY MAX',         '${_i('relative_humidity_2m_max') ?? '--'}%'),
              _Row(Icons.compress,      'SURFACE PRESSURE MEAN', '${_i('surface_pressure_mean') ?? '--'} hPa'),
            ]),

            // ── EVAPOTRANSPIRATION ────────────────────────────────────────────
            _Section(title: 'EVAPOTRANSPIRATION & SOIL', rows: [
              _Row(Icons.eco,           'ET₀ FAO-56',           '${_d('et0_fao_evapotranspiration')?.toStringAsFixed(2) ?? '--'} mm/day'),
            ]),

          ],
        ),
      ),
    );
  }

  // ── Formatters ──────────────────────────────────────────────────────────────

  static String _duration(int? seconds) {
    if (seconds == null) return '--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static String _windDir(double? deg) {
    if (deg == null) return '--';
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final label = dirs[((deg + 11.25) % 360 / 22.5).floor() % 16];
    return '${deg.round()}° $label';
  }
}

// ─── Layout widgets ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return TechnicalCard(
      title: title,
      child: Column(
        children: rows
            .map((r) => TechnicalDataRow(icon: r.icon, label: r.label, value: r.value))
            .toList(),
      ),
    );
  }
}

class _Row {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);
}