import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global provider for the repository
final weatherRepositoryProvider = Provider((ref) => WeatherRepository(Dio()));

class WeatherRepository {
  final Dio _dio;
  
  // Base URLs
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _airQualityUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String _geocodingUrl = 'https://geocoding-api.open-meteo.com/v1/search';

  WeatherRepository(this._dio);

  // ===========================================================================
  // 1. GEOCODING (CITY SEARCH)
  // ===========================================================================

  /// Searches for cities by name using Open-Meteo Geocoding API.
  /// 
  /// Returns a list of matches.
  Future<List<Map<String, dynamic>>> searchCity(String query) async {
    // 1. Validation: Don't spam API with single letters
    if (query.trim().length < 2) return [];

    try {
      final response = await _dio.get(
        _geocodingUrl,
        queryParameters: {
          'name': query,
          'count': 10,       // Limit to top 10 results
          'language': 'en',  // Prefer English names
          'format': 'json',
          'timezone' : 'auto',
        },
      );

      // 2. Safety Check: API returns { "results": [...] } or sometimes just generation time if no results
      final data = response.data;
      if (data == null || data['results'] == null) {
        return [];
      }

      // 3. Casting: Convert dynamic list to strongly typed Map list
      final List<dynamic> results = data['results'];
      return results.cast<Map<String, dynamic>>();
      
    } catch (e) {
      // In production, log this error to Sentry/Firebase
      print('Geocoding Error: $e');
      return []; // Return empty list so UI simply shows "No results"
    }
  }

  // ===========================================================================
  // 2. WEATHER DATA FETCHING
  // ===========================================================================

  /// Fetches comprehensive weather data with maximum granularity.
  /// 
  /// [lat] Latitude of the location.
  /// [long] Longitude of the location.
  /// [tempUnit] 'celsius' or 'fahrenheit'.
  /// [speedUnit] 'kmh', 'ms', 'mph', or 'kn'.
  Future<Map<String, dynamic>> fetchComprehensiveWeather({
    required double lat,
    required double long,
    String tempUnit = 'celsius',
    String speedUnit = 'kmh',
  }) async {
    try {
      // Parallel execution for speed: Fetch Weather + Air Quality simultaneously
      final results = await Future.wait([
        _fetchForecast(lat, long, tempUnit, speedUnit),
        _fetchAirQuality(lat, long),
      ]);

      final forecastData = results[0];
      final airQualityData = results[1];

      // Merge air quality into the main data structure for easier UI consumption
      forecastData['air_quality'] = airQualityData;

      return forecastData;
    } catch (e) {
      throw Exception('Failed to aggregate weather data: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchForecast(
    double lat,
    double long,
    String tempUnit,
    String speedUnit,
  ) async {
    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'latitude': lat,
        'longitude': long,
        'temperature_unit': tempUnit,
        'wind_speed_unit': speedUnit,
        'timezone': 'auto', // Critical for correct daily aggregations
        
        // --- 1. Current Conditions (Real-time) ---
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'apparent_temperature', // "Feels Like"
          'is_day',               // Boolean for UI theme (dark/light mode)
          'precipitation',
          'rain',
          'showers',
          'snowfall',
          'weather_code',
          'cloud_cover',
          'pressure_msl',         // Mean Sea Level Pressure (Barometer)
          'surface_pressure',
          'wind_speed_10m',
          'wind_direction_10m',
          'wind_gusts_10m',
        ].join(','),

        // --- 2. Hourly Granularity (Next 48 Hours) ---
        // Perfect for "Chance of Rain" graphs or temperature curves
        'hourly': [
          'temperature_2m',
          'relative_humidity_2m',
          'dew_point_2m',
          'apparent_temperature',
          'precipitation_probability', // % chance
          'precipitation',             // mm volume
          'weather_code',
          'pressure_msl',
          'surface_pressure',
          'cloud_cover',
          'visibility',
          'wind_speed_10m',
          'wind_direction_10m',
          'uv_index',
          'is_day',
        ].join(','),

        // --- 3. Daily Granularity (Next 14 Days) ---
        // For the 7-day or 14-day list view
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'apparent_temperature_max',
          'apparent_temperature_min',
          'sunrise',
          'sunset',
          'uv_index_max',
          'precipitation_sum',
          'rain_sum',
          'showers_sum',
          'snowfall_sum',
          'precipitation_hours',
          'precipitation_probability_max',
          'wind_speed_10m_max',
          'wind_gusts_10m_max',
          'wind_direction_10m_dominant',
        ].join(','),
        
        'forecast_days': 14, // Extended outlook
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> _fetchAirQuality(double lat, double long) async {
    // Open-Meteo Air Quality is a separate endpoint
    try {
      final response = await _dio.get(
        _airQualityUrl,
        queryParameters: {
          'latitude': lat,
          'longitude': long,
          'timezone': 'auto',
          'current': [
            'european_aqi',
            'us_aqi',
            'pm10',
            'pm2_5',
            'carbon_monoxide',
            'nitrogen_dioxide',
            'sulphur_dioxide',
            'ozone',
            'dust',
            'uv_index', // Redundant but useful verification
          ].join(','),
        },
      );
      return response.data;
    } catch (e) {
      // If AQI fails, don't crash the whole app, just return null/empty
      // This ensures the main weather app works even if pollution data is unavailable
      print('Air Quality API Error: $e');
      return {'current': {}}; 
    }
  }
}
