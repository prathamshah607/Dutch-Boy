import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WikipediaService {
  static const baseUrl = 'https://en.wikipedia.org/w/api.php';

  // Keywords to capture for the Climate RAG
  static const _relevantKeywords = {
    'geography',
    'climate',
    'weather',
    'topography',
    'ecology',
    'environment',
    'geology',
    'flora',
    'fauna',
    'agriculture',
    'economy', // Often contains info about crops/farming
    'landscape',
    'demographics', // Useful for population density context
  };

  Future<String> getEnrichedContext(String cityName) async {
    try {
      final pageTitle = await findCityPage(cityName);
      if (pageTitle == null) throw Exception('City not found');

      final wikitext = await _fetchWikiText(pageTitle);
      final sections = _parseWikiText(wikitext);

      final sb = StringBuffer();

      // 1. Always include the Summary (Introduction)
      if (sections.containsKey('summary')) {
        sb.writeln('=== GENERAL OVERVIEW ===');
        sb.writeln(sections['summary']);
        sb.writeln();
      }

      // 2. Aggregate relevant sections
      sections.forEach((title, content) {
        if (title == 'summary') return; // Already handled

        // Check if title contains any of our keywords
        if (_relevantKeywords.any((k) => title.contains(k))) {
          sb.writeln('=== ${title.toUpperCase().replaceAll('_', ' ')} ===');
          sb.writeln(content);
          sb.writeln();
        }
      });

      final result = sb.toString().trim();
      return result.isEmpty
          ? "No detailed geographic context available."
          : result;
    } catch (e) {
      print('Error getting context: $e');
      return "Unable to retrieve context.";
    }
  }

  Future<String> _fetchWikiText(String title) async {
    final url = Uri.parse('$baseUrl?'
        'action=parse&'
        'page=${Uri.encodeComponent(title)}&'
        'prop=wikitext&'
        'format=json&'
        'formatversion=2');

    final response = await http.get(url);
    if (response.statusCode != 200) throw Exception('Failed to load');

    final data = jsonDecode(response.body);
    return data['parse']['wikitext'] as String;
  }

  Map<String, String> _parseWikiText(String text) {
    final sections = <String, String>{};
    final lines = text.split('\n');

    String currentSection = 'summary';
    StringBuffer buffer = StringBuffer();

    // Regex to match headers like "== Geography ==" or "=== Climate ==="
    final headerRegex = RegExp(r'^(={2,})\s*(.*?)\s*\1$');

    for (var line in lines) {
      if (line.trim().isEmpty ||
          line.startsWith('[[File:') ||
          line.startsWith('{{')) continue;

      final match = headerRegex.firstMatch(line);
      if (match != null) {
        if (buffer.isNotEmpty) {
          // Append to existing content if we've seen this section header before (merging subsections)
          final existing = sections[currentSection] ?? '';
          sections[currentSection] = existing +
              (existing.isEmpty ? '' : '\n') +
              _cleanWikiText(buffer.toString());
        }

        // Start new section
        // normalize the key to lowercase/underscore for easy matching later
        currentSection =
            match.group(2)!.toLowerCase().trim().replaceAll(' ', '_');

        buffer.clear();
      } else {
        buffer.writeln(line);
      }
    }

    // Save last section
    if (buffer.isNotEmpty) {
      final existing = sections[currentSection] ?? '';
      sections[currentSection] = existing +
          (existing.isEmpty ? '' : '\n') +
          _cleanWikiText(buffer.toString());
    }

    return sections;
  }

  String _cleanWikiText(String text) {
    var clean = text;
    // Remove ref tags
    clean = clean.replaceAll(
        RegExp(r'<ref.*?>.*?</ref>',
            caseSensitive: false, multiLine: true, dotAll: true),
        '');
    clean = clean.replaceAll(RegExp(r'<ref.*?/>', caseSensitive: false), '');

    // Remove [[File:...]]
    clean = clean.replaceAll(RegExp(r'\[\[File:.*?\]\]'), '');

    // Replace [[Link|Text]] with Text
    clean = clean.replaceAllMapped(RegExp(r'\[\[(?:[^|\]]*\|)?([^\]]+)\]\]'),
        (match) {
      return match.group(1) ?? '';
    });

    // Remove {{...}} templates
    // We use a non-greedy match to try and catch simple templates
    clean = clean.replaceAll(RegExp(r'\{\{.*?\}\}'), '');

    // Remove formatting
    clean = clean.replaceAll("'''", "").replaceAll("''", "");

    // Clean up extra whitespace that results from removing tags
    clean = clean.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return clean.trim();
  }

  Future<String?> findCityPage(String cityName) async {
    final url = Uri.parse(
        '$baseUrl?action=opensearch&search=${Uri.encodeComponent(cityName)}&limit=1&format=json');
    final response = await http.get(url);
    final data = jsonDecode(response.body) as List;
    if (data.length > 1 && (data[1] as List).isNotEmpty) {
      return (data[1] as List)[0] as String;
    }
    return null;
  }
}

// Global provider for the repository
final weatherRepositoryProvider = Provider((ref) => WeatherRepository(Dio()));

class WeatherRepository {
  final Dio _dio;

  // Base URLs
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _airQualityUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String _geocodingUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  WeatherRepository(this._dio);

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
          'count': 10, // Limit to top 10 results
          'language': 'en', // Prefer English names
          'format': 'json',
          'timezone': 'auto',
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
          'is_day', // Boolean for UI theme (dark/light mode)
          'precipitation',
          'rain',
          'showers',
          'snowfall',
          'weather_code',
          'cloud_cover',
          'pressure_msl', // Mean Sea Level Pressure (Barometer)
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
          'precipitation', // mm volume
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

  /// Fetches historical weather data for graphing.
  ///
  /// [lat] Latitude of the location.
  /// [long] Longitude of the location.
  /// [startDate] ISO format "YYYY-MM-DD"
  /// [endDate] ISO format "YYYY-MM-DD"
  Future<Map<String, dynamic>> fetchHistoricalWeather({
    required double lat,
    required double long,
    required String startDate,
    required String endDate,
    String tempUnit = 'celsius',
  }) async {
    try {
      final response = await _dio.get(
        'https://archive-api.open-meteo.com/v1/archive',
        queryParameters: {
          'latitude': lat,
          'longitude': long,
          'start_date': startDate,
          'end_date': endDate,
          'temperature_unit': tempUnit,
          'timezone': 'auto',

          // Daily aggregations for cleaner graphs
          'daily': [
            'temperature_2m_max',
            'temperature_2m_min',
            'temperature_2m_mean',
            'apparent_temperature_max',
            'apparent_temperature_min',
            'apparent_temperature_mean',
            'precipitation_sum',
            'rain_sum',
            'snowfall_sum',
            'precipitation_hours',
            'wind_speed_10m_max',
            'wind_gusts_10m_max',
            'wind_direction_10m_dominant',
            'shortwave_radiation_sum',
            'et0_fao_evapotranspiration',
            'weather_code',
            'sunrise',
            'sunset',
            'sunshine_duration',
          ].join(','),
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch historical weather: $e');
    }
  }
}

// Place this outside your widget or in a utility file
String buildMonthlyHistorySummary(Map<String, dynamic> historicalData) {
  try {
    final daily = historicalData['daily'] as Map<String, dynamic>;
    final dates = List<String>.from(daily['time']);
    final temps = List<num?>.from(daily['temperature_2m_mean']);
    final appTemps = List<num?>.from(daily['apparent_temperature_mean']);
    final precip = List<num?>.from(daily['precipitation_sum']);
    final winds = List<num?>.from(daily['wind_speed_10m_max']);

    // 1. Group indices by "Year-Month"
    final Map<String, List<int>> monthBuckets = {};

    for (int i = 0; i < dates.length; i++) {
      // Extract "YYYY-MM"
      final date = dates[i];
      final key = date.substring(0, 7);
      monthBuckets.putIfAbsent(key, () => []).add(i);
    }

    final sb = StringBuffer();
    sb.writeln('=== LAST 12 MONTHS CLIMATOLOGY (HISTORICAL ACTUALS) ===');

    // 2. Iterate buckets and calculate averages
    // Sort keys to ensure chronological order
    final sortedKeys = monthBuckets.keys.toList()..sort();

    for (final key in sortedKeys) {
      final indices = monthBuckets[key]!;

      double sumTemp = 0;
      double sumAppTemp = 0;
      double totalPrecip = 0;
      double sumWind = 0;
      int count = 0;

      for (final i in indices) {
        if (temps[i] != null && appTemps[i] != null) {
          sumTemp += temps[i]!;
          sumAppTemp += appTemps[i]!;
          totalPrecip += (precip[i] ?? 0);
          sumWind += (winds[i] ?? 0);
          count++;
        }
      }

      if (count > 0) {
        final avgTemp = sumTemp / count;
        final avgAppTemp = sumAppTemp / count;
        final avgWind = sumWind / count; // Average daily max wind

        // Convert "2024-01" to "Jan 2024" for readability
        final dateObj = DateTime.parse('$key-01');
        final monthName = DateFormat('MMM yyyy').format(dateObj);

        sb.writeln('- $monthName: Avg Temp ${avgTemp.toStringAsFixed(1)}°C '
            '(Feels ${avgAppTemp.toStringAsFixed(1)}°C), '
            'Total Rain ${totalPrecip.toStringAsFixed(1)} mm, '
            'Avg Max Wind ${avgWind.toStringAsFixed(1)} units');
      }
    }
    return sb.toString();
  } catch (e) {
    print('Error calculating monthly history: $e');
    return "Historical monthly summary unavailable.";
  }
}
