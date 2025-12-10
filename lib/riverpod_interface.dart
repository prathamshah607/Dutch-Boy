import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_calling.dart';

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
