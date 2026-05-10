import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:weather/data/weather_providers.dart';

// ─── Available weather model domains ─────────────────────────────────────────
// These match the ?domain= parameter on maps.open-meteo.com
enum MapDomain {
  best(       'best_match',                         'BEST MATCH'),
  ecmwf(      'ecmwf_ifs025',                       'ECMWF IFS'),
  ukmo(       'ukmo_global_deterministic_10km',     'UKMO'),
  gfs(        'gfs_seamless',                       'GFS'),
  icon(       'icon_seamless',                      'ICON'),
  gem(        'gem_seamless',                       'GEM'),
  meteofrance('meteofrance_seamless',               'MÉTÉO-FRANCE');

  final String code;
  final String label;
  const MapDomain(this.code, this.label);
}

// ─── Available overlay variables ─────────────────────────────────────────────
// These match the ?variable= parameter on maps.open-meteo.com
enum WeatherVariable {
  temperature(    'temperature_2m',             'TEMPERATURE',   Icons.thermostat,         Color(0xFFA6755B)),
  precipitation(  'precipitation',              'PRECIPITATION', Icons.water_drop,          Colors.blueAccent),
  rain(           'rain',                       'RAIN',          Icons.grain,               Color(0xFF5B8FA6)),
  snowfall(       'snowfall',                   'SNOWFALL',      Icons.ac_unit,             Colors.white70),
  windSpeed(      'wind_speed_10m',             'WIND 10M',      Icons.air,                 Color(0xFF6E8473)),
  windSpeed80m(   'wind_speed_80m',             'WIND 80M',      Icons.air,                 Color(0xFF8EA693)),
  windGusts(      'wind_gusts_10m',             'WIND GUSTS',    Icons.storm,               Color(0xFF9B7D5D)),
  cape(           'cape',                       'CAPE',          Icons.bolt,                Color(0xFFB49B6B)),
  cloudCover(     'cloud_cover',                'CLOUD COVER',   Icons.cloud,               Colors.white60),
  pressure(       'pressure_msl',               'PRESSURE MSL',  Icons.compress,            Colors.purpleAccent),
  dewPoint(       'dew_point_2m',               'DEW POINT',     Icons.water,               Color(0xFF6EA8B0)),
  humidity(       'relative_humidity_2m',       'HUMIDITY',      Icons.opacity,             Color(0xFF7AA8B0)),
  uvIndex(        'uv_index',                   'UV INDEX',      Icons.wb_sunny,            Color(0xFFD4A94B)),
  soilTemp(       'soil_temperature_6cm',       'SOIL TEMP',     Icons.grass,               Color(0xFF8B6B4A)),
  snowDepth(      'snow_depth',                 'SNOW DEPTH',    Icons.layers,              Color(0xFFB0D4E8)),
  visibility(     'visibility',                 'VISIBILITY',    Icons.visibility,          Color(0xFF7B9EA6));

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  const WeatherVariable(this.code, this.label, this.icon, this.color);
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _activeDomainProvider   = StateProvider<MapDomain>((ref)       => MapDomain.best);
final _activeVariableProvider = StateProvider<WeatherVariable>((ref) => WeatherVariable.temperature);
final _overlayOpacityProvider = StateProvider<double>((ref)          => 0.75);

// Tracks the selected forecast time offset in hours from now (0 = current)
final _timeOffsetProvider = StateProvider<int>((ref) => 0);

// ─── Screen ───────────────────────────────────────────────────────────────────

class WeatherMapScreen extends ConsumerWidget {
  const WeatherMapScreen({super.key});

  // Builds the ISO timestamp used by Open-Meteo maps tiles
  // Format: YYYY-MM-DDTHHMM  e.g. 2026-05-10T0600
  static String _buildTimeParam(int offsetHours) {
    final t = DateTime.now().toUtc().add(Duration(hours: offsetHours));
    // Round down to nearest hour
    final rounded = DateTime.utc(t.year, t.month, t.day, t.hour);
    final date = DateFormat('yyyy-MM-dd').format(rounded);
    final hour = rounded.hour.toString().padLeft(2, '0');
    return '${date}T${hour}00';
  }

  // Open-Meteo tile URL template
  static String _tileUrl(MapDomain domain, WeatherVariable variable, int offsetHours) {
    final time = _buildTimeParam(offsetHours);
    return 'https://maps.open-meteo.com/tiles/'
           '${domain.code}/${variable.code}/$time/{z}/{x}/{y}.png';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city       = ref.watch(currentCityProvider);
    final domain     = ref.watch(_activeDomainProvider);
    final variable   = ref.watch(_activeVariableProvider);
    final opacity    = ref.watch(_overlayOpacityProvider);
    final offset     = ref.watch(_timeOffsetProvider);
    final center     = LatLng(city.latitude, city.longitude);
    final mapCtrl    = MapController();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B24),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Stack(children: [

          // ── MAP ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: mapCtrl,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 5.5,
              minZoom: 2.0,
              maxZoom: 10.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [

              // 1. Base — Carto dark (no key required)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.weather',
                retinaMode: true,
              ),

              // 2. Open-Meteo weather overlay
              Opacity(
                opacity: opacity,
                child: TileLayer(
                  key: ValueKey('$domain-$variable-$offset'), // force rebuild on change
                  urlTemplate: _tileUrl(domain, variable, offset),
                  userAgentPackageName: 'com.example.weather',
                  tileProvider: NetworkTileProvider(),
                  errorTileCallback: (tile, error, _) {
                    // Silently swallow missing tiles — not all domains have all variables
                  },
                ),
              ),

              // 3. City pin
              MarkerLayer(markers: [
                Marker(
                  point: center,
                  width: 140,
                  height: 60,
                  child: _CityMarker(cityName: city.name),
                ),
              ]),

              // 4. Attribution (required by OSM ToS)
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© CartoDB'),
                  TextSourceAttribution('© OpenStreetMap contributors'),
                  TextSourceAttribution('Weather tiles © Open-Meteo'),
                ],
              ),
            ],
          ),

          // ── TOP BAR ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                _MapButton(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(178),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(children: [
                      Container(
                          width: 3,
                          height: 14,
                          color: const Color(0xFF6E8473)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${variable.label}  ·  ${domain.label}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5),
                            ),
                            Text(
                              offset == 0
                                  ? 'CURRENT'
                                  : offset > 0
                                      ? '+${offset}H FORECAST'
                                      : '${offset}H PAST',
                              style: TextStyle(
                                  color: variable.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5),
                            ),
                          ],
                        ),
                      ),
                      // Re-centre button
                      GestureDetector(
                        onTap: () => mapCtrl.move(center, 5.5),
                        child: const Icon(Icons.my_location,
                            color: Colors.white54, size: 18),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── DOMAIN SELECTOR (top-right pill) ──────────────────────────────
          Positioned(
            top: 90,
            right: 12,
            child: _DomainSelector(activeDomain: domain, ref: ref),
          ),

          // ── OPACITY SLIDER (right side) ────────────────────────────────────
          Positioned(
            right: 12,
            top: 240,
            child: _OpacitySlider(opacity: opacity, ref: ref),
          ),

          // ── TIME SCRUBBER (above variable selector) ────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 130,
            child: _TimeScrubber(offset: offset, ref: ref),
          ),

          // ── VARIABLE SELECTOR (bottom) ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _VariableSelector(activeVariable: variable, ref: ref),
          ),
        ]),
      ),
    );
  }
}

// ─── City Marker ──────────────────────────────────────────────────────────────

class _CityMarker extends StatelessWidget {
  final String cityName;
  const _CityMarker({required this.cityName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(210),
            border: Border.all(color: const Color(0xFF6E8473), width: 1.5),
          ),
          child: Text(
            cityName.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2),
          ),
        ),
        Container(width: 2, height: 8, color: const Color(0xFF6E8473)),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Color(0xFF6E8473), shape: BoxShape.circle),
        ),
      ],
    );
  }
}

// ─── Domain Selector ──────────────────────────────────────────────────────────

class _DomainSelector extends StatelessWidget {
  final MapDomain activeDomain;
  final WidgetRef ref;
  const _DomainSelector({required this.activeDomain, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(204),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12))),
            child: const Text('MODEL',
                style: TextStyle(
                    color: Color(0xFF6E8473),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ),
          ...MapDomain.values.map((d) {
            final isActive = d == activeDomain;
            return GestureDetector(
              onTap: () =>
                  ref.read(_activeDomainProvider.notifier).state = d,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                color: isActive
                    ? const Color(0xFF6E8473).withAlpha(51)
                    : Colors.transparent,
                child: Text(
                  d.label,
                  style: TextStyle(
                      color: isActive ? const Color(0xFF6E8473) : Colors.white38,
                      fontSize: 9,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 1),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Variable Selector ────────────────────────────────────────────────────────

class _VariableSelector extends StatelessWidget {
  final WeatherVariable activeVariable;
  final WidgetRef ref;
  const _VariableSelector(
      {required this.activeVariable, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(217),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: WeatherVariable.values.map((v) {
            final isActive = v == activeVariable;
            return GestureDetector(
              onTap: () =>
                  ref.read(_activeVariableProvider.notifier).state = v,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? v.color.withAlpha(38) : Colors.transparent,
                  border: Border.all(
                    color: isActive ? v.color : Colors.white24,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(v.icon,
                        color: isActive ? v.color : Colors.white38,
                        size: 16),
                    const SizedBox(height: 3),
                    Text(
                      v.label,
                      style: TextStyle(
                          color: isActive ? v.color : Colors.white38,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Time Scrubber ────────────────────────────────────────────────────────────

class _TimeScrubber extends StatelessWidget {
  final int offset;   // hours from now
  final WidgetRef ref;
  const _TimeScrubber({required this.offset, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(204),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
                width: 3, height: 10, color: const Color(0xFF6E8473)),
            const SizedBox(width: 8),
            const Text('FORECAST TIME',
                style: TextStyle(
                    color: Color(0xFF6E8473),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const Spacer(),
            Text(
              offset == 0
                  ? 'NOW'
                  : offset > 0
                      ? '+${offset}h'
                      : '${offset}h',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1),
            ),
          ]),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF6E8473),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF6E8473),
              overlayColor: const Color(0xFF6E8473).withAlpha(40),
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: offset.toDouble(),
              min: -24,
              max: 240,   // 10 days forward
              divisions: 264,
              onChanged: (v) {
                // Snap to nearest 3h to avoid excessive tile requests
                final snapped = (v / 3).round() * 3;
                ref.read(_timeOffsetProvider.notifier).state = snapped;
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('-24h', style: TextStyle(color: Colors.white24, fontSize: 8)),
              Text('NOW',  style: TextStyle(color: Colors.white38, fontSize: 8)),
              Text('+10d', style: TextStyle(color: Colors.white24, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Opacity Slider ───────────────────────────────────────────────────────────

class _OpacitySlider extends StatelessWidget {
  final double opacity;
  final WidgetRef ref;
  const _OpacitySlider({required this.opacity, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(204),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LAYER',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF6E8473),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF6E8473),
                  overlayColor: const Color(0xFF6E8473).withAlpha(40),
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                ),
                child: Slider(
                  value: opacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (v) =>
                      ref.read(_overlayOpacityProvider.notifier).state = v,
                ),
              ),
            ),
          ),
          Text(
            '${(opacity * 100).round()}%',
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 8,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Map Button ───────────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _MapButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(178),
          border: Border.all(color: Colors.white12),
        ),
        child: child,
      ),
    );
  }
}