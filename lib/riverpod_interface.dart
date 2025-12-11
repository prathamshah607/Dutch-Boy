import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather/weather_mapper.dart';
import 'data_calling.dart';
import 'package:intl/intl.dart';

// ===========================================================================
// CITY MODEL
// ===========================================================================

class City {
  final String name;
  final double latitude;
  final double longitude;
  final String country;
  final String? admin1; // State/Region
  final String? countryCode; // ISO code (e.g., "US")
  final double? elevation; // Meters above sea level (changed to double)
  final String? timezone; // e.g., "America/New_York"
  final int? population; // City population

  City({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.country,
    this.admin1,
    this.countryCode,
    this.elevation,
    this.timezone,
    this.population,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      country: json['country'] as String,
      admin1: json['admin1'] as String?,
      countryCode: json['country_code'] as String?,
      elevation: (json['elevation'] as num?)?.toDouble(),
      timezone: json['timezone'] as String?,
      population: json['population'] as int?,
    );
  }
}

// ===========================================================================
// PROVIDERS
// ===========================================================================

String buildWeatherLLMContext(Map<String, dynamic> data) {
  final current = data['current'] as Map<String, dynamic>;
  final daily = data['daily'] as Map<String, dynamic>;
  final hourly = data['hourly'] as Map<String, dynamic>;

  final buf = StringBuffer();

  // ========== CURRENT CONDITIONS ==========
  final nowTime = DateTime.parse(current['time']);
  final int wmoCode = current['weather_code'] as int;
  buf.writeln('=== CURRENT CONDITIONS ===');
  buf.writeln(
      'As of ${DateFormat('yyyy-MM-dd HH:mm').format(nowTime)} local time:');
  buf.writeln(
      '- Temperature: ${current['temperature_2m'].round()} °C (feels like ${current['apparent_temperature'].round()} °C)');
  buf.writeln(
      '- Weather: ${WeatherMapper.getDescription(wmoCode)} (Code: $wmoCode)');
  buf.writeln(
      '- Precipitation: ${current['precipitation']} mm, humidity ${current['relative_humidity_2m']}%, wind ${current['wind_speed_10m'].round()} units');
  buf.writeln(
      '- Visibility: ${(hourly['visibility'][0] / 1000).round()} km, UV index ~${daily['uv_index_max'][0]}');
  buf.writeln();

  // ========== HOURLY TABLE (NEXT 24 HOURS) ==========
  // This provides granular context for "Will it rain at 5 PM?"
  buf.writeln('=== HOURLY FORECAST (NEXT 24 HOURS) ===');
  buf.writeln('Format: Time | Temp | Feels Like | Rain Chance (Vol) | Wind');

  final times = List<String>.from(hourly['time'] ?? []);
  final temps = List<num>.from(hourly['temperature_2m'] ?? []);
  final appTemps = List<num>.from(hourly['apparent_temperature'] ?? []);
  final precipProbs = List<num>.from(hourly['precipitation_probability'] ?? []);
  final precipVols = List<num>.from(hourly['precipitation'] ?? []);
  final winds = List<num>.from(hourly['wind_speed_10m'] ?? []);

  if (times.isNotEmpty) {
    // 1. Find the index for the current hour
    int startIdx = times.indexWhere((t) {
      final tDate = DateTime.parse(t);
      // Compare only up to the hour to match
      return tDate.year == nowTime.year &&
          tDate.month == nowTime.month &&
          tDate.day == nowTime.day &&
          tDate.hour == nowTime.hour;
    });

    if (startIdx < 0) startIdx = 0; // Fallback

    // 2. Loop through the next 24 indices
    final endIdx = (startIdx + 24).clamp(0, times.length);

    for (int i = startIdx; i < endIdx; i++) {
      final timeObj = DateTime.parse(times[i]);
      final hourStr = DateFormat('HH:mm').format(timeObj); // e.g. "14:00"

      // Data retrieval
      final t = temps[i].round();
      final app = appTemps[i].round();
      final pop = precipProbs[i]; // Probability of Precip
      final vol = precipVols[i]; // Volume in mm
      final w = winds[i].round();

      // compact row: "14:00 | 22°C | 24°C | 0% (0mm) | 12"
      buf.writeln(
        '$hourStr | ${t}°C | Feels ${app}°C | Rain $pop% (${vol}mm) | Wind $w',
      );
    }
  } else {
    buf.writeln('(Hourly data unavailable)');
  }
  buf.writeln();

  // ========== 10-DAY DAILY SUMMARY ==========
  buf.writeln('=== 10-DAY FORECAST SUMMARY ===');

  final dTimes = List<String>.from(daily['time'] ?? []);
  final tMin = List<num>.from(daily['temperature_2m_min'] ?? []);
  final tMax = List<num>.from(daily['temperature_2m_max'] ?? []);
  final rainSum = List<num>.from(daily['rain_sum'] ?? []);
  final uvMax = List<num>.from(daily['uv_index_max'] ?? []);
  final windMax = List<num>.from(daily['wind_speed_10m_max'] ?? []);

  if (dTimes.isNotEmpty) {
    final days = dTimes.length.clamp(0, 10);
    num globalMin = tMin.sublist(0, days).reduce((a, b) => a < b ? a : b);
    num globalMax = tMax.sublist(0, days).reduce((a, b) => a > b ? a : b);
    num totalRain =
        rainSum.sublist(0, days).fold(0.0, (a, b) => a + b.toDouble());
    num maxUv = uvMax.sublist(0, days).reduce((a, b) => a > b ? a : b);
    num maxWind10 = windMax.sublist(0, days).reduce((a, b) => a > b ? a : b);

    buf.writeln(
        '- Over the next $days days, daily minimum temperatures range from ${globalMin.round()}°C to ${globalMax.round()}°C.');
    buf.writeln(
        '- Total forecast rain over next $days days: ~${totalRain.toStringAsFixed(1)} mm.');
    buf.writeln('- Maximum UV index in this period: ${maxUv.toString()}.');
    buf.writeln(
        '- Maximum daily wind speed in this period: ${maxWind10.round()} units.');
    buf.writeln();
    buf.writeln('- Day-by-day overview:');
    for (int i = 0; i < days; i++) {
      final date = DateTime.parse(dTimes[i]);
      buf.writeln(
          '  • ${DateFormat('EEE, MMM d').format(date)}: ${tMin[i].round()}°C to ${tMax[i].round()}°C, rain ${rainSum[i]} mm, max wind ${windMax[i].round()} units, max UV ${uvMax[i]}.');
    }
  } else {
    buf.writeln('- Daily forecast unavailable.');
  }

  return buf.toString().trim();
}

// Current selected city (defaults to Mumbai)
final currentCityProvider = StateProvider<City>((ref) {
  return City(
    name: 'Mumbai',
    latitude: 19.0760,
    longitude: 72.8777,
    country: 'India',
    admin1: 'Maharashtra',
    countryCode: 'IN',
    elevation: 14.0,
    timezone: 'Asia/Kolkata',
    population: 12691836,
  );
});

// City search provider (autocomplete)
final citySearchProvider =
    FutureProvider.autoDispose.family<List<City>, String>((ref, query) async {
  final repo = ref.read(weatherRepositoryProvider);
  final results = await repo.searchCity(query);
  return results.map((json) => City.fromJson(json)).toList();
});

// Weather data provider (depends on currentCityProvider AND unit preferences)
final weatherRequestProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final city = ref.watch(currentCityProvider);
  final tempUnit = ref.watch(temperatureUnitProvider);
  final speedUnit = ref.watch(speedUnitProvider);
  final repo = ref.read(weatherRepositoryProvider);

  return await repo.fetchComprehensiveWeather(
    lat: city.latitude,
    long: city.longitude,
    tempUnit: tempUnit.apiValue,
    speedUnit: speedUnit.apiValue,
  );
});

// ===========================================================================
// HISTORICAL WEATHER PROVIDERS
// ===========================================================================

// Duration selection provider
enum HistoricalDuration {
  week7('7 Days', 7),
  months3('3 Months', 90),
  year1('1 Year', 365),
  years2('2 Years', 730),
  max('Max (5 Years)', 1825);

  final String label;
  final int days;
  const HistoricalDuration(this.label, this.days);
}

final selectedDurationProvider = StateProvider<HistoricalDuration>((ref) {
  return HistoricalDuration.months3;
});

// Historical weather data provider
// Historical weather data provider
final historicalWeatherProvider =
    FutureProvider.family<Map<String, dynamic>, City>((ref, city) async {
  final duration = ref.watch(selectedDurationProvider);
  final repo = ref.read(weatherRepositoryProvider);

  // Always end 7 days ago to stay within Archive API limits
  final endDate = DateTime.now().subtract(const Duration(days: 7));
  final startDate = endDate.subtract(Duration(days: duration.days));

  return await repo.fetchHistoricalWeather(
    lat: city.latitude,
    long: city.longitude,
    startDate: _formatDate(startDate),
    endDate: _formatDate(endDate),
  );
});

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ===========================================================================
// UNIT PREFERENCES
// ===========================================================================

enum TemperatureUnit {
  celsius('Celsius', '°C', 'celsius'),
  fahrenheit('Fahrenheit', '°F', 'fahrenheit');

  final String label;
  final String symbol;
  final String apiValue;
  const TemperatureUnit(this.label, this.symbol, this.apiValue);
}

enum SpeedUnit {
  kmh('Kilometers/Hour', 'km/h', 'kmh'),
  mph('Miles/Hour', 'mph', 'mph'),
  ms('Meters/Second', 'm/s', 'ms'),
  knots('Knots', 'kn', 'kn');

  final String label;
  final String symbol;
  final String apiValue;
  const SpeedUnit(this.label, this.symbol, this.apiValue);
}

final temperatureUnitProvider = StateProvider<TemperatureUnit>((ref) {
  return TemperatureUnit.celsius;
});

final speedUnitProvider = StateProvider<SpeedUnit>((ref) {
  return SpeedUnit.kmh;
});
