import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/runtime_config.dart';

/// Manages in-memory and persisted chat history for the AI assistant.
class ChatHistoryService {
  static final ChatHistoryService _i = ChatHistoryService._();
  factory ChatHistoryService() => _i;
  ChatHistoryService._();

  static const String _storageKey = 'kaamyaab_chat_history';

  // Max history window read from RuntimeConfig so it can be tuned without
  // touching service logic.
  static int get _maxHistory => RuntimeConfig.chatHistoryMaxMessages;

  final List<Map<String, String>> _history = [];
  List<Map<String, String>> get history => List.unmodifiable(_history);

  /// Loads persisted history from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        final List<dynamic> decoded = jsonDecode(saved);
        _history.clear();
        for (final item in decoded) {
          _history.add(Map<String, String>.from(item as Map));
        }
      }
    } catch (_) {
      _history.clear();
    }
  }

  /// Adds a message to the history.
  ///
  /// [role] must be 'user' or 'chatbot' (case-insensitive).
  /// Any other value — e.g. the legacy Gemini-style 'assistant' — is
  /// rejected in debug mode via [AssertionError] AND at runtime via an
  /// [ArgumentError] so callers are never silently misrouted in release
  /// builds.
  Future<void> addMessage(String role, String message) async {
    final normalised = role.trim().toUpperCase();
    final isValid = normalised == 'USER' || normalised == 'CHATBOT';

    // Debug: loud assertion to catch bad call sites during development.
    assert(
      isValid,
      'ChatHistoryService.addMessage: unexpected role "$role". '
      'Expected "user" or "chatbot".',
    );

    // Release: throw so callers know the message was not stored, rather than
    // silently corrupting history with an unrecognised role.
    if (!isValid) {
      if (kDebugMode) {
        debugPrint(
          'ChatHistoryService: rejected message with unknown role "$role". '
          'Allowed values: "user", "chatbot".',
        );
      }
      throw ArgumentError(
        'ChatHistoryService.addMessage: invalid role "$role". '
        'Use "user" or "chatbot".',
      );
    }

    _history.add({
      'role': normalised,       // always 'USER' or 'CHATBOT'
      'message': message,
    });

    // Enforce sliding window.
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    await _save();
  }

  /// Clears the entire chat history from memory and storage.
  Future<void> clear() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Returns history in Cohere chat format.
  List<Map<String, String>> toCohereFormat() {
    return _history
        .map((m) => {'role': m['role']!, 'message': m['message']!})
        .toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_history));
  }
}