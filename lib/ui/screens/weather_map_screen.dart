import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:weather/data/weather_providers.dart';


import 'dart:io' show Platform;

// ─── Domains ──────────────────────────────────────────────────────────────────

enum MapDomain {
  best('best_match', 'BEST MATCH'),
  ecmwf('ecmwf_ifs025', 'ECMWF IFS'),
  ukmo('ukmo_global_deterministic_10km', 'UKMO'),
  gfs('gfs_seamless', 'GFS'),
  icon('icon_seamless', 'ICON'),
  gem('gem_seamless', 'GEM'),
  meteofrance('meteofrance_seamless', 'MÉTÉO-FRANCE');

  final String code;
  final String label;
  const MapDomain(this.code, this.label);
}

// ─── Variables ────────────────────────────────────────────────────────────────

enum WeatherVariable {
  temperature(
      'temperature_2m', 'TEMPERATURE', Icons.thermostat, Color(0xFFA6755B)),
  precipitation('precipitation', 'PRECIP', Icons.water_drop, Colors.blueAccent),
  rain('rain', 'RAIN', Icons.grain, Color(0xFF5B8FA6)),
  snowfall('snowfall', 'SNOWFALL', Icons.ac_unit, Colors.white70),
  windSpeed('wind_speed_10m', 'WIND 10M', Icons.air, Color(0xFF6E8473)),
  windGusts('wind_gusts_10m', 'GUSTS', Icons.storm, Color(0xFF9B7D5D)),
  cape('cape', 'CAPE', Icons.bolt, Color(0xFFB49B6B)),
  cloudCover('cloud_cover', 'CLOUDS', Icons.cloud, Colors.white60),
  pressure('pressure_msl', 'PRESSURE', Icons.compress, Colors.purpleAccent),
  dewPoint('dew_point_2m', 'DEW POINT', Icons.water, Color(0xFF6EA8B0)),
  humidity(
      'relative_humidity_2m', 'HUMIDITY', Icons.opacity, Color(0xFF7AA8B0)),
  uvIndex('uv_index', 'UV INDEX', Icons.wb_sunny, Color(0xFFD4A94B)),
  soilTemp('soil_temperature_6cm', 'SOIL TEMP', Icons.grass, Color(0xFF8B6B4A)),
  snowDepth('snow_depth', 'SNOW DEPTH', Icons.layers, Color(0xFFB0D4E8)),
  visibility('visibility', 'VISIBILITY', Icons.visibility, Color(0xFF7B9EA6));

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  const WeatherVariable(this.code, this.label, this.icon, this.color);
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _activeDomainProvider = StateProvider<MapDomain>((ref) => MapDomain.best);
final _activeVariableProvider =
    StateProvider<WeatherVariable>((ref) => WeatherVariable.temperature);
final _timeOffsetProvider = StateProvider<int>((ref) => 0);

// ─── Root screen — splits on platform ────────────────────────────────────────

class WeatherMapScreen extends ConsumerWidget {
  const WeatherMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // kIsWeb is a compile-time constant — zero runtime cost
    final bool useRedirect =
        kIsWeb || (!kIsWeb && (Platform.isLinux || Platform.isWindows));

    if (useRedirect) {
      return const _WebRedirectMap();
    }
    return const _NativeMapView();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEB — redirect card
// ═══════════════════════════════════════════════════════════════════════════════

class _WebRedirectMap extends ConsumerWidget {
  const _WebRedirectMap();

  static String _buildUrl({
    required String domain,
    required String variable,
    required int offsetHours,
    required double lat,
    required double lon,
  }) {
    final t = DateTime.now().toUtc().add(Duration(hours: offsetHours));
    final rounded = DateTime.utc(t.year, t.month, t.day, t.hour);
    final timeParam =
        '${DateFormat('yyyy-MM-dd').format(rounded)}T${rounded.hour.toString().padLeft(2, '0')}00';

    // Hash fragment = MapLibre deep-link: #zoom/lat/lon
    return 'https://maps.open-meteo.com/'
        '?domain=$domain'
        '&variable=$variable'
        '&time=$timeParam'
        '#5/$lat/$lon';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(currentCityProvider);
    final domain = ref.watch(_activeDomainProvider);
    final variable = ref.watch(_activeVariableProvider);
    final offset = ref.watch(_timeOffsetProvider);

    final url = _buildUrl(
      domain: domain.code,
      variable: variable.code,
      offsetHours: offset,
      lat: city.latitude,
      lon: city.longitude,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B24),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: Column(children: [
            // ── TOP BAR ─────────────────────────────────────────────────────
            Padding(
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
                          width: 3, height: 14, color: const Color(0xFF6E8473)),
                      const SizedBox(width: 10),
                      Column(
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
                          const Text(
                            'WEB PLATFORM  ·  EXTERNAL RENDERER',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 9,
                                letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── SELECTORS (so user can configure before launching) ───────────
            _VariableSelector(
                activeVariable: variable, ref: ref, compact: true),
            const SizedBox(height: 4),
            _DomainSelector(activeDomain: domain, ref: ref, horizontal: true),
            const SizedBox(height: 4),
            _TimeScrubber(offset: offset, ref: ref),

            const Spacer(),

            // ── REDIRECT CARD ────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                border: Border.all(color: const Color(0xFF6E8473), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 4, height: 16, color: const Color(0xFF6E8473)),
                    const SizedBox(width: 12),
                    const Text(
                      'WEATHER MAP',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'The interactive weather map uses Open-Meteo\'s WebGL '
                    'renderer which requires a native browser environment. '
                    'The map will open pre-configured with your current '
                    'settings — ${variable.label.toLowerCase()}, '
                    '${domain.label}, centred on ${city.name}.',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 8),

                  // URL preview
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.black38,
                    child: Text(
                      url,
                      style: const TextStyle(
                          color: Color(0xFF6E8473),
                          fontSize: 9,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Launch button
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(url);
                        try {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF1F2A31),
                                content: Text(
                                  'Could not open browser: $e',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E8473).withAlpha(38),
                          border: Border.all(color: const Color(0xFF6E8473)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new,
                                color: Color(0xFF6E8473), size: 16),
                            SizedBox(width: 10),
                            Text(
                              'OPEN IN OPEN-METEO MAPS',
                              style: TextStyle(
                                  color: Color(0xFF6E8473),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NATIVE (Android / iOS) — WebView embedding maps.open-meteo.com
// ═══════════════════════════════════════════════════════════════════════════════

class _NativeMapView extends ConsumerStatefulWidget {
  const _NativeMapView();

  @override
  ConsumerState<_NativeMapView> createState() => _NativeMapViewState();
}

class _NativeMapViewState extends ConsumerState<_NativeMapView> {
  late final WebViewController _webCtrl;
  bool _loading = true;

  static String _buildUrl({
    required String domain,
    required String variable,
    required int offsetHours,
    required double lat,
    required double lon,
  }) {
    final t = DateTime.now().toUtc().add(Duration(hours: offsetHours));
    final rounded = DateTime.utc(t.year, t.month, t.day, t.hour);
    final timeParam =
        '${DateFormat('yyyy-MM-dd').format(rounded)}T${rounded.hour.toString().padLeft(2, '0')}00';
    return 'https://maps.open-meteo.com/'
        '?domain=$domain'
        '&variable=$variable'
        '&time=$timeParam'
        '#5/$lat/$lon';
  }

  @override
  void initState() {
    super.initState();
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ));
    _loadMap();
  }

  void _loadMap() {
    final city = ref.read(currentCityProvider);
    final domain = ref.read(_activeDomainProvider);
    final variable = ref.read(_activeVariableProvider);
    final offset = ref.read(_timeOffsetProvider);

    _webCtrl.loadRequest(Uri.parse(_buildUrl(
      domain: domain.code,
      variable: variable.code,
      offsetHours: offset,
      lat: city.latitude,
      lon: city.longitude,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final domain = ref.watch(_activeDomainProvider);
    final variable = ref.watch(_activeVariableProvider);
    final offset = ref.watch(_timeOffsetProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B24),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Column(children: [
          // ── TOP BAR ───────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
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
                          width: 3, height: 14, color: const Color(0xFF6E8473)),
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
                      // Reload button — re-navigates with updated params
                      GestureDetector(
                        onTap: _loadMap,
                        child: const Icon(Icons.refresh,
                            color: Colors.white38, size: 18),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── SELECTOR STRIP ────────────────────────────────────────────────
          _VariableSelector(activeVariable: variable, ref: ref, compact: false),

          // ── WEBVIEW ───────────────────────────────────────────────────────
          Expanded(
            child: Stack(children: [
              WebViewWidget(controller: _webCtrl),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6E8473)),
                ),
            ]),
          ),

          // ── TIME SCRUBBER + DOMAIN (above system nav) ─────────────────────
          Container(
            color: Colors.black.withAlpha(204),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _TimeScrubber(offset: offset, ref: ref),
              _DomainSelector(activeDomain: domain, ref: ref, horizontal: true),
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Shared UI widgets ────────────────────────────────────────────────────────

class _VariableSelector extends StatelessWidget {
  final WeatherVariable activeVariable;
  final WidgetRef ref;
  final bool compact;
  const _VariableSelector(
      {required this.activeVariable, required this.ref, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(204),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: WeatherVariable.values.map((v) {
            final isActive = v == activeVariable;
            return GestureDetector(
              onTap: () {
                ref.read(_activeVariableProvider.notifier).state = v;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 6),
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10, vertical: compact ? 6 : 8),
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
                        size: compact ? 14 : 16),
                    const SizedBox(height: 3),
                    Text(v.label,
                        style: TextStyle(
                            color: isActive ? v.color : Colors.white38,
                            fontSize: compact ? 7 : 7,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
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

class _DomainSelector extends StatelessWidget {
  final MapDomain activeDomain;
  final WidgetRef ref;
  final bool horizontal;
  const _DomainSelector(
      {required this.activeDomain,
      required this.ref,
      required this.horizontal});

  @override
  Widget build(BuildContext context) {
    final items = MapDomain.values.map((d) {
      final isActive = d == activeDomain;
      return GestureDetector(
        onTap: () => ref.read(_activeDomainProvider.notifier).state = d,
        child: Container(
          margin: horizontal
              ? const EdgeInsets.only(right: 6)
              : const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6E8473).withAlpha(51)
                : Colors.transparent,
            border: Border.all(
              color: isActive ? const Color(0xFF6E8473) : Colors.white12,
              width: isActive ? 1.5 : 1,
            ),
          ),
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
    }).toList();

    return Container(
      color: Colors.black.withAlpha(178),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: horizontal
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                const Text('MODEL  ',
                    style: TextStyle(
                        color: Color(0xFF6E8473),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                ...items,
              ]),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: items),
    );
  }
}

class _TimeScrubber extends StatelessWidget {
  final int offset;
  final WidgetRef ref;
  const _TimeScrubber({required this.offset, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Container(width: 3, height: 10, color: const Color(0xFF6E8473)),
        const SizedBox(width: 8),
        const Text('TIME',
            style: TextStyle(
                color: Color(0xFF6E8473),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF6E8473),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF6E8473),
              overlayColor: const Color(0xFF6E8473).withAlpha(40),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: offset.toDouble(),
              min: -24,
              max: 240,
              divisions: 88, // every 3h
              onChanged: (v) {
                final snapped = (v / 3).round() * 3;
                ref.read(_timeOffsetProvider.notifier).state = snapped;
              },
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            offset == 0
                ? 'NOW'
                : offset > 0
                    ? '+${offset}h'
                    : '${offset}h',
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
}

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
