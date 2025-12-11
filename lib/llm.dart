import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'riverpod_interface.dart';
import 'data_calling.dart';

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
  final _wikiService = WikipediaService();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  String? _contextCache;

  // Insert your OpenAI API Key here
  static const String _openAiApiKey = '';

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

      final endHist =
          DateTime.now().subtract(const Duration(days: 5)); // 5-day lag buffer
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

WEATHER SUMMARY (FORECAST):
$weatherContext

$historyContext

WIKIPEDIA CONTEXT (GEOGRAPHY / CLIMATE / ECOLOGY):
$wikiContext
'''
          .trim();

    } catch (e) {
      _messages.add(_ChatMessage(
        role: 'assistant',
        text: 'Unable to load full context: $e',
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Sends the conversation history + context to OpenAI
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _contextCache == null) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _controller.clear();
      _loading = true;
    });

    try {
      final response = await _callOpenAI(text);

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', text: response));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
              role: 'assistant', text: 'Error while generating answer: $e'));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Raw HTTP call to OpenAI Chat Completions API
  Future<String> _callOpenAI(String userQuestion) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    // System prompt setup
    final systemPrompt = '''
You are a climate, geography, ecology, and agriculture expert integrated into the Dutch Boy weather analysis platform.

Use the CONTEXT to answer questions about this specific location, including:
- geography, topography, environment and soil-related factors
- climate regime, seasonal patterns, and typical weather
- ecology, flora, fauna, and environmental constraints
- human lifestyle, agriculture, and planning considerations influenced by climate
- interpretation of the current weather and forecast

Be concrete and location-specific. If helpful, relate your explanation to numeric climate or forecast values from the context.

CONTEXT:
$_contextCache
''';

    final messagesPayload = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userQuestion},
    ];

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini', 
        'messages': messagesPayload,
        'temperature': 0.5,
        'max_tokens': 2000,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'].toString().trim();
    } else {
      throw Exception(
          'OpenAI API Error: ${response.statusCode} - ${response.body}');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
            const Text(
              'CLIMATE ASSISTANT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
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
      ),
      body: Column(
        children: [
          if (_loading && _messages.isEmpty)
            const LinearProgressIndicator(color: Color(0xFF00D9FF)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF00D9FF).withOpacity(0.18)
                          : Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isUser ? const Color(0xFF00D9FF) : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading && _messages.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: LinearProgressIndicator(color: Color(0xFF00D9FF)),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Colors.white24, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText:
                          'Ask about climate, geography, crops, seasons, lifestyle...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00D9FF)),
                  onPressed: _loading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;

  _ChatMessage({required this.role, required this.text});
}
