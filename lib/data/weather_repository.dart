import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final weatherRepositoryProvider = Provider((ref) => WeatherRepository(Dio()));

class WeatherRepository {
  final Dio _dio;

  static const String _forecastUrl   = 'https://api.open-meteo.com/v1/forecast';
  static const String _archiveUrl    = 'https://archive-api.open-meteo.com/v1/archive';
  static const String _airQualityUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String _geocodingUrl  = 'https://geocoding-api.open-meteo.com/v1/search';

  WeatherRepository(this._dio);

  // ─── Geocoding ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchCity(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final response = await _dio.get(_geocodingUrl, queryParameters: {
        'name': query,
        'count': 10,
        'language': 'en',
        'format': 'json',
      });
      final data = response.data;
      if (data == null || data['results'] == null) return [];
      final List results = data['results'];
      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('Geocoding Error: $e');
      return [];
    }
  }

  // ─── Comprehensive Forecast ────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchComprehensiveWeather({
    required double lat,
    required double long,
    String tempUnit   = 'celsius',
    String speedUnit  = 'kmh',
    String precipUnit = 'mm',
    int forecastDays  = 16,
  }) async {
    try {
      final results = await Future.wait([
        _fetchForecast(lat, long, tempUnit, speedUnit, precipUnit, forecastDays),
        _fetchAirQuality(lat, long),
      ]);
      final forecastData   = results[0];
      final airQualityData = results[1];
      forecastData['air_quality'] = airQualityData;
      return forecastData;
    } catch (e) {
      throw Exception('Failed to aggregate weather data: $e');
    }
  }

  // ─── Forecast (private) ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchForecast(
    double lat,
    double long,
    String tempUnit,
    String speedUnit,
    String precipUnit,
    int forecastDays,
  ) async {
    final response = await _dio.get(_forecastUrl, queryParameters: {
      'latitude':           lat,
      'longitude':          long,
      'temperature_unit':   tempUnit,
      'wind_speed_unit':    speedUnit,
      'precipitation_unit': precipUnit,
      'timezone':           'auto',
      'forecast_days':      forecastDays,

      // ── CURRENT CONDITIONS ────────────────────────────────────────────────
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'is_day',
        'precipitation',
        'rain',
        'showers',
        'snowfall',
        'weather_code',
        'cloud_cover',
        'pressure_msl',
        'surface_pressure',
        'wind_speed_10m',
        'wind_direction_10m',
        'wind_gusts_10m',
      ].join(','),

      // ── HOURLY ────────────────────────────────────────────────────────────
      // All variable names verified against open-meteo.com/en/docs
      'hourly': [

        // Temperature & Humidity
        'temperature_2m',
        'relative_humidity_2m',
        'dew_point_2m',
        'apparent_temperature',
        'vapour_pressure_deficit',    // kPa — plant/crop stress indicator

        // Precipitation
        'precipitation_probability',
        'precipitation',
        'rain',
        'showers',
        'snowfall',                   // cm
        'snow_depth',                 // metres — accumulated snowpack
        'freezing_level_height',      // metres — 0°C isotherm altitude

        // Pressure & Instability
        'pressure_msl',
        'surface_pressure',
        'cape',                       // J/kg — storm energy proxy

        // Evapotranspiration
        'et0_fao_evapotranspiration', // mm/hr — FAO-56 reference ET
        'evapotranspiration',         // mm/hr — actual land surface ET

        // Wind (multi-level — all confirmed in docs)
        'wind_speed_10m',
        'wind_speed_80m',             // rotor-swept layer
        'wind_speed_120m',
        'wind_speed_180m',
        'wind_direction_10m',
        'wind_direction_80m',
        'wind_direction_120m',
        'wind_direction_180m',
        'wind_gusts_10m',

        // Cloud Cover (by altitude layer)
        'cloud_cover',
        'cloud_cover_low',            // < 3 km
        'cloud_cover_mid',            // 3–8 km
        'cloud_cover_high',           // > 8 km

        // Solar & Radiation (all confirmed in docs)
        'shortwave_radiation',        // W/m² global horizontal irradiance
        'direct_radiation',           // W/m² beam on horizontal plane
        'direct_normal_irradiance',   // W/m² DNI — perpendicular to sun
        'diffuse_radiation',          // W/m² scattered radiation
        'uv_index',
        'uv_index_clear_sky',         // UV under cloud-free conditions

        // Soil
        'soil_temperature_0cm',
        'soil_temperature_6cm',
        'soil_temperature_18cm',
        'soil_temperature_54cm',
        'soil_moisture_0_to_1cm',
        'soil_moisture_1_to_3cm',
        'soil_moisture_3_to_9cm',
        'soil_moisture_9_to_27cm',
        'soil_moisture_27_to_81cm',

        // Visibility & State
        'visibility',
        'is_day',
        'weather_code',

      ].join(','),

      // ── DAILY ─────────────────────────────────────────────────────────────
      // Only the parameters listed in the Daily Parameter Definition table
      'daily': [

        // Identity & Sun
        'weather_code',
        'sunrise',
        'sunset',
        'daylight_duration',          // seconds
        'sunshine_duration',          // seconds (WMO definition ≥120 W/m²)

        // Temperature
        'temperature_2m_max',
        'temperature_2m_min',
        'temperature_2m_mean',
        'apparent_temperature_max',
        'apparent_temperature_min',
        'apparent_temperature_mean',

        // Precipitation
        'precipitation_sum',
        'rain_sum',
        'showers_sum',
        'snowfall_sum',
        'precipitation_hours',
        'precipitation_probability_max',
        'precipitation_probability_min',
        'precipitation_probability_mean',

        // Wind
        'wind_speed_10m_max',
        'wind_gusts_10m_max',
        'wind_direction_10m_dominant',

        // Radiation & ET
        'shortwave_radiation_sum',    // MJ/m²
        'et0_fao_evapotranspiration', // mm/day

        // UV
        'uv_index_max',
        'uv_index_clear_sky_max',

        // Humidity (max only — confirmed in docs)
        'relative_humidity_2m_max',

        // Pressure (confirmed in original codebase)
        'surface_pressure_mean',

      ].join(','),
    });
    return response.data;
  }

  // ─── Air Quality (private) ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchAirQuality(double lat, double long) async {
    try {
      final response = await _dio.get(_airQualityUrl, queryParameters: {
        'latitude':      lat,
        'longitude':     long,
        'timezone':      'auto',
        'forecast_days': 5,
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
          'uv_index',
          'uv_index_clear_sky',
          'ammonia',
          'aerosol_optical_depth',
          'methane',
        ].join(','),
        'hourly': [
          'pm10',
          'pm2_5',
          'carbon_monoxide',
          'nitrogen_dioxide',
          'sulphur_dioxide',
          'ozone',
          'dust',
          'uv_index',
          'uv_index_clear_sky',
          'ammonia',
          'aerosol_optical_depth',
          'european_aqi',
          'european_aqi_pm2_5',
          'european_aqi_pm10',
          'european_aqi_nitrogen_dioxide',
          'european_aqi_ozone',
          'european_aqi_sulphur_dioxide',
          'us_aqi',
          'us_aqi_pm2_5',
          'us_aqi_pm10',
          'us_aqi_nitrogen_dioxide',
          'us_aqi_carbon_monoxide',
          'us_aqi_ozone',
          'us_aqi_sulphur_dioxide',
          // Pollen — returns null out of season, never crashes
          'alder_pollen',
          'birch_pollen',
          'grass_pollen',
          'mugwort_pollen',
          'olive_pollen',
          'ragweed_pollen',
        ].join(','),
      });
      return response.data;
    } catch (e) {
      if (kDebugMode) debugPrint('Air Quality API Error: $e');
      return {'current': {}, 'hourly': {}};
    }
  }

  // ─── Historical Archive ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchHistoricalWeather({
    required double lat,
    required double long,
    required String startDate,
    required String endDate,
    String tempUnit   = 'celsius',
    String speedUnit  = 'kmh',
    String precipUnit = 'mm',
  }) async {
    try {
      final response = await _dio.get(_archiveUrl, queryParameters: {
        'latitude':           lat,
        'longitude':          long,
        'start_date':         startDate,
        'end_date':           endDate,
        'temperature_unit':   tempUnit,
        'wind_speed_unit':    speedUnit,
        'precipitation_unit': precipUnit,
        'timezone':           'auto',

        // Archive API daily variables — same valid set as forecast daily
        // plus a few archive-only extras confirmed in the archive docs
        'daily': [

          // Identity & Sun
          'weather_code',
          'sunrise',
          'sunset',
          'daylight_duration',
          'sunshine_duration',

          // Temperature
          'temperature_2m_max',
          'temperature_2m_min',
          'temperature_2m_mean',
          'apparent_temperature_max',
          'apparent_temperature_min',
          'apparent_temperature_mean',

          // Precipitation
          'precipitation_sum',
          'rain_sum',
          'showers_sum',
          'snowfall_sum',
          'precipitation_hours',

          // Wind
          'wind_speed_10m_max',
          'wind_gusts_10m_max',
          'wind_direction_10m_dominant',

          // Radiation & ET
          'shortwave_radiation_sum',
          'et0_fao_evapotranspiration',

          // UV
          'uv_index_max',
          'uv_index_clear_sky_max',

          // Humidity & Pressure
          'relative_humidity_2m_max',
          'surface_pressure_mean',

        ].join(','),
      });
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch historical weather: $e');
    }
  }

  // ─── Utility ───────────────────────────────────────────────────────────────

  static String buildMonthlyHistorySummary(Map<String, dynamic> historicalData) {
    try {
      final daily    = historicalData['daily'] as Map;
      final dates    = List<String>.from(daily['time']);
      final temps    = List<num?>.from(daily['temperature_2m_mean']);
      final appTemps = List<num?>.from(daily['apparent_temperature_mean']);
      final precip   = List<num?>.from(daily['precipitation_sum']);
      final winds    = List<num?>.from(daily['wind_speed_10m_max']);
      final radiation = List<num?>.from(daily['shortwave_radiation_sum'] ?? []);
      final et0      = List<num?>.from(daily['et0_fao_evapotranspiration'] ?? []);

      final Map<String, List<int>> monthBuckets = {};
      for (int i = 0; i < dates.length; i++) {
        monthBuckets.putIfAbsent(dates[i].substring(0, 7), () => []).add(i);
      }

      final sb = StringBuffer();
      sb.writeln('=== MONTHLY CLIMATOLOGY (HISTORICAL ACTUALS) ===');

      for (final key in (monthBuckets.keys.toList()..sort())) {
        final idx = monthBuckets[key]!;
        double sumTemp = 0, sumApp = 0, totalPrecip = 0,
               sumWind = 0, sumRad = 0, sumET0 = 0;
        int count = 0;

        for (final i in idx) {
          if (temps[i] != null && appTemps[i] != null) {
            sumTemp     += temps[i]!.toDouble();
            sumApp      += appTemps[i]!.toDouble();
            totalPrecip += (precip[i] ?? 0).toDouble();
            sumWind     += (winds[i] ?? 0).toDouble();
            if (radiation.isNotEmpty && i < radiation.length) {
              sumRad    += (radiation[i] ?? 0).toDouble();
            }
            if (et0.isNotEmpty && i < et0.length) {
              sumET0    += (et0[i] ?? 0).toDouble();
            }
            count++;
          }
        }

        if (count > 0) {
          final monthName =
              DateFormat('MMM yyyy').format(DateTime.parse('$key-01'));
          sb.writeln(
            '- $monthName: '
            'Avg ${(sumTemp / count).toStringAsFixed(1)}° '
            '(Feels ${(sumApp / count).toStringAsFixed(1)}°), '
            'Rain ${totalPrecip.toStringAsFixed(1)} mm, '
            'Wind ${(sumWind / count).toStringAsFixed(1)} km/h, '
            'Solar ${(sumRad / count).toStringAsFixed(1)} MJ/m², '
            'ET₀ ${sumET0.toStringAsFixed(1)} mm',
          );
        }
      }
      return sb.toString();
    } catch (e) {
      if (kDebugMode) debugPrint('Monthly summary error: $e');
      return 'Historical monthly summary unavailable.';
    }
  }
}