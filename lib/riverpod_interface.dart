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
  final String? admin1;        // State/Region
  final String? countryCode;   // ISO code (e.g., "US")
  final double? elevation;     // Meters above sea level (changed to double)
  final String? timezone;      // e.g., "America/New_York"
  final int? population;       // City population

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
final citySearchProvider = FutureProvider.autoDispose.family<List<City>, String>((ref, query) async {
  final repo = ref.read(weatherRepositoryProvider);
  final results = await repo.searchCity(query);
  return results.map((json) => City.fromJson(json)).toList();
});

// Weather data provider (depends on currentCityProvider)
final weatherRequestProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final city = ref.watch(currentCityProvider);
  final repo = ref.read(weatherRepositoryProvider);
  
  return await repo.fetchComprehensiveWeather(
    lat: city.latitude,
    long: city.longitude,
  );
});
