import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'city_search_screen.dart';

void main() {
  // 1. Wrap the entire app in ProviderScope.
  // This is REQUIRED for Riverpod to work.
  runApp(
    const ProviderScope(
      child: WeatherApp(),
    ),
  );
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Weather',
      debugShowCheckedModeBanner: false, // Removes the little "Debug" sash
      
      // 2. Define the Global Theme
      // We start with a dark theme because weather apps usually look best dark
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple, // Sets the base tint
        fontFamily: 'SF Pro Display', // Optional: If you added custom fonts
      ),
      
      // 3. Set the Home Screen
      home: const CitySearchScreen(),
    );
  }
}
