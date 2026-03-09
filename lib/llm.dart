import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:weather_icons/weather_icons.dart';
import 'riverpod_interface.dart';
import 'data_calling.dart';
import 'weather_mapper.dart';

// ============================================================================
// WIDGET TYPE ENUM - Controls what weather widgets LLM can display
// ============================================================================
enum WeatherWidgetType {
  hourlyForecast,
  dailyForecast,
  currentConditions,
  alerts,
  uvIndex,
  precipitation,
  wind,
  activitySuggestion,
  temperatureComparison,
  none,
}

// ============================================================================
// STRUCTURED LLM RESPONSE - Contains text + widget directives
// ============================================================================
class LLMResponse {
  final String text;
  final List<WeatherWidgetType> widgets;
  final Map<String, dynamic>? widgetParams;
  final String? activitySuggestion;
  final String? alertMessage;

  LLMResponse({
    required this.text,
    this.widgets = const [],
    this.widgetParams,
    this.activitySuggestion,
    this.alertMessage,
  });

  factory LLMResponse.fromJson(Map<String, dynamic> json) {
    final widgetStrings = List<String>.from(json['widgets'] ?? []);
    final widgets = widgetStrings
        .map((w) {
          switch (w.toLowerCase()) {
            case 'hourly_forecast':
            case 'hourlyforecast':
              return WeatherWidgetType.hourlyForecast;
            case 'daily_forecast':
            case 'dailyforecast':
              return WeatherWidgetType.dailyForecast;
            case 'current_conditions':
            case 'currentconditions':
              return WeatherWidgetType.currentConditions;
            case 'alerts':
              return WeatherWidgetType.alerts;
            case 'uv_index':
            case 'uvindex':
              return WeatherWidgetType.uvIndex;
            case 'precipitation':
              return WeatherWidgetType.precipitation;
            case 'wind':
              return WeatherWidgetType.wind;
            case 'activity_suggestion':
            case 'activitysuggestion':
              return WeatherWidgetType.activitySuggestion;
            case 'temperature_comparison':
            case 'temperaturecomparison':
              return WeatherWidgetType.temperatureComparison;
            default:
              return WeatherWidgetType.none;
          }
        })
        .where((w) => w != WeatherWidgetType.none)
        .toList();

    return LLMResponse(
      text: json['text'] ?? json['response'] ?? '',
      widgets: widgets,
      widgetParams: json['widget_params'] as Map<String, dynamic>?,
      activitySuggestion: json['activity_suggestion'] as String?,
      alertMessage: json['alert'] as String?,
    );
  }

  factory LLMResponse.textOnly(String text) {
    return LLMResponse(text: text);
  }
}

// ============================================================================
// CHAT MESSAGE - Extended to hold structured responses
// ============================================================================
class ChatMessage {
  final String role;
  final String text;
  final LLMResponse? structuredResponse;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    this.structuredResponse,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ============================================================================
// MAIN PAGE - Climate Assistant with Groq + Widget Rendering
// ============================================================================
class ClimateAssistantPage extends StatefulWidget {
  final City city;
  final Map<String, dynamic> weatherData;

  const ClimateAssistantPage({
    super.key,
    required this.city,
    required this.weatherData,
  });

  @override
  State<ClimateAssistantPage> createState() => _ClimateAssistantPageState();
}

class _ClimateAssistantPageState extends State<ClimateAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _wikiService = WikipediaService();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _contextCache;

  // ==================== GROQ API CONFIGURATION ====================
  // Key is loaded from .env file (GROQ_API_KEY)
  static String get _groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  // GPT-OSS Models available on Groq:
  // - llama-3.3-70b-versatile (recommended - fast + capable)
  // - llama-3.1-8b-instant (faster, lighter)
  // - mixtral-8x7b-32768 (good for long context)
  // - gemma2-9b-it (Google's open model)
  static const String _model = 'llama-3.3-70b-versatile';
  // ================================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContext();
    });
  }

  Future<void> _loadContext() async {
    setState(() => _loading = true);
    try {
      final wikiFuture = _wikiService.getEnrichedContext(widget.city.name);

      final repo =
          ProviderScope.containerOf(context).read(weatherRepositoryProvider);

      final endHist = DateTime.now().subtract(const Duration(days: 5));
      final startHist = endHist.subtract(const Duration(days: 365));

      final historyFuture = repo.fetchHistoricalWeather(
        lat: widget.city.latitude,
        long: widget.city.longitude,
        startDate: _formatDate(startHist),
        endDate: _formatDate(endHist),
        tempUnit: 'celsius',
      );

      final results = await Future.wait([wikiFuture, historyFuture]);
      final wikiContext = results[0] as String;
      final historyData = results[1] as Map<String, dynamic>;

      final historyContext = buildMonthlyHistorySummary(historyData);
      final weatherContext = buildWeatherLLMContext(widget.weatherData);

      _contextCache = '''
CITY: ${widget.city.name}, ${widget.city.country}
LAT: ${widget.city.latitude}, LON: ${widget.city.longitude}
ELEVATION: ${widget.city.elevation ?? 'Unknown'} m
TIMEZONE: ${widget.city.timezone ?? 'Unknown'}

=== LIVE WEATHER DATA (USE THIS FOR ACCURATE RESPONSES) ===
$weatherContext

=== HISTORICAL CLIMATE DATA (LAST 12 MONTHS) ===
$historyContext

=== GEOGRAPHIC & ECOLOGICAL CONTEXT ===
$wikiContext
'''
          .trim();

      // Add welcome message with quick action suggestions
      _addWelcomeMessage();
    } catch (e) {
      _messages.add(ChatMessage(
        role: 'assistant',
        text: 'Unable to load full context: $e',
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addWelcomeMessage() {
    final current = widget.weatherData['current'];
    final temp = current['temperature_2m'].round();
    final condition = WeatherMapper.getDescription(current['weather_code']);

    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        text: '''Welcome to the Climate Assistant for ${widget.city.name}! 🌍

Current conditions: $temp°C, $condition

I can help you with:
• **Weather Analysis** - "What's the best time to go outside today?"
• **Activity Planning** - "Should I plan a picnic this weekend?"
• **Climate Insights** - "How does this week compare to typical weather?"
• **Agriculture** - "Is it a good time to plant tomatoes?"
• **Travel Tips** - "What should I pack for this weather?"

Try asking a question or tap a quick action below!''',
        structuredResponse: LLMResponse(
          text: '',
          widgets: [WeatherWidgetType.currentConditions],
        ),
      ));
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _controller.text.trim();
    if (text.isEmpty || _contextCache == null) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      if (overrideText == null) _controller.clear();
      _loading = true;
    });

    _scrollToBottom();

    try {
      final response = await _callGroq(text);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            text: response.text,
            structuredResponse: response,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            text: 'Error while generating answer: $e',
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Calls Groq API with structured JSON output for widget rendering
  Future<LLMResponse> _callGroq(String userQuestion) async {
    const url = 'https://api.groq.com/openai/v1/chat/completions';

    final systemPrompt = '''
You are an advanced climate, geography, ecology, and weather analysis AI integrated into the Dutch Boy weather platform. You have access to real-time weather data, historical climate data, and geographic context for the user's location.

YOUR CAPABILITIES:
1. Weather Analysis & Forecasting - Interpret current conditions and forecasts
2. Activity Planning - Suggest best times for outdoor activities based on weather
3. Climate Comparison - Compare current weather to historical norms
4. Agriculture Advice - Planting, harvesting, and crop guidance based on conditions
5. Health & Safety - UV exposure warnings, air quality alerts, weather hazards
6. Travel Planning - Packing suggestions, best times to visit
7. Lifestyle Recommendations - What to wear, energy usage tips

RESPONSE FORMAT:
You MUST respond with valid JSON in this exact structure:
{
  "text": "Your detailed response here with markdown formatting",
  "widgets": ["widget_type1", "widget_type2"],
  "activity_suggestion": "Optional: A specific activity recommendation",
  "alert": "Optional: Any weather warnings or alerts"
}

AVAILABLE WIDGETS (include relevant ones based on the question):
- "hourly_forecast" - Show next 12 hours of weather (use for time-specific questions)
- "daily_forecast" - Show 7-day forecast (use for multi-day planning)
- "current_conditions" - Show current weather card
- "uv_index" - Show UV exposure information
- "precipitation" - Show rain/snow probability chart
- "wind" - Show wind speed and direction
- "activity_suggestion" - Display activity recommendation card
- "temperature_comparison" - Show temp trends

GUIDELINES:
- Be specific and location-aware using the provided context
- Include relevant widgets that visually support your answer
- Use markdown formatting in text (bold, bullets, etc.)
- Reference specific data points from the context (temperatures, times, etc.)
- For activity questions, always include "activity_suggestion" widget
- For "when" questions, include "hourly_forecast" or "daily_forecast"
- Keep responses concise but informative

CONTEXT DATA:
$_contextCache
''';

    final messagesPayload = [
      {'role': 'system', 'content': systemPrompt},
      ..._messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .take(10)
          .map((m) => {
                'role': m.role,
                'content': m.role == 'assistant' && m.structuredResponse != null
                    ? m.structuredResponse!.text
                    : m.text,
              }),
      {'role': 'user', 'content': userQuestion},
    ];

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messagesPayload,
        'temperature': 0.7,
        'max_tokens': 2048,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content =
          data['choices'][0]['message']['content'].toString().trim();

      try {
        final jsonResponse = jsonDecode(content);
        return LLMResponse.fromJson(jsonResponse);
      } catch (e) {
        // Fallback if JSON parsing fails
        return LLMResponse.textOnly(content);
      }
    } else {
      throw Exception(
          'Groq API Error: ${response.statusCode} - ${response.body}');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'CLIMATE ASSISTANT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: const Color(0xFF00D9FF), width: 1),
                  ),
                  child: const Text(
                    'GROQ',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00D9FF),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              widget.city.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: () {
              setState(() {
                _messages.clear();
                _contextCache = null;
              });
              _loadContext();
            },
            tooltip: 'Reset conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading && _messages.isEmpty)
            const LinearProgressIndicator(color: Color(0xFF00D9FF)),

          // Quick Action Chips
          if (_messages.length <= 2 && !_loading) _buildQuickActions(),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          if (_loading && _messages.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: LinearProgressIndicator(color: Color(0xFF00D9FF)),
            ),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('☀️ Best time today?', 'What is the best time to go outside today?'),
      ('🌧️ Rain forecast', 'Will it rain today or this week?'),
      ('👕 What to wear', 'What should I wear based on today\'s weather?'),
      ('📊 Week outlook', 'Give me a summary of this week\'s weather'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) {
          return ActionChip(
            label: Text(action.$1, style: const TextStyle(fontSize: 11)),
            backgroundColor: Colors.black54,
            side: const BorderSide(color: Colors.white24),
            labelStyle: const TextStyle(color: Colors.white70),
            onPressed: () => _sendMessage(action.$2),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Main message bubble
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF00D9FF).withOpacity(0.18)
                    : Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUser ? const Color(0xFF00D9FF) : Colors.white24,
                  width: 1,
                ),
              ),
              child: _buildMessageContent(msg),
            ),

            // Widgets below assistant messages
            if (!isUser && msg.structuredResponse != null)
              ..._buildWidgets(msg.structuredResponse!),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg) {
    // Simple markdown-like rendering
    final text = msg.text;

    return SelectableText.rich(
      TextSpan(
        children: _parseMarkdown(text),
      ),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }

  List<TextSpan> _parseMarkdown(String text) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Bold text
      line = line.replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*'),
        (m) => '⟦BOLD⟧${m.group(1)}⟦/BOLD⟧',
      );

      // Process the line
      final parts = line.split(RegExp(r'⟦/?BOLD⟧'));
      bool isBold = false;

      for (final part in parts) {
        if (part.isEmpty) {
          isBold = !isBold;
          continue;
        }
        spans.add(TextSpan(
          text: part,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF00D9FF) : Colors.white,
          ),
        ));
        isBold = !isBold;
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  List<Widget> _buildWidgets(LLMResponse response) {
    final widgets = <Widget>[];

    for (final widgetType in response.widgets) {
      switch (widgetType) {
        case WeatherWidgetType.hourlyForecast:
          widgets.add(_buildHourlyForecastWidget());
          break;
        case WeatherWidgetType.dailyForecast:
          widgets.add(_buildDailyForecastWidget());
          break;
        case WeatherWidgetType.currentConditions:
          widgets.add(_buildCurrentConditionsWidget());
          break;
        case WeatherWidgetType.uvIndex:
          widgets.add(_buildUVWidget());
          break;
        case WeatherWidgetType.precipitation:
          widgets.add(_buildPrecipitationWidget());
          break;
        case WeatherWidgetType.wind:
          widgets.add(_buildWindWidget());
          break;
        case WeatherWidgetType.activitySuggestion:
          if (response.activitySuggestion != null) {
            widgets.add(_buildActivityWidget(response.activitySuggestion!));
          }
          break;
        case WeatherWidgetType.alerts:
          if (response.alertMessage != null) {
            widgets.add(_buildAlertWidget(response.alertMessage!));
          }
          break;
        default:
          break;
      }
    }

    return widgets;
  }

  Widget _buildHourlyForecastWidget() {
    final hourly = widget.weatherData['hourly'];
    final times = List<String>.from(hourly['time'] ?? []);
    final temps = List<num>.from(hourly['temperature_2m'] ?? []);
    final codes = List<int>.from(hourly['weather_code'] ?? []);
    final precipProbs =
        List<num>.from(hourly['precipitation_probability'] ?? []);

    final now = DateTime.parse(widget.weatherData['current']['time']);
    int startIdx = times.indexWhere((t) {
      final dt = DateTime.parse(t);
      return dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day &&
          dt.hour == now.hour;
    });
    if (startIdx < 0) startIdx = 0;

    final displayCount = 12;
    final endIdx = (startIdx + displayCount).clamp(0, times.length);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFF00D9FF), size: 16),
              const SizedBox(width: 6),
              const Text(
                'HOURLY FORECAST',
                style: TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: endIdx - startIdx,
              itemBuilder: (context, index) {
                final i = startIdx + index;
                final time = DateTime.parse(times[i]);
                final temp = temps[i].round();
                final code = codes[i];
                final rainChance = precipProbs[i].round();

                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(time),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      BoxedIcon(
                        WeatherMapper.getIcon(
                            code, time.hour >= 6 && time.hour < 20),
                        size: 20,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$temp°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (rainChance > 0)
                        Text(
                          '💧$rainChance%',
                          style: TextStyle(
                            color:
                                rainChance > 50 ? Colors.blue : Colors.white38,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyForecastWidget() {
    final daily = widget.weatherData['daily'];
    final times = List<String>.from(daily['time'] ?? []);
    final maxTemps = List<num>.from(daily['temperature_2m_max'] ?? []);
    final minTemps = List<num>.from(daily['temperature_2m_min'] ?? []);
    final codes = List<int>.from(daily['weather_code'] ?? []);
    final rainSums = List<num>.from(daily['rain_sum'] ?? []);

    final displayCount = 7.clamp(0, times.length);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: Color(0xFF00D9FF), size: 16),
              const SizedBox(width: 6),
              const Text(
                '7-DAY FORECAST',
                style: TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(displayCount, (i) {
            final date = DateTime.parse(times[i]);
            final maxTemp = maxTemps[i].round();
            final minTemp = minTemps[i].round();
            final code = codes[i];
            final rain = rainSums[i];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      i == 0 ? 'Today' : DateFormat('EEE').format(date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  BoxedIcon(
                    WeatherMapper.getIcon(code, true),
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTempBar(minTemp, maxTemp),
                  ),
                  const SizedBox(width: 8),
                  if (rain > 0)
                    Text(
                      '${rain.toStringAsFixed(1)}mm',
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTempBar(int min, int max) {
    final daily = widget.weatherData['daily'];
    final allMax = List<num>.from(daily['temperature_2m_max'] ?? []);
    final allMin = List<num>.from(daily['temperature_2m_min'] ?? []);

    final globalMin = allMin.reduce((a, b) => a < b ? a : b).toInt();
    final globalMax = allMax.reduce((a, b) => a > b ? a : b).toInt();
    final range = globalMax - globalMin;

    if (range == 0) return const SizedBox();

    final leftFraction = (min - globalMin) / range;
    final widthFraction = (max - min) / range;

    return Row(
      children: [
        Text(
          '$min°',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Padding(
                padding: EdgeInsets.only(left: leftFraction * 100),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widthFraction.clamp(0.1, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$max°',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCurrentConditionsWidget() {
    final current = widget.weatherData['current'];
    final temp = current['temperature_2m'].round();
    final feelsLike = current['apparent_temperature'].round();
    final humidity = current['relative_humidity_2m'];
    final windSpeed = current['wind_speed_10m'].round();
    final code = current['weather_code'];
    final isDay = current['is_day'] == 1;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.15),
            const Color(0xFF0A0E21).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          BoxedIcon(
            WeatherMapper.getIcon(code, isDay),
            size: 48,
            color: const Color(0xFF00D9FF),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$temp°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  WeatherMapper.getDescription(code),
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildConditionChip('Feels $feelsLike°', Icons.thermostat),
              const SizedBox(height: 4),
              _buildConditionChip('$humidity%', Icons.water_drop),
              const SizedBox(height: 4),
              _buildConditionChip('$windSpeed km/h', Icons.air),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionChip(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildUVWidget() {
    final daily = widget.weatherData['daily'];
    final uvMax = (daily['uv_index_max'] as List)[0];

    String level;
    Color color;
    if (uvMax <= 2) {
      level = 'Low';
      color = Colors.green;
    } else if (uvMax <= 5) {
      level = 'Moderate';
      color = Colors.yellow;
    } else if (uvMax <= 7) {
      level = 'High';
      color = Colors.orange;
    } else if (uvMax <= 10) {
      level = 'Very High';
      color = Colors.red;
    } else {
      level = 'Extreme';
      color = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UV INDEX: $uvMax',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  level,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecipitationWidget() {
    final hourly = widget.weatherData['hourly'];
    final times = List<String>.from(hourly['time'] ?? []);
    final precipProbs =
        List<num>.from(hourly['precipitation_probability'] ?? []);
    final precip = List<num>.from(hourly['precipitation'] ?? []);

    final now = DateTime.parse(widget.weatherData['current']['time']);
    int startIdx = times.indexWhere((t) {
      final dt = DateTime.parse(t);
      return dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day &&
          dt.hour == now.hour;
    });
    if (startIdx < 0) startIdx = 0;

    final next12 = precipProbs.sublist(
        startIdx, (startIdx + 12).clamp(0, precipProbs.length));
    final maxChance =
        next12.isNotEmpty ? next12.reduce((a, b) => a > b ? a : b) : 0;
    final totalPrecip = precip
        .sublist(startIdx, (startIdx + 12).clamp(0, precip.length))
        .fold(0.0, (sum, v) => sum + v.toDouble());

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.umbrella, color: Colors.lightBlueAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRECIPITATION (12H)',
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Max chance: $maxChance% • Total: ${totalPrecip.toStringAsFixed(1)}mm',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindWidget() {
    final current = widget.weatherData['current'];
    final windSpeed = current['wind_speed_10m'].round();
    final windDir = current['wind_direction_10m'];
    final gusts = current['wind_gusts_10m'].round();

    String direction = '';
    if (windDir >= 337.5 || windDir < 22.5)
      direction = 'N';
    else if (windDir < 67.5)
      direction = 'NE';
    else if (windDir < 112.5)
      direction = 'E';
    else if (windDir < 157.5)
      direction = 'SE';
    else if (windDir < 202.5)
      direction = 'S';
    else if (windDir < 247.5)
      direction = 'SW';
    else if (windDir < 292.5)
      direction = 'W';
    else
      direction = 'NW';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.air, color: Colors.tealAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WIND CONDITIONS',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$windSpeed km/h from $direction • Gusts up to $gusts km/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityWidget(String suggestion) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.withOpacity(0.2),
            Colors.teal.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_run,
                color: Colors.greenAccent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTIVITY SUGGESTION',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertWidget(String alert) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WEATHER ALERT',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ask about weather, activities, climate...',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF00D9FF)),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _loading ? Colors.white12 : const Color(0xFF00D9FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _loading ? Colors.white38 : Colors.black,
                  size: 20,
                ),
                onPressed: _loading ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
