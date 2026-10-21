import 'package:flutter_test/flutter_test.dart';
import 'package:my_logs/features/ai_assistant/domain/models/ai_message.dart';

void main() {
  group('AiAssistant Domain & Model Tests', () {
    test('AiActionType.fromString maps action strings correctly', () {
      expect(AiActionType.fromString('create_task'), equals(AiActionType.createTask));
      expect(AiActionType.fromString('create_note'), equals(AiActionType.createNote));
      expect(AiActionType.fromString('create_reminder'), equals(AiActionType.createReminder));
      expect(AiActionType.fromString('add_book'), equals(AiActionType.addBook));
      expect(AiActionType.fromString('add_media'), equals(AiActionType.addMedia));
      expect(AiActionType.fromString('create_learning_path'), equals(AiActionType.createLearningPath));
      expect(AiActionType.fromString('unknown_tool'), equals(AiActionType.unknown));
    });

    test('AiActionItem parses from JSON and serializes', () {
      final json = {
        'type': 'create_task',
        'data': {
          'title': 'Call doctor',
          'priority': 'high',
        },
      };

      final action = AiActionItem.fromJson(json, actionId: 'test_action_1');
      expect(action.id, equals('test_action_1'));
      expect(action.type, equals(AiActionType.createTask));
      expect(action.data['title'], equals('Call doctor'));
      expect(action.isExecuted, isFalse);

      final executed = action.copyWith(
        isExecuted: true,
        resultMessage: 'Created task: "Call doctor"',
      );
      expect(executed.isExecuted, isTrue);
      expect(executed.resultMessage, equals('Created task: "Call doctor"'));

      final outJson = executed.toJson();
      expect(outJson['isExecuted'], isTrue);
      expect(outJson['type'], equals('createTask'));
    });

    test('AiChatMessage preserves messages, roles, and actions', () {
      final now = DateTime(2026, 10, 17, 12, 0);
      final msg = AiChatMessage(
        id: 'msg_1',
        role: AiMessageRole.assistant,
        content: 'I created a reminder for you.',
        timestamp: now,
        actions: [
          AiActionItem(
            id: 'a_1',
            type: AiActionType.createReminder,
            data: {'title': 'Dentist appointment'},
            isExecuted: true,
            resultMessage: 'Reminder scheduled',
          ),
        ],
      );

      expect(msg.role, equals(AiMessageRole.assistant));
      expect(msg.actions.length, equals(1));
      expect(msg.actions.first.type, equals(AiActionType.createReminder));
      expect(msg.isError, isFalse);

      final json = msg.toJson();
      expect(json['id'], equals('msg_1'));
      expect(json['role'], equals('assistant'));
    });
  });
}
