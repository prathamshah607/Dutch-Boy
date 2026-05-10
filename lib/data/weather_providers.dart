import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather/data/weather_repository.dart';

// ─── City Model ───────────────────────────────────────────────────────────────

class City {
  final String name;
  final double latitude;
  final double longitude;
  final String country;
  final String? admin1;
  final String? countryCode;
  final double? elevation;
  final String? timezone;
  final int? population;

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

  factory City.fromJson(Map<String, dynamic> json) => City(
        name:        json['name'] as String,
        latitude:    (json['latitude'] as num).toDouble(),
        longitude:   (json['longitude'] as num).toDouble(),
        country:     json['country'] as String,
        admin1:      json['admin1'] as String?,
        countryCode: json['country_code'] as String?,
        elevation:   (json['elevation'] as num?)?.toDouble(),
        timezone:    json['timezone'] as String?,
        population:  json['population'] as int?,
      );
}

// ─── Unit Enums ───────────────────────────────────────────────────────────────

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

enum PrecipitationUnit {
  mm('Millimeters', 'mm', 'mm'),
  inch('Inches', 'in', 'inch');

  final String label;
  final String symbol;
  final String apiValue;
  const PrecipitationUnit(this.label, this.symbol, this.apiValue);
}

// ─── Historical Duration Enum ─────────────────────────────────────────────────

enum HistoricalDuration {
  week7('7 Days', 7),
  months3('3 Months', 90),
  months6('6 Months', 180),
  year1('1 Year', 365),
  years2('2 Years', 730),
  years5('5 Years', 1825);

  final String label;
  final int days;
  const HistoricalDuration(this.label, this.days);
}

// ─── Unit Providers ───────────────────────────────────────────────────────────

final temperatureUnitProvider =
    StateProvider<TemperatureUnit>((ref) => TemperatureUnit.celsius);

final speedUnitProvider =
    StateProvider<SpeedUnit>((ref) => SpeedUnit.kmh);

final precipitationUnitProvider =
    StateProvider<PrecipitationUnit>((ref) => PrecipitationUnit.mm);

/// How many days ahead to fetch. 1–16 supported by Open-Meteo.
final forecastDaysProvider =
    StateProvider<int>((ref) => 16);

// ─── City Providers ───────────────────────────────────────────────────────────

final currentCityProvider = StateProvider<City>((ref) {
  return City(
    name:        'Mumbai',
    latitude:    19.0760,
    longitude:   72.8777,
    country:     'India',
    admin1:      'Maharashtra',
    countryCode: 'IN',
    elevation:   14.0,
    timezone:    'Asia/Kolkata',
    population:  12691836,
  );
});

final citySearchProvider =
    FutureProvider.autoDispose.family<List<City>, String>((ref, query) async {
  final repo    = ref.read(weatherRepositoryProvider);
  final results = await repo.searchCity(query);
  return results.map((json) => City.fromJson(json)).toList();
});

// ─── Forecast Provider ────────────────────────────────────────────────────────

final weatherRequestProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final city         = ref.watch(currentCityProvider);
  final tempUnit     = ref.watch(temperatureUnitProvider);
  final speedUnit    = ref.watch(speedUnitProvider);
  final precipUnit   = ref.watch(precipitationUnitProvider);
  final forecastDays = ref.watch(forecastDaysProvider);
  final repo         = ref.read(weatherRepositoryProvider);

  return repo.fetchComprehensiveWeather(
    lat:          city.latitude,
    long:         city.longitude,
    tempUnit:     tempUnit.apiValue,
    speedUnit:    speedUnit.apiValue,
    precipUnit:   precipUnit.apiValue,
    forecastDays: forecastDays,
  );
});

// ─── Historical Provider ──────────────────────────────────────────────────────

final selectedDurationProvider =
    StateProvider<HistoricalDuration>((ref) => HistoricalDuration.months3);

final historicalWeatherProvider =
    FutureProvider.family<Map<String, dynamic>, City>((ref, city) async {
  final duration  = ref.watch(selectedDurationProvider);
  final tempUnit  = ref.watch(temperatureUnitProvider);
  final speedUnit = ref.watch(speedUnitProvider);
  final repo      = ref.read(weatherRepositoryProvider);

  // Archive API lags ~5 days behind real-time
  final endDate   = DateTime.now().subtract(const Duration(days: 5));
  final startDate = endDate.subtract(Duration(days: duration.days));

  return repo.fetchHistoricalWeather(
    lat:       city.latitude,
    long:      city.longitude,
    startDate: _formatDate(startDate),
    endDate:   _formatDate(endDate),
    tempUnit:  tempUnit.apiValue,
    speedUnit: speedUnit.apiValue,
  );
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';