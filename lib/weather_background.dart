import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ============================================================================
// WEATHER BACKGROUND — Multi-layered compositing system
//
// Layer stack (bottom to top):
//   1. Base Sky          — time-of-day gradient (8 phases)
//   2. Weather Tint      — atmosphere modifier per weather condition
//   3. Celestial         — stars, moon glow, sun glow
//   4. Clouds            — custom-painted volumetric clouds
//   5. Atmospheric       — fog banks, haze/dust overlay
//   6. Precipitation     — rain, snow, sleet particles
//   7. Drama             — lightning flashes, vignette
// ============================================================================

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

  // --- Time helpers ---
  double get _hour {
    try {
      final dt = DateTime.parse(currentTimeString);
      return dt.hour + dt.minute / 60.0;
    } catch (_) {
      return isDay ? 12.0 : 0.0;
    }
  }

  _SkyPhase get _phase {
    final h = _hour;
    if (h >= 0 && h < 4) return _SkyPhase.deepNight;
    if (h >= 4 && h < 5.5) return _SkyPhase.preDawn;
    if (h >= 5.5 && h < 7) return _SkyPhase.dawn;
    if (h >= 7 && h < 10) return _SkyPhase.morning;
    if (h >= 10 && h < 16) return _SkyPhase.midday;
    if (h >= 16 && h < 18) return _SkyPhase.afternoon;
    if (h >= 18 && h < 20) return _SkyPhase.dusk;
    if (h >= 20 && h < 22) return _SkyPhase.twilight;
    return _SkyPhase.deepNight;
  }

  // --- Weather category helpers ---
  bool get _isClear => code == 0;
  bool get _isMainlyClear => code == 1;
  bool get _isPartlyCloudy => code == 2;
  bool get _isOvercast => code == 3;
  bool get _isFog => code == 45 || code == 48;
  bool get _isDrizzle => code >= 51 && code <= 57;
  bool get _isRain => (code >= 61 && code <= 67) || (code >= 80 && code <= 82);
  bool get _isSnow => (code >= 71 && code <= 77) || (code >= 85 && code <= 86);
  bool get _isThunderstorm => code >= 95;
  bool get _isFreezingRain => code == 66 || code == 67;
  bool get _isHeavyRain => code == 65 || code == 82;
  bool get _isHeavySnow => code == 75 || code == 86;

  bool get _hasAnyClouds =>
      _isPartlyCloudy ||
      _isOvercast ||
      _isMainlyClear ||
      _isFog ||
      _isDrizzle ||
      _isRain ||
      _isSnow ||
      _isThunderstorm;

  bool get _hasThickClouds =>
      _isOvercast || _isRain || _isSnow || _isThunderstorm || _isDrizzle;

  bool get _isStormy => _isThunderstorm || _isFreezingRain || _isHeavyRain;

  double get _cloudDensity {
    if (_isClear) return 0.0;
    if (_isMainlyClear) return 0.15;
    if (_isPartlyCloudy) return 0.35;
    if (_isFog) return 0.5;
    if (_isOvercast) return 0.7;
    if (_isDrizzle) return 0.6;
    if (_isRain) return 0.75;
    if (_isSnow) return 0.6;
    if (_isThunderstorm) return 0.9;
    return 0.3;
  }

  bool get _showStars {
    final p = _phase;
    return p == _SkyPhase.deepNight ||
        p == _SkyPhase.twilight ||
        p == _SkyPhase.preDawn;
  }

  bool get _hasPollution => aqi > 100;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // -- LAYER 1: Base Sky --
        _BaseSkyLayer(phase: _phase, hour: _hour),

        // -- LAYER 2: Weather Atmosphere Tint --
        _WeatherTintLayer(
          code: code,
          isStormy: _isStormy,
          hasThickClouds: _hasThickClouds,
          isFog: _isFog,
          isSnow: _isSnow,
          isRain: _isRain || _isDrizzle,
          phase: _phase,
        ),

        // -- LAYER 3: Celestial --
        if (_showStars && _cloudDensity < 0.7)
          _StarsLayer(
            cloudDensity: _cloudDensity,
            phase: _phase,
          ),

        if (_showStars && _cloudDensity < 0.5) _MoonGlowLayer(phase: _phase),

        if (isDay && _cloudDensity < 0.6 && !_isFog)
          _SunGlowLayer(phase: _phase, hour: _hour),

        // -- LAYER 4: Clouds --
        if (_hasAnyClouds && _cloudDensity > 0.0)
          _CloudLayer(
            density: _cloudDensity,
            isDark: !isDay || _isStormy,
            isSnowy: _isSnow,
            phase: _phase,
          ),

        // -- LAYER 5: Atmospheric --
        if (_isFog) _FogLayer(isDay: isDay),

        if (_hasPollution) _HazeLayer(aqi: aqi),

        if (_isSnow) _SnowAmbientLayer(isDay: isDay),

        // -- LAYER 6: Precipitation --
        if (_isRain || _isDrizzle)
          _PrecipitationOverlay(
            type: _isHeavyRain
                ? _PrecipType.heavyRain
                : _isDrizzle
                    ? _PrecipType.drizzle
                    : _PrecipType.rain,
          ),

        if (_isSnow)
          _PrecipitationOverlay(
            type: _isHeavySnow ? _PrecipType.heavySnow : _PrecipType.snow,
          ),

        if (_isFreezingRain)
          const _PrecipitationOverlay(type: _PrecipType.sleet),

        // -- LAYER 7: Drama --
        if (_isThunderstorm) const _LightningLayer(),

        // Vignette — always on for depth
        _VignetteLayer(intensity: _isStormy ? 0.5 : 0.25),
      ],
    );
  }
}

// ============================================================================
// SKY PHASE ENUM
// ============================================================================

enum _SkyPhase {
  deepNight,
  preDawn,
  dawn,
  morning,
  midday,
  afternoon,
  dusk,
  twilight,
}

// ============================================================================
// LAYER 1: BASE SKY
// ============================================================================

class _BaseSkyLayer extends StatelessWidget {
  final _SkyPhase phase;
  final double hour;
  const _BaseSkyLayer({required this.phase, required this.hour});

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradient(phase);
    return Container(decoration: BoxDecoration(gradient: gradient));
  }

  LinearGradient _getGradient(_SkyPhase p) {
    switch (p) {
      case _SkyPhase.deepNight:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF05060F),
            Color(0xFF0A1628),
            Color(0xFF0F2137),
          ],
          stops: [0.0, 0.55, 1.0],
        );
      case _SkyPhase.preDawn:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A1628),
            Color(0xFF1A2744),
            Color(0xFF2D3A5C),
            Color(0xFF4A3B5C),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        );
      case _SkyPhase.dawn:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B2A4A),
            Color(0xFF3D4E7C),
            Color(0xFF8E6B8A),
            Color(0xFFD4886B),
            Color(0xFFE8A87C),
          ],
          stops: [0.0, 0.25, 0.5, 0.78, 1.0],
        );
      case _SkyPhase.morning:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2266A8),
            Color(0xFF3B8CC7),
            Color(0xFF6CB4D9),
            Color(0xFFB8D8E8),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        );
      case _SkyPhase.midday:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1565C0),
            Color(0xFF1E88E5),
            Color(0xFF42A5F5),
            Color(0xFF90CAF9),
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
        );
      case _SkyPhase.afternoon:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B6DB5),
            Color(0xFF4A90C4),
            Color(0xFF8BBAD4),
            Color(0xFFD4C4A8),
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        );
      case _SkyPhase.dusk:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A2744),
            Color(0xFF3A3560),
            Color(0xFF7B4A6E),
            Color(0xFFC06040),
            Color(0xFFD9734A),
          ],
          stops: [0.0, 0.2, 0.5, 0.8, 1.0],
        );
      case _SkyPhase.twilight:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A1628),
            Color(0xFF1A2040),
            Color(0xFF2D2850),
            Color(0xFF3E2D4A),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        );
    }
  }
}

// ============================================================================
// LAYER 2: WEATHER ATMOSPHERE TINT
// ============================================================================

class _WeatherTintLayer extends StatelessWidget {
  final int code;
  final bool isStormy;
  final bool hasThickClouds;
  final bool isFog;
  final bool isSnow;
  final bool isRain;
  final _SkyPhase phase;

  const _WeatherTintLayer({
    required this.code,
    required this.isStormy,
    required this.hasThickClouds,
    required this.isFog,
    required this.isSnow,
    required this.isRain,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: _buildTint()),
    );
  }

  LinearGradient _buildTint() {
    if (isStormy) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0D1117).withOpacity(0.65),
          const Color(0xFF1B2631).withOpacity(0.55),
          const Color(0xFF1C2526).withOpacity(0.4),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }

    if (isSnow) {
      final bool isNight = phase == _SkyPhase.deepNight ||
          phase == _SkyPhase.twilight ||
          phase == _SkyPhase.preDawn;
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(isNight ? 0xFF1A2332 : 0xFFB0BEC5).withOpacity(0.3),
          Color(isNight ? 0xFF263238 : 0xFFCFD8DC).withOpacity(0.25),
          Color(isNight ? 0xFF37474F : 0xFFECEFF1).withOpacity(0.2),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }

    if (isFog) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF78909C).withOpacity(0.3),
          const Color(0xFF90A4AE).withOpacity(0.45),
          const Color(0xFFB0BEC5).withOpacity(0.55),
        ],
        stops: const [0.0, 0.4, 1.0],
      );
    }

    if (hasThickClouds) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF455A64).withOpacity(0.45),
          const Color(0xFF607D8B).withOpacity(0.35),
          const Color(0xFF78909C).withOpacity(0.25),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }

    if (isRain) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF37474F).withOpacity(0.4),
          const Color(0xFF455A64).withOpacity(0.3),
          const Color(0xFF546E7A).withOpacity(0.2),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }

    return const LinearGradient(
      colors: [Colors.transparent, Colors.transparent],
    );
  }
}

// ============================================================================
// LAYER 3a: STARS
// ============================================================================

class _StarsLayer extends StatefulWidget {
  final double cloudDensity;
  final _SkyPhase phase;
  const _StarsLayer({required this.cloudDensity, required this.phase});

  @override
  State<_StarsLayer> createState() => _StarsLayerState();
}

class _StarsLayerState extends State<_StarsLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Star> _stars;
  final _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _stars = List.generate(120, (_) => _generateStar());
  }

  _Star _generateStar() {
    final brightness = _rng.nextDouble();
    final colorRoll = _rng.nextDouble();
    Color tint;
    if (colorRoll < 0.6) {
      tint = const Color(0xFFE8EAF6); // blue-white
    } else if (colorRoll < 0.8) {
      tint = const Color(0xFFFFF8E1); // warm white
    } else if (colorRoll < 0.9) {
      tint = const Color(0xFFFFCC80); // amber
    } else {
      tint = const Color(0xFFEF9A9A); // red giant
    }
    return _Star(
      x: _rng.nextDouble(),
      y: _rng.nextDouble() * 0.7,
      size: _rng.nextDouble() * 1.8 + 0.4,
      twinkleOffset: _rng.nextDouble() * 2 * pi,
      twinkleSpeed: _rng.nextDouble() * 1.5 + 0.5,
      brightness: 0.3 + brightness * 0.7,
      color: tint,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double phaseOpacity = 1.0;
    if (widget.phase == _SkyPhase.twilight) phaseOpacity = 0.5;
    if (widget.phase == _SkyPhase.preDawn) phaseOpacity = 0.6;

    final opacity = (1.0 - widget.cloudDensity) * phaseOpacity;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _StarsPainter(
              stars: _stars,
              animValue: _ctrl.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Star {
  final double x, y, size, twinkleOffset, twinkleSpeed, brightness;
  final Color color;
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleOffset,
    required this.twinkleSpeed,
    required this.brightness,
    required this.color,
  });
}

class _StarsPainter extends CustomPainter {
  final List<_Star> stars;
  final double animValue;
  _StarsPainter({required this.stars, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final twinkle =
          (sin(animValue * 2 * pi * star.twinkleSpeed + star.twinkleOffset) +
                  1) /
              2;
      final alpha = (star.brightness * (0.4 + twinkle * 0.6)).clamp(0.0, 1.0);

      final paint = Paint()..color = star.color.withOpacity(alpha);
      if (star.size > 1.2) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
      }

      final dx = star.x * size.width;
      final dy = star.y * size.height;
      canvas.drawCircle(Offset(dx, dy), star.size, paint);

      // Larger stars get a subtle cross-spike
      if (star.size > 1.4) {
        final spikePaint = Paint()
          ..color = star.color.withOpacity(alpha * 0.3)
          ..strokeWidth = 0.5;
        final spikeLen = star.size * 2.5;
        canvas.drawLine(
            Offset(dx - spikeLen, dy), Offset(dx + spikeLen, dy), spikePaint);
        canvas.drawLine(
            Offset(dx, dy - spikeLen), Offset(dx, dy + spikeLen), spikePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => true;
}

// ============================================================================
// LAYER 3b: MOON GLOW
// ============================================================================

class _MoonGlowLayer extends StatelessWidget {
  final _SkyPhase phase;
  const _MoonGlowLayer({required this.phase});

  @override
  Widget build(BuildContext context) {
    double intensity = 0.0;
    if (phase == _SkyPhase.deepNight) intensity = 0.25;
    if (phase == _SkyPhase.twilight) intensity = 0.15;
    if (phase == _SkyPhase.preDawn) intensity = 0.12;

    return Positioned.fill(
      child: CustomPaint(
        painter: _CelestialGlowPainter(
          center: const Alignment(-0.5, -0.65),
          color: const Color(0xFFCDD5E0),
          radius: 0.25,
          intensity: intensity,
        ),
      ),
    );
  }
}

// ============================================================================
// LAYER 3c: SUN GLOW
// ============================================================================

class _SunGlowLayer extends StatelessWidget {
  final _SkyPhase phase;
  final double hour;
  const _SunGlowLayer({required this.phase, required this.hour});

  @override
  Widget build(BuildContext context) {
    double progress = ((hour - 6) / 12).clamp(0.0, 1.0);
    double xAlign = -0.6 + progress * 1.2;
    double yAlign = -0.9 + sin(progress * pi) * 0.5;

    Color glowColor;
    double intensity;
    switch (phase) {
      case _SkyPhase.dawn:
        glowColor = const Color(0xFFFFAB40);
        intensity = 0.3;
        break;
      case _SkyPhase.morning:
        glowColor = const Color(0xFFFFF176);
        intensity = 0.2;
        break;
      case _SkyPhase.midday:
        glowColor = const Color(0xFFFFF9C4);
        intensity = 0.18;
        break;
      case _SkyPhase.afternoon:
        glowColor = const Color(0xFFFFE082);
        intensity = 0.22;
        break;
      case _SkyPhase.dusk:
        glowColor = const Color(0xFFFF8A65);
        intensity = 0.35;
        break;
      default:
        glowColor = Colors.transparent;
        intensity = 0.0;
    }

    if (intensity == 0) return const SizedBox.shrink();

    return Positioned.fill(
      child: CustomPaint(
        painter: _CelestialGlowPainter(
          center: Alignment(xAlign, yAlign),
          color: glowColor,
          radius: 0.35,
          intensity: intensity,
        ),
      ),
    );
  }
}

class _CelestialGlowPainter extends CustomPainter {
  final Alignment center;
  final Color color;
  final double radius;
  final double intensity;
  _CelestialGlowPainter({
    required this.center,
    required this.color,
    required this.radius,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = (center.x + 1) / 2 * size.width;
    final cy = (center.y + 1) / 2 * size.height;
    final r = size.longestSide * radius;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        r,
        [
          color.withOpacity(intensity),
          color.withOpacity(intensity * 0.4),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _CelestialGlowPainter old) =>
      old.intensity != intensity || old.center != center;
}

// ============================================================================
// LAYER 4: CLOUDS — custom painted volumetric shapes
// ============================================================================

class _CloudLayer extends StatefulWidget {
  final double density;
  final bool isDark;
  final bool isSnowy;
  final _SkyPhase phase;
  const _CloudLayer({
    required this.density,
    required this.isDark,
    required this.isSnowy,
    required this.phase,
  });

  @override
  State<_CloudLayer> createState() => _CloudLayerState();
}

class _CloudLayerState extends State<_CloudLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_CloudBlob> _blobs;
  final _rng = Random(99);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 80),
    )..repeat();

    _generateBlobs();
  }

  void _generateBlobs() {
    final count = (4 + widget.density * 12).round();
    _blobs = List.generate(count, (i) {
      return _CloudBlob(
        xBase: _rng.nextDouble() * 1.6 - 0.3,
        y: _rng.nextDouble() * 0.55 + 0.02,
        width: _rng.nextDouble() * 0.35 + 0.15,
        height: _rng.nextDouble() * 0.06 + 0.03,
        speed: _rng.nextDouble() * 0.08 + 0.02,
        opacity: (0.15 + _rng.nextDouble() * 0.35) * widget.density,
        layerDepth: _rng.nextDouble(),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _CloudPainter(
            blobs: _blobs,
            animValue: _ctrl.value,
            isDark: widget.isDark,
            isSnowy: widget.isSnowy,
            phase: widget.phase,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CloudBlob {
  final double xBase, y, width, height, speed, opacity, layerDepth;
  const _CloudBlob({
    required this.xBase,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.opacity,
    required this.layerDepth,
  });
}

class _CloudPainter extends CustomPainter {
  final List<_CloudBlob> blobs;
  final double animValue;
  final bool isDark;
  final bool isSnowy;
  final _SkyPhase phase;

  _CloudPainter({
    required this.blobs,
    required this.animValue,
    required this.isDark,
    required this.isSnowy,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in blobs) {
      double x = (blob.xBase + animValue * blob.speed) % 1.4 - 0.2;

      final cx = x * size.width;
      final cy = blob.y * size.height;
      final w = blob.width * size.width;
      final h = blob.height * size.height;

      Color baseColor;
      if (isSnowy) {
        baseColor = isDark ? const Color(0xFF546E7A) : const Color(0xFFCFD8DC);
      } else if (isDark) {
        baseColor = Color.lerp(
            const Color(0xFF263238), const Color(0xFF37474F), blob.layerDepth)!;
      } else {
        baseColor = Color.lerp(
            const Color(0xFFECEFF1), const Color(0xFFB0BEC5), blob.layerDepth)!;
      }

      // Tint clouds during golden hours
      if (phase == _SkyPhase.dawn || phase == _SkyPhase.dusk) {
        baseColor = Color.lerp(
            baseColor, const Color(0xFFE8A87C), 0.25 * (1 - blob.layerDepth))!;
      }

      final paint = Paint()
        ..color = baseColor.withOpacity(blob.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 1.5);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
        paint,
      );

      // Brighter highlight on closer clouds
      if (blob.layerDepth > 0.4) {
        final highlightPaint = Paint()
          ..color = (isDark ? const Color(0xFF455A64) : const Color(0xFFFAFAFA))
              .withOpacity(blob.opacity * 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy - h * 0.3),
            width: w * 0.7,
            height: h * 0.5,
          ),
          highlightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => true;
}

// ============================================================================
// LAYER 5a: FOG
// ============================================================================

class _FogLayer extends StatefulWidget {
  final bool isDay;
  const _FogLayer({required this.isDay});

  @override
  State<_FogLayer> createState() => _FogLayerState();
}

class _FogLayerState extends State<_FogLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _FogPainter(
            animValue: _ctrl.value,
            isDay: widget.isDay,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FogPainter extends CustomPainter {
  final double animValue;
  final bool isDay;
  _FogPainter({required this.animValue, required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    final bands = [
      _FogBand(y: 0.55, thickness: 0.18, speed: 0.03, opacity: 0.35),
      _FogBand(y: 0.70, thickness: 0.22, speed: -0.02, opacity: 0.45),
      _FogBand(y: 0.85, thickness: 0.25, speed: 0.015, opacity: 0.55),
    ];

    for (final band in bands) {
      final cy = band.y * size.height;
      final h = band.thickness * size.height;
      final xOffset = sin(animValue * 2 * pi * 0.5) * size.width * band.speed;

      final fogColor =
          isDay ? const Color(0xFFCFD8DC) : const Color(0xFF546E7A);

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(xOffset, cy - h / 2),
          Offset(xOffset, cy + h / 2),
          [
            Colors.transparent,
            fogColor.withOpacity(band.opacity),
            fogColor.withOpacity(band.opacity * 0.8),
            Colors.transparent,
          ],
          [0.0, 0.3, 0.7, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.5);

      canvas.drawRect(
        Rect.fromLTWH(-50, cy - h / 2, size.width + 100, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FogPainter old) => true;
}

class _FogBand {
  final double y, thickness, speed, opacity;
  const _FogBand({
    required this.y,
    required this.thickness,
    required this.speed,
    required this.opacity,
  });
}

// ============================================================================
// LAYER 5b: HAZE / POLLUTION
// ============================================================================

class _HazeLayer extends StatelessWidget {
  final double aqi;
  const _HazeLayer({required this.aqi});

  @override
  Widget build(BuildContext context) {
    final severity = ((aqi - 100) / 200).clamp(0.0, 1.0);
    final opacity = 0.15 + severity * 0.3;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
                    const Color(0xFF8D6E63), const Color(0xFF6D4C41), severity)!
                .withOpacity(opacity * 0.6),
            Color.lerp(
                    const Color(0xFF9E9E9E), const Color(0xFF795548), severity)!
                .withOpacity(opacity),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LAYER 5c: SNOW AMBIENT GLOW
// ============================================================================

class _SnowAmbientLayer extends StatelessWidget {
  final bool isDay;
  const _SnowAmbientLayer({required this.isDay});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            (isDay ? const Color(0xFFE8EAF6) : const Color(0xFF37474F))
                .withOpacity(0.15),
            (isDay ? const Color(0xFFEDE7F6) : const Color(0xFF455A64))
                .withOpacity(0.3),
          ],
          stops: const [0.5, 0.8, 1.0],
        ),
      ),
    );
  }
}

// ============================================================================
// LAYER 6: PRECIPITATION
// ============================================================================

enum _PrecipType { drizzle, rain, heavyRain, snow, heavySnow, sleet }

class _PrecipitationOverlay extends StatefulWidget {
  final _PrecipType type;
  const _PrecipitationOverlay({required this.type});

  @override
  State<_PrecipitationOverlay> createState() => _PrecipitationOverlayState();
}

class _PrecipitationOverlayState extends State<_PrecipitationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Droplet> _drops;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    final count = _particleCount;
    _drops = List.generate(count, (_) => _makeDrop());
  }

  int get _particleCount {
    switch (widget.type) {
      case _PrecipType.drizzle:
        return 60;
      case _PrecipType.rain:
        return 140;
      case _PrecipType.heavyRain:
        return 250;
      case _PrecipType.snow:
        return 80;
      case _PrecipType.heavySnow:
        return 160;
      case _PrecipType.sleet:
        return 100;
    }
  }

  _Droplet _makeDrop() {
    final isSnowType =
        widget.type == _PrecipType.snow || widget.type == _PrecipType.heavySnow;
    return _Droplet(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      speed: isSnowType
          ? _rng.nextDouble() * 0.003 + 0.001
          : _rng.nextDouble() * 0.015 + 0.008,
      size: isSnowType
          ? _rng.nextDouble() * 2.5 + 1.0
          : _rng.nextDouble() * 1.5 + 0.5,
      wobble: _rng.nextDouble() * 2 * pi,
      opacity: _rng.nextDouble() * 0.5 + 0.3,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _PrecipPainter(
            drops: _drops,
            type: widget.type,
            rng: _rng,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Droplet {
  double x, y;
  final double speed, size, wobble, opacity;
  _Droplet({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.wobble,
    required this.opacity,
  });
}

class _PrecipPainter extends CustomPainter {
  final List<_Droplet> drops;
  final _PrecipType type;
  final Random rng;

  _PrecipPainter({
    required this.drops,
    required this.type,
    required this.rng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isSnowType =
        type == _PrecipType.snow || type == _PrecipType.heavySnow;
    final isSleet = type == _PrecipType.sleet;

    for (final drop in drops) {
      if (isSnowType) {
        drop.y += drop.speed;
        drop.x += sin(drop.y * 10 + drop.wobble) * 0.0008;
      } else {
        drop.y += drop.speed;
        drop.x += drop.speed * 0.08;
      }

      if (drop.y > 1.05 || drop.x > 1.1) {
        drop.y = -0.05;
        drop.x = rng.nextDouble();
      }

      final dx = drop.x * size.width;
      final dy = drop.y * size.height;

      if (isSnowType) {
        final paint = Paint()
          ..color = const Color(0xFFF5F5F5).withOpacity(drop.opacity * 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
        canvas.drawCircle(Offset(dx, dy), drop.size, paint);
      } else if (isSleet) {
        final paint = Paint()
          ..color = const Color(0xFFB0BEC5).withOpacity(drop.opacity * 0.5)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(dx, dy),
          Offset(dx + 1.5, dy + drop.size * 5),
          paint,
        );
      } else {
        final streakLen = type == _PrecipType.heavyRain
            ? drop.size * 10
            : type == _PrecipType.drizzle
                ? drop.size * 3
                : drop.size * 6;
        final paint = Paint()
          ..color = const Color(0xFFB0BEC5).withOpacity(
              drop.opacity * (type == _PrecipType.heavyRain ? 0.5 : 0.35))
          ..strokeWidth = type == _PrecipType.heavyRain ? 1.8 : 1.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(dx, dy),
          Offset(dx + streakLen * 0.15, dy + streakLen),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PrecipPainter old) => true;
}

// ============================================================================
// LAYER 7a: LIGHTNING
// ============================================================================

class _LightningLayer extends StatefulWidget {
  const _LightningLayer();

  @override
  State<_LightningLayer> createState() => _LightningLayerState();
}

class _LightningLayerState extends State<_LightningLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _flashOpacity = 0.0;
  final _rng = Random();
  double _nextFlash = 0.0;

  @override
  void initState() {
    super.initState();
    _nextFlash = _rng.nextDouble() * 0.3 + 0.1;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _ctrl.addListener(_checkFlash);
  }

  void _checkFlash() {
    final v = _ctrl.value;
    if ((v - _nextFlash).abs() < 0.01) {
      setState(() => _flashOpacity = 0.3 + _rng.nextDouble() * 0.3);
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _flashOpacity = 0.0);
      });
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _flashOpacity = 0.15 + _rng.nextDouble() * 0.15);
          Future.delayed(const Duration(milliseconds: 60), () {
            if (mounted) setState(() => _flashOpacity = 0.0);
          });
        }
      });
      _nextFlash = v + _rng.nextDouble() * 0.4 + 0.15;
      if (_nextFlash > 1.0) _nextFlash -= 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_checkFlash);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        color: Color.lerp(
          Colors.transparent,
          const Color(0xFFE1F5FE),
          _flashOpacity,
        ),
      ),
    );
  }
}

// ============================================================================
// LAYER 7b: VIGNETTE
// ============================================================================

class _VignetteLayer extends StatelessWidget {
  final double intensity;
  const _VignetteLayer({required this.intensity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(intensity),
            ],
            stops: const [0.45, 1.0],
          ),
        ),
      ),
    );
  }
}
