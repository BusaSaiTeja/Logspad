import 'package:flutter/foundation.dart';

enum AiMessageRole {
  user,
  assistant,
  system,
}

enum AiActionType {
  createTask,
  createNote,
  createReminder,
  addBook,
  addMedia,
  createLearningPath,
  unknown;

  static AiActionType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'create_task':
      case 'createtask':
        return AiActionType.createTask;
      case 'create_note':
      case 'createnote':
        return AiActionType.createNote;
      case 'create_reminder':
      case 'createreminder':
        return AiActionType.createReminder;
      case 'add_book':
      case 'addbook':
      case 'create_book':
      case 'createbook':
        return AiActionType.addBook;
      case 'add_media':
      case 'addmedia':
      case 'create_media':
      case 'createmedia':
        return AiActionType.addMedia;
      case 'create_learning_path':
      case 'createlearningpath':
        return AiActionType.createLearningPath;
      default:
        return AiActionType.unknown;
    }
  }
}

@immutable
class AiActionItem {
  const AiActionItem({
    required this.id,
    required this.type,
    required this.data,
    this.isExecuted = false,
    this.resultMessage,
    this.errorMessage,
  });

  final String id;
  final AiActionType type;
  final Map<String, dynamic> data;
  final bool isExecuted;
  final String? resultMessage;
  final String? errorMessage;

  AiActionItem copyWith({
    String? id,
    AiActionType? type,
    Map<String, dynamic>? data,
    bool? isExecuted,
    String? resultMessage,
    String? errorMessage,
  }) {
    return AiActionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      isExecuted: isExecuted ?? this.isExecuted,
      resultMessage: resultMessage ?? this.resultMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory AiActionItem.fromJson(Map<String, dynamic> json, {String? actionId}) {
    final rawType = json['type'] as String? ?? '';
    final rawData = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AiActionItem(
      id: actionId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: AiActionType.fromString(rawType),
      data: rawData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'data': data,
      'isExecuted': isExecuted,
      'resultMessage': resultMessage,
      'errorMessage': errorMessage,
    };
  }
}

@immutable
class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.actions = const [],
    this.isError = false,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime timestamp;
  final List<AiActionItem> actions;
  final bool isError;

  AiChatMessage copyWith({
    String? id,
    AiMessageRole? role,
    String? content,
    DateTime? timestamp,
    List<AiActionItem>? actions,
    bool? isError,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      actions: actions ?? this.actions,
      isError: isError ?? this.isError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'isError': isError,
    };
  }
}
