import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:weather/core/weather_mapper.dart';
import 'package:weather/ui/widgets/weather_components.dart';

class HourlyDetailScreen extends StatelessWidget {
  final Map<String, dynamic> hourly; // full hourly map
  final int index;                   // the specific hour index within hourly arrays
  final String cityName;

  const HourlyDetailScreen({
    super.key,
    required this.hourly,
    required this.index,
    required this.cityName,
  });

  // Safe accessor — returns null if key missing or index out of range
  T? _get<T>(String key) {
    final list = hourly[key];
    if (list == null || index >= (list as List).length) return null;
    final val = list[index];
    if (val == null) return null;
    return val as T;
  }

  double? _d(String key) {
    final v = _get<num>(key);
    return v?.toDouble();
  }

  int? _i(String key) {
    final v = _get<num>(key);
    return v?.round();
  }

  String? _s(String key) => _get<String>(key);

  @override
  Widget build(BuildContext context) {
    final timeStr = _s('time') ?? '';
    final dt = timeStr.isNotEmpty ? DateTime.parse(timeStr) : DateTime.now();
    final timeLabel = DateFormat('EEE, MMM d · HH:mm').format(dt);
    final hCode = _i('weather_code') ?? 0;
    final isDay = (_i('is_day') ?? 1) == 1;

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
              timeLabel.toUpperCase(),
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
                    WeatherMapper.getIcon(hCode, isDay),
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
                      const SizedBox(height: 4),
                      Text(
                        '${_i('temperature_2m') ?? '--'}°',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w200,
                            height: 1.0,
                            letterSpacing: -2),
                      ),
                      Text(
                        'FEELS LIKE ${_i('apparent_temperature') ?? '--'}°',
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── TEMPERATURE & HUMIDITY ───────────────────────────────────────
            _Section(title: 'TEMPERATURE & HUMIDITY', rows: [
              _Row(Icons.thermostat,           'TEMPERATURE',             '${_i('temperature_2m') ?? '--'}°'),
              _Row(Icons.device_thermostat,    'FEELS LIKE',              '${_i('apparent_temperature') ?? '--'}°'),
              _Row(Icons.water,                'RELATIVE HUMIDITY',       '${_i('relative_humidity_2m') ?? '--'}%'),
              _Row(Icons.blur_on,              'DEW POINT',               '${_i('dew_point_2m') ?? '--'}°'),
              _Row(Icons.science,              'VAPOUR PRESSURE DEFICIT', _vpd(_d('vapour_pressure_deficit'))),
            ]),

            // ── PRECIPITATION ─────────────────────────────────────────────────
            _Section(title: 'PRECIPITATION', rows: [
              _Row(Icons.water_drop,           'PROBABILITY',             '${_i('precipitation_probability') ?? '--'}%'),
              _Row(Icons.cloudy_snowing,       'TOTAL',                   '${_d('precipitation')?.toStringAsFixed(2) ?? '--'} mm'),
              _Row(Icons.grain,                'RAIN',                    '${_d('rain')?.toStringAsFixed(2) ?? '--'} mm'),
              _Row(Icons.shower,               'SHOWERS',                 '${_d('showers')?.toStringAsFixed(2) ?? '--'} mm'),
              _Row(Icons.ac_unit,              'SNOWFALL',                '${_d('snowfall')?.toStringAsFixed(2) ?? '--'} cm'),
              _Row(Icons.layers,               'SNOW DEPTH',              _snowDepth(_d('snow_depth'))),
              _Row(Icons.height,               'FREEZING LEVEL',          _freezingLevel(_d('freezing_level_height'))),
            ]),

            // ── WIND ─────────────────────────────────────────────────────────
            _Section(title: 'WIND', rows: [
              _Row(Icons.air,                  'SPEED @ 10 m',            '${_i('wind_speed_10m') ?? '--'} km/h'),
              _Row(Icons.air,                  'SPEED @ 80 m',            '${_i('wind_speed_80m') ?? '--'} km/h'),
              _Row(Icons.air,                  'SPEED @ 120 m',           '${_i('wind_speed_120m') ?? '--'} km/h'),
              _Row(Icons.air,                  'SPEED @ 180 m',           '${_i('wind_speed_180m') ?? '--'} km/h'),
              _Row(Icons.explore,              'DIRECTION @ 10 m',        _windDir(_d('wind_direction_10m'))),
              _Row(Icons.explore,              'DIRECTION @ 80 m',        _windDir(_d('wind_direction_80m'))),
              _Row(Icons.explore,              'DIRECTION @ 120 m',       _windDir(_d('wind_direction_120m'))),
              _Row(Icons.explore,              'DIRECTION @ 180 m',       _windDir(_d('wind_direction_180m'))),
              _Row(Icons.storm,                'GUSTS @ 10 m',            '${_i('wind_gusts_10m') ?? '--'} km/h'),
            ]),

            // ── CLOUD COVER ──────────────────────────────────────────────────
            _Section(title: 'CLOUD COVER', rows: [
              _Row(Icons.cloud,                'TOTAL',                   '${_i('cloud_cover') ?? '--'}%'),
              _Row(Icons.cloud_queue,          'LOW CLOUD (< 3 km)',      '${_i('cloud_cover_low') ?? '--'}%'),
              _Row(Icons.cloud_queue,          'MID CLOUD (3–8 km)',      '${_i('cloud_cover_mid') ?? '--'}%'),
              _Row(Icons.cloud_queue,          'HIGH CLOUD (> 8 km)',     '${_i('cloud_cover_high') ?? '--'}%'),
            ]),

            // ── RADIATION & SOLAR ─────────────────────────────────────────────
            _Section(title: 'RADIATION & SOLAR', rows: [
              _Row(Icons.wb_sunny,             'UV INDEX',                _d('uv_index')?.toStringAsFixed(1) ?? '--'),
              _Row(Icons.wb_sunny_outlined,    'UV INDEX (CLEAR SKY)',    _d('uv_index_clear_sky')?.toStringAsFixed(1) ?? '--'),
              _Row(Icons.brightness_5,         'SHORTWAVE RADIATION',     '${_i('shortwave_radiation') ?? '--'} W/m²'),
              _Row(Icons.brightness_7,         'DIRECT RADIATION',        '${_i('direct_radiation') ?? '--'} W/m²'),
              _Row(Icons.brightness_4,         'DIFFUSE RADIATION',       '${_i('diffuse_radiation') ?? '--'} W/m²'),
              _Row(Icons.highlight,            'DIRECT NORMAL IRR.',      '${_i('direct_normal_irradiance') ?? '--'} W/m²'),
            ]),

            // ── SOIL ─────────────────────────────────────────────────────────
            _Section(title: 'SOIL', rows: [
              _Row(Icons.thermostat,           'TEMP @ 0 cm',             '${_d('soil_temperature_0cm')?.toStringAsFixed(1) ?? '--'}°'),
              _Row(Icons.thermostat,           'TEMP @ 6 cm',             '${_d('soil_temperature_6cm')?.toStringAsFixed(1) ?? '--'}°'),
              _Row(Icons.thermostat,           'TEMP @ 18 cm',            '${_d('soil_temperature_18cm')?.toStringAsFixed(1) ?? '--'}°'),
              _Row(Icons.thermostat,           'TEMP @ 54 cm',            '${_d('soil_temperature_54cm')?.toStringAsFixed(1) ?? '--'}°'),
              _Row(Icons.water_drop,           'MOISTURE 0–1 cm',         _soilMoisture(_d('soil_moisture_0_to_1cm'))),
              _Row(Icons.water_drop,           'MOISTURE 1–3 cm',         _soilMoisture(_d('soil_moisture_1_to_3cm'))),
              _Row(Icons.water_drop,           'MOISTURE 3–9 cm',         _soilMoisture(_d('soil_moisture_3_to_9cm'))),
              _Row(Icons.water_drop,           'MOISTURE 9–27 cm',        _soilMoisture(_d('soil_moisture_9_to_27cm'))),
              _Row(Icons.water_drop,           'MOISTURE 27–81 cm',       _soilMoisture(_d('soil_moisture_27_to_81cm'))),
            ]),

            // ── ATMOSPHERE & STABILITY ────────────────────────────────────────
            _Section(title: 'ATMOSPHERE & STABILITY', rows: [
              _Row(Icons.compress,             'PRESSURE (MSL)',          '${_i('pressure_msl') ?? '--'} hPa'),
              _Row(Icons.compress,             'SURFACE PRESSURE',        '${_i('surface_pressure') ?? '--'} hPa'),
              _Row(Icons.bolt,                 'CAPE',                    _cape(_d('cape'))),
              _Row(Icons.straighten,           'ET₀ (FAO-56)',            '${_d('et0_fao_evapotranspiration')?.toStringAsFixed(2) ?? '--'} mm'),
              _Row(Icons.eco,                  'EVAPOTRANSPIRATION',      '${_d('evapotranspiration')?.toStringAsFixed(2) ?? '--'} mm'),
              _Row(Icons.visibility,           'VISIBILITY',              _visibility(_d('visibility'))),
            ]),

          ],
        ),
      ),
    );
  }

  // ── Value formatters ─────────────────────────────────────────────────────────

  static String _windDir(double? deg) {
    if (deg == null) return '--';
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final label = dirs[((deg + 11.25) % 360 / 22.5).floor() % 16];
    return '${deg.round()}° $label';
  }

  static String _vpd(double? kPa) {
    if (kPa == null) return '--';
    final label = kPa < 0.4 ? 'LOW' : kPa < 0.8 ? 'MODERATE' : kPa < 1.6 ? 'HIGH' : 'VERY HIGH';
    return '${kPa.toStringAsFixed(2)} kPa  ($label)';
  }

  static String _cape(double? j) {
    if (j == null) return '--';
    final label = j < 300 ? 'STABLE' : j < 1000 ? 'MARGINAL' : j < 2500 ? 'MODERATE' : 'EXTREME';
    return '${j.round()} J/kg  ($label)';
  }

  static String _freezingLevel(double? m) {
    if (m == null) return '--';
    return '${m.round()} m  (${(m / 1000).toStringAsFixed(1)} km)';
  }

  static String _snowDepth(double? m) {
    if (m == null) return '--';
    return '${(m * 100).round()} cm';
  }

  static String _soilMoisture(double? m3) {
    if (m3 == null) return '--';
    return '${(m3 * 100).toStringAsFixed(1)}% vol.';
  }

  static String _visibility(double? m) {
    if (m == null) return '--';
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
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