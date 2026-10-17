import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_logs/features/learning_paths/application/learning_path_providers.dart';
import 'package:my_logs/features/notes/application/note_providers.dart';
import 'package:my_logs/features/read/application/book_providers.dart';
import 'package:my_logs/features/reminders/application/reminder_providers.dart';
import 'package:my_logs/features/tasks/application/task_providers.dart';
import 'package:my_logs/features/watch/application/media_providers.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';
import 'package:my_logs/features/ai_assistant/application/ai_assistant_provider.dart';

/// Centralized utility to invalidate all domain providers on logout or account deletion.
/// Prevents in-memory cache leakage between different user accounts.
void resetAllDomainProviders(WidgetRef ref) {
  ref.invalidate(taskListProvider);
  ref.invalidate(noteListProvider);
  ref.invalidate(noteCategoriesProvider);
  ref.invalidate(reminderListProvider);
  ref.invalidate(bookListProvider);
  ref.invalidate(mediaListProvider);
  ref.invalidate(learningPathListProvider);
  ref.invalidate(workspaceListProvider);
  ref.invalidate(activeWorkspaceIdProvider);
  ref.invalidate(aiAssistantProvider);
}

/// Invalidate entity list providers (e.g. after workspace deletion/reassignment).
void invalidateDomainEntityProviders(Ref ref) {
  ref.invalidate(taskListProvider);
  ref.invalidate(noteListProvider);
  ref.invalidate(reminderListProvider);
  ref.invalidate(bookListProvider);
  ref.invalidate(mediaListProvider);
  ref.invalidate(learningPathListProvider);
}
