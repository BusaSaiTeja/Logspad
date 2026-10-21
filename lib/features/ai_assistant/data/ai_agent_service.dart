import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:my_logs/core/config/api_config.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/features/ai_assistant/domain/models/ai_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefAiEndpointKey = 'custom_ai_agent_endpoint';

class AiAgentService {
  AiAgentService({
    required this.authService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AuthService authService;
  final http.Client _client;

  /// Retrieves the active AI backend base URL (from SharedPreferences or ApiConfig).
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(_prefAiEndpointKey)?.trim();
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    return ApiConfig.aiAgentBaseUrl.trim();
  }

  /// Sets a custom backend endpoint for local/Vercel testing.
  Future<void> setCustomEndpoint(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_prefAiEndpointKey);
    } else {
      await prefs.setString(_prefAiEndpointKey, url.trim());
    }
  }

  /// Sends the conversation to the backend Groq/Qwen agent and returns the reply and any tool actions.
  Future<({String reply, List<AiActionItem> actions})> sendPrompt({
    required List<AiChatMessage> history,
    required String activeWorkspaceId,
    List<String> enabledFeatures = const ['notes', 'tasks', 'reminders'],
    String provider = 'groq',
  }) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl.isEmpty) {
      throw const SocketException(
        'AI backend endpoint is not configured. Please set your Vercel or local API URL.',
      );
    }

    // Resolve endpoint URI
    final trimmed = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse(trimmed.endsWith('/api/chat') ? trimmed : '$trimmed/api/chat');

    // Retrieve Firebase ID token for authorization
    final currentUser = authService.currentUser;
    final idToken = await currentUser?.getIdToken();

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (idToken != null && idToken.isNotEmpty) 'Authorization': 'Bearer $idToken',
    };

    final payload = {
      'workspaceId': activeWorkspaceId,
      'enabledFeatures': enabledFeatures,
      'provider': provider,
      'messages': history
          .where((m) => !m.isError)
          .map((m) => {
                'role': m.role == AiMessageRole.user ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList(),
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final reply = data['reply'] as String? ?? 'Request processed successfully.';

        final rawActions = data['actions'] as List<dynamic>? ?? [];
        final actions = <AiActionItem>[];
        for (var i = 0; i < rawActions.length; i++) {
          final item = rawActions[i];
          if (item is Map<String, dynamic>) {
            actions.add(
              AiActionItem.fromJson(item, actionId: 'action_${DateTime.now().millisecondsSinceEpoch}_$i'),
            );
          }
        }

        return (reply: reply, actions: actions);
      } else {
        throw HttpException(
          'Backend returned status code ${response.statusCode}: ${response.body}',
          uri: uri,
        );
      }
    } on TimeoutException {
      throw const SocketException('AI agent request timed out. Please check your network and try again.');
    }
  }
}

final aiAgentServiceProvider = Provider<AiAgentService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AiAgentService(authService: authService);
});
