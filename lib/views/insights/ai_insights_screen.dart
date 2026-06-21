import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../viewmodels/ai_insights_viewmodel.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final AiInsightsViewModel _viewModel = AiInsightsViewModel();
  String? _insights;
  bool _isLoading = false;
  String _apiKey = "";

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? "";
    });
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() {
      _apiKey = key;
    });
  }

  void _promptForApiKey() {
    final controller = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Gemini API Key"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "To use the AI Analyst, you need a free Gemini API key from Google AI Studio (aistudio.google.com).",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "API Key",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                await _saveApiKey(key);
                if (mounted) Navigator.pop(context);
                _generateInsights(); // Auto-start the AI analysis!
              }
            },
            child: const Text("Save Key"),
          ),
        ],
      ),
    );
  }

  void _generateInsights() async {
    if (_apiKey.isEmpty) {
      _promptForApiKey();
      return;
    }

    setState(() {
      _isLoading = true;
      _insights = null;
    });

    final result = await _viewModel.generateInsights(_apiKey);

    if (mounted) {
      setState(() {
        _insights = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF059669); // Emerald Green system
    const Color backgroundBlue = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text(
              "AI Business Analyst",
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key, color: Colors.grey),
            tooltip: "Set Gemini API Key",
            onPressed: _promptForApiKey,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 40),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Smart Sales Forecasting",
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Tap the button below to have Gemini analyze your last 30 days of sales, identify fast-moving products, and provide strategies for next month.",
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateInsights,
                      icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, color: primaryBlue),
                      label: Text(
                        _isLoading ? "Analyzing..." : "Generate Insights",
                        style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _insights == null && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.query_stats_rounded, size: 80, color: primaryBlue.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            const Text(
                              "No insights generated yet.\nClick 'Generate Insights' to start.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: _isLoading
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 24),
                                      Text(
                                        "Gemini is analyzing your data...\nThis may take a few seconds.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                )
                              : Markdown(
                                  data: _insights!,
                                  padding: const EdgeInsets.all(32),
                                  styleSheet: MarkdownStyleSheet(
                                    h1: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 24),
                                    h2: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w800, fontSize: 20),
                                    h3: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                                    p: const TextStyle(color: Color(0xFF334155), fontSize: 15, height: 1.6),
                                    listBullet: const TextStyle(color: primaryBlue, fontSize: 16),
                                    strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
