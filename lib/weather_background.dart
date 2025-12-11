import 'dart:math';
import 'package:flutter/material.dart';

class WeatherBackground extends StatelessWidget {
  final int code;
  final bool isDay;
  final String currentTimeString;
  final double aqi;

  const WeatherBackground({
    super.key,
    required this.code,
    required this.isDay,
    required this.currentTimeString,
    this.aqi = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // BASE SKY (Realistic, Mature Colors)
        Container(
          decoration: BoxDecoration(
            gradient: _getBaseSkyGradient(),
          ),
        ),


        // A. Twilight / Golden Hour (Subdued, Atmospheric)
        if (_isGoldenHour())
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0x1A4A148C),        // Deep purple tint (10%)
                  const Color(0x4DFF6F00),        // Burnt orange (30%)
                  const Color(0x66BF360C),        // Deep ember red (40%)
                ],
                stops: const [0.0, 0.3, 0.65, 1.0],
              ),
            ),
          ),

        // B. Haze / Pollution / Fog (Desaturated Grey-Brown)
        if (_isHazyOrPolluted())
          Container(
            color: const Color(0xFF424242).withOpacity(0.35), // Charcoal grey overlay
          ),

        // C. Storm Darkening (For severe weather)
        if (_isStormy())
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),        // Dark overlay top
                  Color(0x33000000),        // Lighter at horizon
                ],
              ),
            ),
          ),

        // Stars (Subtle, realistic)
        if (!isDay && !_isCloudy(code)) 
          const WeatherParticleOverlay(type: ParticleType.stars),

        // Clouds (Realistic grey tones)
        if (_isCloudy(code))
          CloudOverlay(isDark: !isDay || _isStormy()),

        // Rain (More visible, realistic streaks)
        if (_isRainy(code))
          const WeatherParticleOverlay(type: ParticleType.rain),
        
        // Snow (Soft, realistic)
        if (_isSnowy(code))
          const WeatherParticleOverlay(type: ParticleType.snow),

        // Vignette effect for depth
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  LinearGradient _getBaseSkyGradient() {
    if (!isDay) {
      // NIGHT: Deep, realistic night sky
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF000814),        // Almost black (deep space)
          Color(0xFF001D3D),        // Dark navy
          Color(0xFF003566),        // Midnight blue horizon
        ],
        stops: [0.0, 0.5, 1.0],
      );
    } else {
      // DAY: Realistic overcast/clear sky
      if (_isCloudy(code) || _isStormy()) {
        // Overcast day - grey, moody
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF546E7A),      // Steel blue-grey
            Color(0xFF78909C),      // Lighter grey
            Color(0xFF90A4AE),      // Pale grey horizon
          ],
          stops: [0.0, 0.6, 1.0],
        );
      } else {
        // Clear day - realistic blue sky
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1565C0),      // Deep sky blue
            Color(0xFF1976D2),      // Standard blue
            Color(0xFF42A5F5),      // Horizon blue
          ],
          stops: [0.0, 0.5, 1.0],
        );
      }
    }
  }

  bool _isGoldenHour() {
    try {
      final DateTime remoteTime = DateTime.parse(currentTimeString);
      final int hour = remoteTime.hour;
      return (hour >= 5 && hour < 8) || (hour >= 17 && hour < 20);
    } catch (e) {
      return false;
    }
  }

  bool _isHazyOrPolluted() {
    return aqi > 100 || code == 45 || code == 48;
  }

  bool _isStormy() {
    return code >= 95 || code == 66 || code == 67; // Thunderstorms, freezing rain
  }

  bool _isCloudy(int code) => code == 1 || code == 2 || code == 3 || code == 45 || code == 48;
  bool _isRainy(int code) => (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;
  bool _isSnowy(int code) => (code >= 71 && code <= 77) || (code >= 85 && code <= 86);
}

enum ParticleType { rain, snow, stars }

class WeatherParticleOverlay extends StatefulWidget {
  final ParticleType type;
  const WeatherParticleOverlay({super.key, required this.type});

  @override
  State<WeatherParticleOverlay> createState() => _WeatherParticleOverlayState();
}

class _WeatherParticleOverlayState extends State<WeatherParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    final duration = widget.type == ParticleType.stars
        ? const Duration(seconds: 4)
        : const Duration(seconds: 10);
    _controller = AnimationController(vsync: this, duration: duration)..repeat();

    int count = widget.type == ParticleType.stars ? 80 : 150;
    for (int i = 0; i < count; i++) {
      _particles.add(_generateParticle());
    }
  }

  Particle _generateParticle() {
    return Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      speed: _random.nextDouble() * 0.01 + 0.005,
      size: _random.nextDouble() *
              (widget.type == ParticleType.stars ? 1.5 : 2.5) +
          1,
      opacity: _random.nextDouble(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(
            particles: _particles,
            type: widget.type,
            random: _random,
            animValue: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final ParticleType type;
  final Random random;
  final double animValue;

  ParticlePainter({
    required this.particles,
    required this.type,
    required this.random,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      if (type == ParticleType.stars) {
        // Subtle twinkle
        double twinkle = (sin((animValue * 2 * pi) + (particle.x * 10)) + 1) / 2;
        particle.opacity = 0.3 + (twinkle * 0.7);
      } else {
        // Falling
        double fallSpeed = type == ParticleType.snow ? 0.15 : 1.8;
        particle.y += particle.speed * fallSpeed;
        if (particle.y > 1.0) {
          particle.y = -0.1;
          particle.x = random.nextDouble();
        }
      }

      final paint = Paint();
      final dx = particle.x * size.width;
      final dy = particle.y * size.height;

      if (type == ParticleType.rain) {
        // Realistic rain streaks (blue-white tint)
        paint.color = const Color(0xFFB0BEC5).withOpacity(particle.opacity * 0.5);
        paint.strokeWidth = 1.5;
        canvas.drawLine(
          Offset(dx, dy),
          Offset(dx - 2, dy + particle.size * 6), // Diagonal streak
          paint,
        );
      } else if (type == ParticleType.snow) {
        // Soft snow (cool white)
        paint.color = const Color(0xFFECEFF1).withOpacity(particle.opacity * 0.8);
        canvas.drawCircle(Offset(dx, dy), particle.size / 2, paint);
      } else {
        // Stars (cool white, subtle)
        paint.color = const Color(0xFFE3F2FD).withOpacity(particle.opacity * 0.6);
        canvas.drawCircle(Offset(dx, dy), particle.size / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// REALISTIC CLOUDS

class CloudOverlay extends StatefulWidget {
  final bool isDark;
  const CloudOverlay({super.key, this.isDark = false});

  @override
  State<CloudOverlay> createState() => _CloudOverlayState();
}

class _CloudOverlayState extends State<CloudOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 50),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            _buildCloud(top: 60, scale: 1.8, speed: 0.9, opacity: 0.25),
            _buildCloud(top: 150, scale: 1.3, speed: 0.6, opacity: 0.18),
            _buildCloud(top: 250, scale: 1.5, speed: 0.75, opacity: 0.15),
          ],
        );
      },
    );
  }

  Widget _buildCloud({
    required double top,
    required double scale,
    required double speed,
    required double opacity,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double offset = (screenWidth + 300) * _controller.value * speed;
    
    // Realistic cloud colors
    final Color cloudColor = widget.isDark 
        ? const Color(0xFF37474F)  // Dark grey clouds
        : const Color(0xFFCFD8DC); // Light grey clouds

    return Positioned(
      top: top,
      left: -300 + offset,
      child: Opacity(
        opacity: opacity,
        child: Icon(Icons.cloud, size: 100 * scale, color: cloudColor),
      ),
    );
  }
}
