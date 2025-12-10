import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

class WeatherMapper {
  /// Returns the specific WeatherIcon based on WMO code and time of day.
  /// 
  /// [code] The WMO weather code (0-99).
  /// [isDay] 1 = Day, 0 = Night (matches Open-Meteo 'is_day' variable).
  static IconData getIcon(int code, bool isDay) {
    if (isDay) {
      return _getDayIcon(code);
    } else {
      return _getNightIcon(code);
    }
  }

  /// Returns a human-readable description of the weather.
  static String getDescription(int code) {
    switch (code) {
      case 0: return 'Clear Sky';
      case 1: return 'Mainly Clear';
      case 2: return 'Partly Cloudy';
      case 3: return 'Overcast';
      case 45: return 'Foggy';
      case 48: return 'Depositing Rime Fog';
      case 51: return 'Light Drizzle';
      case 53: return 'Moderate Drizzle';
      case 55: return 'Dense Drizzle';
      case 56: return 'Light Freezing Drizzle';
      case 57: return 'Dense Freezing Drizzle';
      case 61: return 'Slight Rain';
      case 63: return 'Moderate Rain';
      case 65: return 'Heavy Rain';
      case 66: return 'Light Freezing Rain';
      case 67: return 'Heavy Freezing Rain';
      case 71: return 'Slight Snow Fall';
      case 73: return 'Moderate Snow Fall';
      case 75: return 'Heavy Snow Fall';
      case 77: return 'Snow Grains';
      case 80: return 'Slight Rain Showers';
      case 81: return 'Moderate Rain Showers';
      case 82: return 'Violent Rain Showers';
      case 85: return 'Slight Snow Showers';
      case 86: return 'Heavy Snow Showers';
      case 95: return 'Thunderstorm';
      case 96: return 'Thunderstorm & Hail';
      case 99: return 'Thunderstorm & Heavy Hail';
      default: return 'Unknown';
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  static IconData _getDayIcon(int code) {
    switch (code) {
      case 0: return WeatherIcons.day_sunny;
      case 1: return WeatherIcons.day_sunny_overcast;
      case 2: return WeatherIcons.day_cloudy;
      case 3: return WeatherIcons.cloudy; // Overcast is same day/night
      case 45: return WeatherIcons.day_fog;
      case 48: return WeatherIcons.day_fog;
      case 51: case 53: case 55: return WeatherIcons.day_sprinkle;
      case 56: case 57: return WeatherIcons.day_rain_mix;
      case 61: return WeatherIcons.day_showers;
      case 63: return WeatherIcons.day_rain;
      case 65: return WeatherIcons.day_rain;
      case 66: case 67: return WeatherIcons.day_sleet;
      case 71: return WeatherIcons.day_snow;
      case 73: return WeatherIcons.day_snow;
      case 75: return WeatherIcons.day_snow;
      case 77: return WeatherIcons.day_hail;
      case 80: return WeatherIcons.day_showers;
      case 81: return WeatherIcons.day_showers;
      case 82: return WeatherIcons.day_storm_showers;
      case 85: return WeatherIcons.day_snow;
      case 86: return WeatherIcons.day_snow;
      case 95: return WeatherIcons.day_thunderstorm;
      case 96: case 99: return WeatherIcons.day_storm_showers;
      default: return WeatherIcons.day_sunny;
    }
  }

  static IconData _getNightIcon(int code) {
    switch (code) {
      case 0: return WeatherIcons.night_clear;
      case 1: return WeatherIcons.night_alt_partly_cloudy;
      case 2: return WeatherIcons.night_alt_cloudy;
      case 3: return WeatherIcons.cloudy;
      case 45: return WeatherIcons.night_fog;
      case 48: return WeatherIcons.night_fog;
      case 51: case 53: case 55: return WeatherIcons.night_sprinkle;
      case 56: case 57: return WeatherIcons.night_alt_rain_mix;
      case 61: return WeatherIcons.night_alt_showers;
      case 63: return WeatherIcons.night_alt_rain;
      case 65: return WeatherIcons.night_alt_rain;
      case 66: case 67: return WeatherIcons.night_alt_sleet;
      case 71: return WeatherIcons.night_alt_snow;
      case 73: return WeatherIcons.night_alt_snow;
      case 75: return WeatherIcons.night_alt_snow;
      case 77: return WeatherIcons.night_alt_hail;
      case 80: return WeatherIcons.night_alt_showers;
      case 81: return WeatherIcons.night_alt_showers;
      case 82: return WeatherIcons.night_alt_storm_showers;
      case 85: return WeatherIcons.night_alt_snow;
      case 86: return WeatherIcons.night_alt_snow;
      case 95: return WeatherIcons.night_thunderstorm;
      case 96: case 99: return WeatherIcons.night_alt_storm_showers;
      default: return WeatherIcons.night_clear;
    }
  }
}
