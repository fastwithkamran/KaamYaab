import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages in-memory and persisted chat history for the AI assistant.
/// Singleton pattern to match other services in the project.
class ChatHistoryService {
  static final ChatHistoryService _i = ChatHistoryService._();
  factory ChatHistoryService() => _i;
  ChatHistoryService._();

  static const String _storageKey = 'kaamyaab_chat_history';
  static const int _maxHistory = 20;

  final List<Map<String, String>> _history = [];

  List<Map<String, String>> get history => List.unmodifiable(_history);

  /// Loads history from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        final List<dynamic> decoded = jsonDecode(saved);
        _history.clear();
        for (var item in decoded) {
          _history.add(Map<String, String>.from(item));
        }
      }
    } catch (e) {
      _history.clear();
    }
  }

  /// Adds a message to the history.
  /// [role] must be 'user' or 'chatbot' (case-insensitive).
  /// Passing any other value logs a warning and stores the message as 'CHATBOT'.
  Future<void> addMessage(String role, String message) async {
    final normalised = role.toUpperCase();
    if (normalised != 'USER' && normalised != 'CHATBOT') {
      // Catch callers passing 'assistant' or other stale Gemini-style roles.
      assert(false, 'ChatHistoryService.addMessage: unexpected role "$role". '
          'Expected "user" or "chatbot".');
    }
    _history.add({
      'role': normalised == 'USER' ? 'USER' : 'CHATBOT',
      'message': message,
    });

    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
    await _save();
  }

  /// Clears the entire chat history.
  Future<void> clear() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Converts history to Cohere format.
  List<Map<String, String>> toCohereFormat() {
    return _history.map((m) => {
      'role': m['role']!,
      'message': m['message']!,
    }).toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_history));
  }
}