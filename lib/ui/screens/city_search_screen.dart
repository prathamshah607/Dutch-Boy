import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather/ui/screens/weather_home_screen.dart';
import 'package:weather/data/weather_providers.dart';

class CitySearchScreen extends ConsumerStatefulWidget {
  const CitySearchScreen({super.key});

  @override
  ConsumerState<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends ConsumerState<CitySearchScreen> {
  String _searchQuery = '';

  static const _bg = Color(0xFF12171D);
  static const _panel = Color(0xFF1A2228);
  static const _surface = Color(0xFF222D33);
  static const _accent = Color(0xFF6E8473);

  @override
  Widget build(BuildContext context) {
    final searchAsync = _searchQuery.isEmpty
        ? const AsyncValue<List>.data([])
        : ref.watch(citySearchProvider(_searchQuery));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: _SearchField(
          surface: _surface,
          accent: _accent,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: searchAsync.when(
        loading: () => const _StatusView(
            icon: Icons.sync,
            spinning: true,
            title: 'Searching',
            subtitle: 'Querying location database…'),
        error: (err, _) => _ErrorView(message: err.toString()),
        data: (cities) {
          if (_searchQuery.isEmpty) {
            return const _StatusView(
                icon: Icons.travel_explore,
                title: 'Search a location',
                subtitle: 'Start typing to find a city.');
          }
          if (cities.isEmpty) {
            return const _StatusView(
                icon: Icons.location_off,
                title: 'No results',
                subtitle: 'Try a different spelling or nearby city.');
          }
          return _CityList(cities: cities);
        },
      ),
    );
  }
}

// ─── _SearchField ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final Color surface;
  final Color accent;
  final ValueChanged<String> onChanged;

  const _SearchField(
      {required this.surface, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)),
      child: TextField(
        autofocus: true,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        cursorColor: accent,
        decoration: const InputDecoration(
          hintText: 'Search city',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ─── _CityList ────────────────────────────────────────────────────────────────

class _CityList extends ConsumerWidget {
  final List cities;
  const _CityList({required this.cities});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _CityCard(city: cities[index], ref: ref),
    );
  }
}

// ─── _CityCard ────────────────────────────────────────────────────────────────

class _CityCard extends StatelessWidget {
  final dynamic city;
  final WidgetRef ref;

  const _CityCard({required this.city, required this.ref});

  static const _surface = Color(0xFF222D33);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ref.read(currentCityProvider.notifier).state = city;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const WeatherHomeScreen()));
      },
      child: Container(
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12)),
                  child: const Icon(Icons.location_on_outlined,
                      color: Colors.white70, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(city.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                          [
                            if (city.admin1 != null &&
                                city.admin1!.isNotEmpty)
                              city.admin1,
                            city.country
                          ].join(', '),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
              ]),
            ),
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: _CityMetaGrid(city: city),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _CityMetaGrid ────────────────────────────────────────────────────────────

class _CityMetaGrid extends StatelessWidget {
  final dynamic city;
  const _CityMetaGrid({required this.city});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: _DataPoint('Lat', city.latitude.toStringAsFixed(3))),
          Expanded(
              child: _DataPoint('Lon', city.longitude.toStringAsFixed(3),
                  alignRight: true)),
        ]),
        if (city.elevation != null || city.timezone != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: city.elevation != null
                  ? _DataPoint('Elevation', '${city.elevation!.round()} m')
                  : const SizedBox(),
            ),
            Expanded(
              child: city.timezone != null
                  ? _DataPoint(
                      'Timezone',
                      city.timezone!
                          .split('/')
                          .last
                          .replaceAll('_', ' '),
                      alignRight: true)
                  : const SizedBox(),
            ),
          ]),
        ],
        if (city.population != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: _DataPoint(
                    'Population', _formatPopulation(city.population!))),
          ]),
        ],
      ],
    );
  }

  static String _formatPopulation(int population) {
    if (population >= 1000000) {
      return '${(population / 1000000).toStringAsFixed(1)} M';
    }
    if (population >= 1000) return '${(population / 1000).toStringAsFixed(0)} K';
    return population.toString();
  }
}

// ─── _DataPoint ───────────────────────────────────────────────────────────────

class _DataPoint extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _DataPoint(this.label, this.value, {this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: Colors.white38, fontSize: 10, letterSpacing: 0.7)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── _StatusView ──────────────────────────────────────────────────────────────

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool spinning;

  const _StatusView({
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
                      strokeWidth: 2, color: Colors.white54))
              : Icon(icon, size: 40, color: Colors.white24),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── _ErrorView ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFF2B1515),
            border: Border.all(color: const Color(0xFFEF5350))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF5350), size: 26),
            const SizedBox(height: 10),
            const Text('Search failed',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}