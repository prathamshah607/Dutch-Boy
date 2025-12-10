import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather/weather_home_screen.dart';
import 'riverpod_interface.dart';

class CitySearchScreen extends ConsumerStatefulWidget {
  const CitySearchScreen({super.key});

  @override
  ConsumerState<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends ConsumerState<CitySearchScreen> {
  String _searchQuery = "";

  // Muted accent color
  static const _accent = Color(0xFF4DD0E1); // teal-ish cyan, not neon

  @override
  Widget build(BuildContext context) {
    final searchAsync = _searchQuery.isEmpty
        ? const AsyncValue.data(<City>[])
        : ref.watch(citySearchProvider(_searchQuery));

    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111217),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF08090D),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: TextField(
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            cursorColor: _accent,
            decoration: const InputDecoration(
              hintText: "Search city",
              hintStyle: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white54,
                size: 18,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white12,
          ),
        ),
      ),
      body: searchAsync.when(
        loading: () => const _CenteredStatus(
          icon: Icons.sync,
          spinning: true,
          title: "Searching",
          subtitle: "Querying location database…",
        ),
        error: (err, stack) => _ErrorPanel(message: err.toString()),
        data: (cities) {
          if (cities.isEmpty && _searchQuery.isNotEmpty) {
            return const _CenteredStatus(
              icon: Icons.location_off,
              title: "No results",
              subtitle: "Try a different spelling or nearby city.",
            );
          }

          if (_searchQuery.isEmpty) {
            return const _CenteredStatus(
              icon: Icons.travel_explore,
              title: "Search a location",
              subtitle: "Start typing to find a city.",
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final city = cities[index];

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.zero,
                  onTap: () {
                    // Update the current city
                    ref.read(currentCityProvider.notifier).state = city;

                    // Navigate to weather screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WeatherHomeScreen(),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111217),
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      city.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if (city.admin1 != null &&
                                            city.admin1!.isNotEmpty)
                                          city.admin1,
                                        city.country,
                                      ].join(", "),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white30,
                                size: 20,
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Colors.white10),

                        // METADATA GRID
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDataPoint(
                                      "Lat",
                                      city.latitude.toStringAsFixed(3),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildDataPoint(
                                      "Lon",
                                      city.longitude.toStringAsFixed(3),
                                      alignRight: true,
                                    ),
                                  ),
                                ],
                              ),
                              if (city.elevation != null ||
                                  city.timezone != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (city.elevation != null)
                                      Expanded(
                                        child: _buildDataPoint(
                                          "Elevation",
                                          "${city.elevation!.round()} m",
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                    if (city.timezone != null)
                                      Expanded(
                                        child: _buildDataPoint(
                                          "Timezone",
                                          city.timezone!
                                              .split('/')
                                              .last
                                              .replaceAll('_', ' '),
                                          alignRight: true,
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                  ],
                                ),
                              ],
                              if (city.population != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDataPoint(
                                        "Population",
                                        _formatPopulation(city.population!),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDataPoint(String label, String value,
      {bool alignRight = false}) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatPopulation(int population) {
    if (population >= 1000000) {
      return "${(population / 1000000).toStringAsFixed(1)} M";
    } else if (population >= 1000) {
      return "${(population / 1000).toStringAsFixed(0)} K";
    }
    return population.toString();
  }
}

// ===================================================================
// Helper widgets (minimal, muted)
// ===================================================================

class _CenteredStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool spinning;

  const _CenteredStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          spinning
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              : Icon(icon, size: 40, color: Colors.white24),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;

  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF2B1515),
          border: Border.all(color: const Color(0xFFEF5350), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF5350), size: 26),
            const SizedBox(height: 10),
            const Text(
              "Search failed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
