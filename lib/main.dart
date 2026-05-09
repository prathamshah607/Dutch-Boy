import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'city_search_screen.dart';

void main() async {
  await dotenv.load(fileName: '.env');
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
    const earthyBackground = Color(0xFF12171D);
    const earthySurface = Color(0xFF1A2228);
    const earthyCard = Color(0xFF232E34);
    const earthyPrimary = Color(0xFF6E8473);
    const earthySecondary = Color(0xFF4E6373);
    const earthyAccent = Color(0xFF8E755E);

    final baseText =
        GoogleFonts.publicSansTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: const Color(0xFFE4E7E5),
      displayColor: const Color(0xFFE4E7E5),
    );

    final displayText = GoogleFonts.spectralTextTheme(baseText).copyWith(
      displayLarge: GoogleFonts.spectral(
        textStyle: baseText.displayLarge,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.6,
      ),
      displayMedium: GoogleFonts.spectral(
        textStyle: baseText.displayMedium,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
      ),
      displaySmall: GoogleFonts.spectral(
        textStyle: baseText.displaySmall,
        fontWeight: FontWeight.w500,
      ),
    );

    return MaterialApp(
      title: 'Flutter Weather',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: earthyBackground,
        colorScheme: const ColorScheme.dark(
          primary: earthyPrimary,
          secondary: earthySecondary,
          tertiary: earthyAccent,
          surface: earthySurface,
          surfaceContainerHighest: earthyCard,
          error: Color(0xFFB35B5B),
          onPrimary: Color(0xFF0F1316),
          onSecondary: Color(0xFFEAF0EE),
          onSurface: Color(0xFFE4E7E5),
        ),
        textTheme: displayText,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFE4E7E5),
        ),
        cardTheme: CardThemeData(
          color: earthyCard.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x334A5D68)),
          ),
        ),
        dividerColor: const Color(0x3356646D),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF182027),
          hintStyle: const TextStyle(color: Color(0x8CA4B0B7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x3356646D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: earthyPrimary),
          ),
        ),
      ),
      home: const CitySearchScreen(),
    );
  }
}
