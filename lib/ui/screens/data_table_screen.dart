import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:weather/core/weather_mapper.dart';
import 'package:weather/data/weather_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PARAMETER DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

class DailyParam {
  final String key;
  final String label;
  final String unit;
  final bool defaultOn;
  const DailyParam(this.key, this.label, this.unit, {this.defaultOn = false});
}

class HourlyParam {
  final String key;
  final String label;
  final String unit;
  final bool defaultOn;
  const HourlyParam(this.key, this.label, this.unit, {this.defaultOn = false});
}

const List<DailyParam> kAllDailyParams = [
  DailyParam('weather_code',                  'COND',       '',      defaultOn: true),
  DailyParam('temperature_2m_max',            'MAX',        '°',     defaultOn: true),
  DailyParam('temperature_2m_min',            'MIN',        '°',     defaultOn: true),
  DailyParam('apparent_temperature_max',      'FEELS MAX',  '°'),
  DailyParam('apparent_temperature_min',      'FEELS MIN',  '°'),
  DailyParam('precipitation_sum',             'PRECIP',     'mm',    defaultOn: true),
  DailyParam('precipitation_probability_max', 'PRECIP %',   '%',     defaultOn: true),
  DailyParam('rain_sum',                      'RAIN',       'mm'),
  DailyParam('showers_sum',                   'SHOWERS',    'mm'),
  DailyParam('snowfall_sum',                  'SNOWFALL',   'cm'),
  DailyParam('precipitation_hours',           'PRECIP HRS', 'h'),
  DailyParam('wind_speed_10m_max',            'WIND MAX',   'km/h',  defaultOn: true),
  DailyParam('wind_gusts_10m_max',            'GUSTS MAX',  'km/h'),
  DailyParam('wind_direction_10m_dominant',   'WIND DIR',   '°'),
  DailyParam('relative_humidity_2m_max',      'HUM MAX',    '%',     defaultOn: true),
  DailyParam('relative_humidity_2m_min',      'HUM MIN',    '%'),
  DailyParam('surface_pressure_mean',         'PRESSURE',   'hPa',   defaultOn: true),
  DailyParam('uv_index_max',                  'UV MAX',     '',      defaultOn: true),
  DailyParam('uv_index_clear_sky_max',        'UV CLEAR',   ''),
  DailyParam('sunrise',                       'SUNRISE',    '',      defaultOn: true),
  DailyParam('sunset',                        'SUNSET',     '',      defaultOn: true),
  DailyParam('daylight_duration',             'DAYLIGHT',   'h'),
  DailyParam('sunshine_duration',             'SUNSHINE',   'h'),
  DailyParam('shortwave_radiation_sum',       'SOLAR RAD',  'MJ/m²'),
  DailyParam('et0_fao_evapotranspiration',    'EVAPOTRANS', 'mm'),
  DailyParam('cape_max',                      'CAPE MAX',   'J/kg'),
  DailyParam('lifted_index_min',              'LIFT IDX',   'K'),
  DailyParam('freezing_level_height_max',     'FREEZE LVL', 'm'),
];

const List<HourlyParam> kAllHourlyParams = [
  HourlyParam('time',                         'TIME',       '',      defaultOn: true),
  HourlyParam('weather_code',                 'COND',       '',      defaultOn: true),
  HourlyParam('temperature_2m',              'TEMP',       '°',     defaultOn: true),
  HourlyParam('apparent_temperature',         'FEELS',      '°',     defaultOn: true),
  HourlyParam('dew_point_2m',                'DEW PT',     '°'),
  HourlyParam('relative_humidity_2m',         'HUM',        '%',     defaultOn: true),
  HourlyParam('precipitation',                'PRECIP',     'mm',    defaultOn: true),
  HourlyParam('precipitation_probability',    'PRECIP %',   '%',     defaultOn: true),
  HourlyParam('rain',                         'RAIN',       'mm'),
  HourlyParam('showers',                      'SHOWERS',    'mm'),
  HourlyParam('snowfall',                     'SNOWFALL',   'cm'),
  HourlyParam('snow_depth',                   'SNOW DEP',   'm'),
  HourlyParam('wind_speed_10m',              'WIND',       'km/h',  defaultOn: true),
  HourlyParam('wind_speed_80m',              'WIND 80m',   'km/h'),
  HourlyParam('wind_speed_120m',             'WIND 120m',  'km/h'),
  HourlyParam('wind_speed_180m',             'WIND 180m',  'km/h'),
  HourlyParam('wind_direction_10m',          'WIND DIR',   '°'),
  HourlyParam('wind_gusts_10m',              'GUSTS',      'km/h'),
  HourlyParam('pressure_msl',               'PRES MSL',   'hPa',   defaultOn: true),
  HourlyParam('surface_pressure',           'SURF PRES',  'hPa'),
  HourlyParam('cloud_cover',                'CLOUDS',     '%',     defaultOn: true),
  HourlyParam('cloud_cover_low',            'CLD LOW',    '%'),
  HourlyParam('cloud_cover_mid',            'CLD MID',    '%'),
  HourlyParam('cloud_cover_high',           'CLD HIGH',   '%'),
  HourlyParam('visibility',                 'VIS',        'km',    defaultOn: true),
  HourlyParam('uv_index',                   'UV',         ''),
  HourlyParam('uv_index_clear_sky',         'UV CLEAR',   ''),
  HourlyParam('cape',                       'CAPE',       'J/kg'),
  HourlyParam('lifted_index',               'LIFT IDX',   'K'),
  HourlyParam('freezing_level_height',      'FREEZE LVL', 'm'),
  HourlyParam('shortwave_radiation',        'SW RAD',     'W/m²'),
  HourlyParam('direct_radiation',           'DIR RAD',    'W/m²'),
  HourlyParam('diffuse_radiation',          'DIFF RAD',   'W/m²'),
  HourlyParam('direct_normal_irradiance',   'DNI',        'W/m²'),
  HourlyParam('et0_fao_evapotranspiration', 'EVAPOTRANS', 'mm'),
  HourlyParam('soil_temperature_6cm',       'SOIL TEMP',  '°'),
  HourlyParam('soil_moisture_3_9cm',        'SOIL MOIST', 'm³/m³'),
  HourlyParam('is_day',                     'DAY/NIGHT',  ''),
];

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

final selectedDailyParamsProvider = StateProvider<Set<String>>((ref) {
  return kAllDailyParams.where((p) => p.defaultOn).map((p) => p.key).toSet();
});

final selectedHourlyParamsProvider = StateProvider<Set<String>>((ref) {
  return kAllHourlyParams.where((p) => p.defaultOn).map((p) => p.key).toSet();
});

final _expandedDayProvider = StateProvider<int>((ref) => -1);

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class DataTableScreen extends ConsumerWidget {
  const DataTableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherRequestProvider);
    final cityName = ref.watch(currentCityProvider).name;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1217),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: Column(children: [
            _Header(cityName: cityName),
            Expanded(
              child: weatherAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6E8473))),
                error: (e, _) => Center(
                    child: Text('ERROR: $e',
                        style: const TextStyle(color: Colors.red))),
                data: (data) => _TableBody(
                  daily: data['daily'] as Map,
                  hourly: data['hourly'] as Map,
                ),
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

class _Header extends ConsumerWidget {
  final String cityName;
  const _Header({required this.cityName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.black,
        border:
            Border(bottom: BorderSide(color: Color(0xFF6E8473), width: 1)),
      ),
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
              Text(cityName.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const Text('RAW DATA TABLE  ·  16-DAY FORECAST',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      letterSpacing: 1.5)),
            ],
          ),
        ),
        _ConfigButton(
          label: 'DAILY COLS',
          onTap: () => _showColumnPicker(
            context, ref,
            params: kAllDailyParams
                .map((p) =>
                    _ParamToggle(key: p.key, label: p.label, unit: p.unit))
                .toList(),
            selectedProvider: selectedDailyParamsProvider,
            title: 'DAILY COLUMNS',
          ),
        ),
        const SizedBox(width: 8),
        _ConfigButton(
          label: 'HOURLY COLS',
          onTap: () => _showColumnPicker(
            context, ref,
            params: kAllHourlyParams
                .map((p) =>
                    _ParamToggle(key: p.key, label: p.label, unit: p.unit))
                .toList(),
            selectedProvider: selectedHourlyParamsProvider,
            title: 'HOURLY COLUMNS',
          ),
        ),
      ]),
    );
  }

  static void _showColumnPicker(
    BuildContext context,
    WidgetRef ref, {
    required List<_ParamToggle> params,
    required StateProvider<Set<String>> selectedProvider,
    required String title,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111A20),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => _ColumnPickerSheet(
        params: params,
        selectedProvider: selectedProvider,
        title: title,
        ref: ref,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _ConfigButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ConfigButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF6E8473)),
          color: const Color(0xFF6E8473).withAlpha(25),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.tune, color: Color(0xFF6E8473), size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6E8473),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLUMN PICKER SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _ParamToggle {
  final String key;
  final String label;
  final String unit;
  const _ParamToggle(
      {required this.key, required this.label, required this.unit});
}

class _ColumnPickerSheet extends ConsumerWidget {
  final List<_ParamToggle> params;
  final StateProvider<Set<String>> selectedProvider;
  final String title;
  final WidgetRef ref;

  const _ColumnPickerSheet({
    required this.params,
    required this.selectedProvider,
    required this.title,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final selected = ref.watch(selectedProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Column(children: [
        // Title bar
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Colors.white10))),
          child: Row(children: [
            Container(
                width: 3, height: 14, color: const Color(0xFF6E8473)),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const Spacer(),
            Text('${selected.length} / ${params.length}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                final defaults = params
                    .where((p) {
                      final dailyMatch = kAllDailyParams
                          .where((d) => d.key == p.key)
                          .firstOrNull;
                      final hourlyMatch = kAllHourlyParams
                          .where((h) => h.key == p.key)
                          .firstOrNull;
                      return (dailyMatch?.defaultOn ?? false) ||
                          (hourlyMatch?.defaultOn ?? false);
                    })
                    .map((p) => p.key)
                    .toSet();
                ref.read(selectedProvider.notifier).state = defaults;
              },
              child: const Text('RESET',
                  style: TextStyle(
                      color: Color(0xFF6E8473),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ),
          ]),
        ),
        // Param list
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: params.length,
            itemBuilder: (_, i) {
              final p = params[i];
              final isOn = selected.contains(p.key);
              return InkWell(
                onTap: () {
                  final current =
                      Set<String>.from(ref.read(selectedProvider));
                  isOn ? current.remove(p.key) : current.add(p.key);
                  ref.read(selectedProvider.notifier).state = current;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOn
                        ? const Color(0xFF6E8473).withAlpha(20)
                        : Colors.transparent,
                    border: const Border(
                        bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isOn
                              ? const Color(0xFF6E8473)
                              : Colors.white24,
                          width: 1.5,
                        ),
                        color: isOn
                            ? const Color(0xFF6E8473)
                            : Colors.transparent,
                      ),
                      child: isOn
                          ? const Icon(Icons.check,
                              size: 11, color: Colors.black)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Text(p.label,
                        style: TextStyle(
                            color:
                                isOn ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight: isOn
                                ? FontWeight.w700
                                : FontWeight.w400,
                            letterSpacing: 0.5)),
                    const SizedBox(width: 6),
                    if (p.unit.isNotEmpty)
                      Text('(${p.unit})',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 9)),
                    const Spacer(),
                    Text(p.key,
                        style: const TextStyle(
                            color: Colors.white12,
                            fontSize: 8,
                            fontFamily: 'monospace')),
                  ]),
                ),
              );
            },
          ),
        ),
        // Done button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: const Color(0xFF6E8473).withAlpha(38),
            child: const Text('DONE',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF6E8473),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TABLE BODY
// ═══════════════════════════════════════════════════════════════════════════════

class _TableBody extends ConsumerWidget {
  final Map daily;
  final Map hourly;
  const _TableBody({required this.daily, required this.hourly});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDaily = ref.watch(selectedDailyParamsProvider);
    final expandedDay = ref.watch(_expandedDayProvider);
    final activeDailyParams =
        kAllDailyParams.where((p) => selectedDaily.contains(p.key)).toList();
    final int dayCount =
        ((daily['time'] as List?)?.length ?? 16).clamp(1, 16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // Fixed columns: chevron (24) + date (110) = 134
        const fixedWidth = 134.0;
        final paramCount = activeDailyParams.length;
        final availableForParams = screenWidth - fixedWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: screenWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DailyHeaderRow(
                    params: activeDailyParams,
                    availableWidth: availableForParams,
                    colCount: paramCount,
                  ),
                  Container(height: 1, color: const Color(0xFF6E8473)),
                  ...List.generate(dayCount, (dayIndex) {
                    final isExpanded = expandedDay == dayIndex;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DailyDataRow(
                          dayIndex: dayIndex,
                          daily: daily,
                          params: activeDailyParams,
                          isExpanded: isExpanded,
                          availableWidth: availableForParams,
                          colCount: paramCount,
                          onTap: () {
                            ref
                                .read(_expandedDayProvider.notifier)
                                .state = isExpanded ? -1 : dayIndex;
                          },
                        ),
                        if (isExpanded)
                          _HourlyInlineTable(
                            dayIndex: dayIndex,
                            hourly: hourly,
                            ref: ref,
                            parentWidth: screenWidth,
                          ),
                        Container(height: 1, color: Colors.white10),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAILY HEADER ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _DailyHeaderRow extends StatelessWidget {
  final List<DailyParam> params;
  final double availableWidth;
  final int colCount;

  const _DailyHeaderRow({
    required this.params,
    required this.availableWidth,
    required this.colCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Row(children: [
        _HeaderCell('', width: 24),
        _HeaderCell('DATE', width: 110),
        ...params.map((p) => _HeaderCell(
              p.unit.isNotEmpty ? '${p.label}\n${p.unit}' : p.label,
              width: _colWidth(p.key, availableWidth, colCount),
            )),
      ]),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  const _HeaderCell(this.text, {required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white10))),
      child: Text(text,
          textAlign: TextAlign.right,
          style: const TextStyle(
              color: Color(0xFF6E8473),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              height: 1.3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAILY DATA ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _DailyDataRow extends StatelessWidget {
  final int dayIndex;
  final Map daily;
  final List<DailyParam> params;
  final bool isExpanded;
  final VoidCallback onTap;
  final double availableWidth;
  final int colCount;

  const _DailyDataRow({
    required this.dayIndex,
    required this.daily,
    required this.params,
    required this.isExpanded,
    required this.onTap,
    required this.availableWidth,
    required this.colCount,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(daily['time'][dayIndex]);
    final isToday = dayIndex == 0;
    final dateLabel = isToday
        ? 'TODAY'
        : DateFormat('EEE dd MMM').format(date).toUpperCase();

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isExpanded
            ? const Color(0xFF6E8473).withAlpha(18)
            : (dayIndex.isEven
                ? Colors.white.withAlpha(4)
                : Colors.transparent),
        child: Row(children: [
          SizedBox(
            width: 24,
            child: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF6E8473),
              size: 16,
            ),
          ),
          Container(
            width: 110,
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 13),
            decoration: const BoxDecoration(
                border:
                    Border(right: BorderSide(color: Colors.white10))),
            child: Text(dateLabel,
                style: TextStyle(
                    color: isToday
                        ? const Color(0xFF6E8473)
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
          ...params.map((p) => _DailyValueCell(
                param: p,
                value: daily[p.key] is List
                    ? daily[p.key][dayIndex]
                    : null,
                width: _colWidth(p.key, availableWidth, colCount),
              )),
        ]),
      ),
    );
  }
}

class _DailyValueCell extends StatelessWidget {
  final DailyParam param;
  final dynamic value;
  final double width;

  const _DailyValueCell({
    required this.param,
    required this.value,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final display = _formatDailyValue(param.key, value);
    final color = _colorForDailyKey(param.key, value);

    return Container(
      width: width,
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white10))),
      child: Text(
        display,
        textAlign: TextAlign.right,
        style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
            letterSpacing: 0.3),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOURLY INLINE TABLE
// ═══════════════════════════════════════════════════════════════════════════════

class _HourlyInlineTable extends ConsumerWidget {
  final int dayIndex;
  final Map hourly;
  final WidgetRef ref;
  final double parentWidth;

  const _HourlyInlineTable({
    required this.dayIndex,
    required this.hourly,
    required this.ref,
    required this.parentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final selectedHourly = ref.watch(selectedHourlyParamsProvider);
    final activeHourlyParams = kAllHourlyParams
        .where((p) => selectedHourly.contains(p.key))
        .toList();
    final int startHour = dayIndex * 24;
    // 24px indent for the chevron column
    final availableForParams = parentWidth - 24.0;
    final colCount = activeHourlyParams.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(100),
        border: const Border(
            left: BorderSide(color: Color(0xFF6E8473), width: 3)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: parentWidth - 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hourly header
            Container(
              color: const Color(0xFF0A1018),
              child: Row(children: [
                const SizedBox(width: 24),
                ...activeHourlyParams.map((p) => _HourlyHeaderCell(
                      p,
                      width: _hourlyColWidth(
                          p.key, availableForParams, colCount),
                    )),
              ]),
            ),
            Container(
                height: 1,
                color: const Color(0xFF6E8473).withAlpha(80)),
            // 24 hour rows
            ...List.generate(24, (hourOffset) {
              final idx = startHour + hourOffset;
              return _HourlyDataRow(
                hourOffset: hourOffset,
                globalIndex: idx,
                hourly: hourly,
                params: activeHourlyParams,
                availableWidth: availableForParams,
                colCount: colCount,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _HourlyHeaderCell extends StatelessWidget {
  final HourlyParam param;
  final double width;
  const _HourlyHeaderCell(this.param, {required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white10))),
      child: Text(
        param.unit.isNotEmpty
            ? '${param.label}\n${param.unit}'
            : param.label,
        textAlign: TextAlign.right,
        style: const TextStyle(
            color: Color(0xFF6E8473),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            height: 1.3),
      ),
    );
  }
}

class _HourlyDataRow extends StatelessWidget {
  final int hourOffset;
  final int globalIndex;
  final Map hourly;
  final List<HourlyParam> params;
  final double availableWidth;
  final int colCount;

  const _HourlyDataRow({
    required this.hourOffset,
    required this.globalIndex,
    required this.hourly,
    required this.params,
    required this.availableWidth,
    required this.colCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: hourOffset.isEven
            ? Colors.white.withAlpha(5)
            : Colors.transparent,
        border:
            const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(children: [
        const SizedBox(width: 24),
        ...params.map((p) {
          final rawValue = _getHourlyValue(hourly, p.key, globalIndex);
          final display = _formatHourlyValue(p.key, rawValue);
          final color = _colorForHourlyKey(p.key, rawValue);
          return Container(
            width: _hourlyColWidth(p.key, availableWidth, colCount),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: const BoxDecoration(
                border:
                    Border(right: BorderSide(color: Colors.white10))),
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: color,
                  fontSize: 23,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500),
            ),
          );
        }),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMATTERS
// ═══════════════════════════════════════════════════════════════════════════════

dynamic _getHourlyValue(Map hourly, String key, int index) {
  if (key == 'time') {
    final times = hourly['time'] as List?;
    if (times == null || index >= times.length) return null;
    return times[index];
  }
  final list = hourly[key];
  if (list == null || index >= (list as List).length) return null;
  return list[index];
}

String _formatDailyValue(String key, dynamic value) {
  if (value == null) return '—';
  try {
    if (key == 'weather_code') {
      return WeatherMapper.getDescription(value as int)
          .toUpperCase()
          .split(' ')
          .take(2)
          .join(' ');
    }
    if (key == 'sunrise' || key == 'sunset') {
      return DateFormat('HH:mm')
          .format(DateTime.parse(value as String));
    }
    if (key == 'daylight_duration' || key == 'sunshine_duration') {
      final hours = (value as num) / 3600;
      return '${hours.toStringAsFixed(1)}h';
    }
    if (key == 'wind_direction_10m_dominant') {
      return _windDir((value as num).toDouble());
    }
    if (value is num) {
      if (value == value.roundToDouble()) return value.round().toString();
      return value.toStringAsFixed(1);
    }
    return value.toString();
  } catch (_) {
    return '—';
  }
}

String _formatHourlyValue(String key, dynamic value) {
  if (value == null) return '—';
  try {
    if (key == 'time') {
      return DateFormat('HH:mm')
          .format(DateTime.parse(value as String));
    }
    if (key == 'weather_code') {
      return WeatherMapper.getDescription(value as int)
          .toUpperCase()
          .split(' ')
          .take(2)
          .join(' ');
    }
    if (key == 'is_day') {
      return (value as int) == 1 ? 'DAY' : 'NIGHT';
    }
    if (key == 'wind_direction_10m') {
      return _windDir((value as num).toDouble());
    }
    if (key == 'visibility') {
      return ((value as num) / 1000).toStringAsFixed(1);
    }
    if (value is num) {
      if (value == value.roundToDouble()) return value.round().toString();
      return value.toStringAsFixed(1);
    }
    return value.toString();
  } catch (_) {
    return '—';
  }
}

String _windDir(double deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[((deg + 22.5) / 45).floor() % 8];
}

Color _colorForDailyKey(String key, dynamic value) {
  if (value == null) return Colors.white24;
  if (key.contains('temperature') || key.contains('apparent')) {
    final v = (value as num).toDouble();
    if (v >= 40) return const Color(0xFFFF3B3B);
    if (v >= 35) return const Color(0xFFFF6B35);
    if (v >= 30) return const Color(0xFFA6755B);
    if (v >= 20) return Colors.white;
    if (v >= 10) return const Color(0xFF7E97A8);
    return const Color(0xFF5B8FA6);
  }
  if (key.contains('precipitation') && !key.contains('probability')) {
    final v = (value as num).toDouble();
    if (v > 20) return const Color(0xFF3B6BFF);
    if (v > 5)  return Colors.blueAccent;
    if (v > 0)  return const Color(0xFF7E97A8);
    return Colors.white38;
  }
  if (key.contains('probability')) {
    final v = (value as num).toDouble();
    if (v >= 80) return const Color(0xFF3B6BFF);
    if (v >= 50) return Colors.blueAccent;
    if (v >= 20) return const Color(0xFF7E97A8);
    return Colors.white38;
  }
  if (key == 'uv_index_max' || key == 'uv_index_clear_sky_max') {
    final v = (value as num).toDouble();
    if (v >= 8) return const Color(0xFFFF3B3B);
    if (v >= 6) return const Color(0xFFFF6B35);
    if (v >= 3) return const Color(0xFFD4A94B);
    return Colors.white70;
  }
  if (key == 'cape_max') {
    final v = (value as num).toDouble();
    if (v >= 2000) return const Color(0xFFFF3B3B);
    if (v >= 1000) return const Color(0xFFD4A94B);
    return Colors.white70;
  }
  return Colors.white70;
}

Color _colorForHourlyKey(String key, dynamic value) {
  if (value == null) return Colors.white24;
  if (key == 'time') return const Color(0xFF6E8473);
  if (key == 'is_day') {
    return (value as int) == 1
        ? const Color(0xFFD4A94B)
        : const Color(0xFF7E97A8);
  }
  return _colorForDailyKey(key, value);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLUMN WIDTH HELPERS — proportional to screen
// ═══════════════════════════════════════════════════════════════════════════════

double _colWidth(String key, double availableWidth, int colCount) {
  final base = colCount > 0 ? availableWidth / colCount : availableWidth;
  if (key == 'weather_code')               return (base * 1.6).clamp(100, 200);
  if (key == 'sunrise' || key == 'sunset') return (base * 0.85).clamp(56, 100);
  if (key == 'wind_direction_10m_dominant') return (base * 0.85).clamp(56, 100);
  if (key.contains('radiation') || key.contains('evapotrans')) {
    return (base * 1.1).clamp(72, 130);
  }
  if (key == 'freezing_level_height_max')  return (base * 1.0).clamp(72, 120);
  return base.clamp(64, 140);
}

double _hourlyColWidth(String key, double availableWidth, int colCount) {
  final base = colCount > 0 ? availableWidth / colCount : availableWidth;
  if (key == 'time')                       return (base * 0.7).clamp(50, 80);
  if (key == 'weather_code')               return (base * 1.6).clamp(100, 200);
  if (key == 'wind_direction_10m')         return (base * 0.85).clamp(54, 100);
  if (key.contains('radiation') || key.contains('evapotrans') ||
      key.contains('irradiance')) {
    return (base * 1.1).clamp(72, 130);
  }
  if (key == 'freezing_level_height')      return (base * 1.0).clamp(70, 120);
  return base.clamp(62, 120);
}