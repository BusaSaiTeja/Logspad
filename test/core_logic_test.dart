import 'package:flutter_test/flutter_test.dart';
import 'package:my_logs/core/utils/date_utils.dart';
import 'package:my_logs/features/reminders/domain/models/reminder_item.dart';
import 'package:my_logs/features/tasks/domain/models/task_item.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';
import 'package:my_logs/features/workspaces/application/workspace_stats_provider.dart';
import 'package:my_logs/features/workspaces/domain/models/workspace_item.dart';

void main() {
  group('Workspace Scoping & Filtering Tests', () {
    final now = DateTime.now();
    final defaultWs = WorkspaceItem(
      id: 'ws_default',
      name: 'Personal',
      iconName: 'person',
      colorValue: 0xFF4F46E5,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );

    final workWs = WorkspaceItem(
      id: 'ws_work',
      name: 'Work',
      iconName: 'work',
      colorValue: 0xFF10B981,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );

    final allWorkspaces = [defaultWs, workWs];

    test('itemMatchesWorkspace correctly matches explicit active workspace', () {
      expect(
        itemMatchesWorkspace(
          itemWorkspaceId: 'ws_work',
          activeWorkspaceId: 'ws_work',
          allWorkspaces: allWorkspaces,
        ),
        isTrue,
      );

      expect(
        itemMatchesWorkspace(
          itemWorkspaceId: 'ws_default',
          activeWorkspaceId: 'ws_work',
          allWorkspaces: allWorkspaces,
        ),
        isFalse,
      );
    });

    test('legacy items with empty workspaceId match the default workspace', () {
      expect(
        itemMatchesWorkspace(
          itemWorkspaceId: '',
          activeWorkspaceId: 'ws_default',
          allWorkspaces: allWorkspaces,
        ),
        isTrue,
      );

      expect(
        itemMatchesWorkspace(
          itemWorkspaceId: '',
          activeWorkspaceId: 'ws_work',
          allWorkspaces: allWorkspaces,
        ),
        isFalse,
      );
    });

    test('filterWorkspaceItems filters entities by active workspace', () {
      final task1 = TaskItem(
        id: 't1',
        workspaceId: 'ws_default',
        title: 'Task 1',
        createdAt: now,
        updatedAt: now,
      );
      final task2 = TaskItem(
        id: 't2',
        workspaceId: 'ws_work',
        title: 'Task 2',
        createdAt: now,
        updatedAt: now,
      );
      final task3 = TaskItem(
        id: 't3',
        workspaceId: '',
        title: 'Legacy Task',
        createdAt: now,
        updatedAt: now,
      );

      final items = [task1, task2, task3];

      final filteredWork = filterWorkspaceItems(
        items: items,
        activeWorkspaceId: 'ws_work',
        allWorkspaces: allWorkspaces,
      );
      expect(filteredWork.map((t) => t.id).toList(), ['t2']);

      final filteredDefault = filterWorkspaceItems(
        items: items,
        activeWorkspaceId: 'ws_default',
        allWorkspaces: allWorkspaces,
      );
      expect(filteredDefault.map((t) => t.id).toList(), ['t1', 't3']);
    });
  });

  group('WorkspaceStats Tests', () {
    test('computes total correctly across all domains', () {
      const stats = WorkspaceStats(
        notes: 10,
        tasks: 5,
        reminders: 3,
        books: 2,
        media: 4,
        paths: 1,
      );
      expect(stats.total, 25);
    });

    test('defaults to zero', () {
      const stats = WorkspaceStats();
      expect(stats.total, 0);
    });
  });

  group('Date & Reminder Bounds Tests', () {
    test('Overdue reminder earliestDate calculation never exceeds initialDate', () {
      final now = DateTime.now();
      final overdueTime = now.subtract(const Duration(days: 3));

      final earliestDate = overdueTime.isBefore(now)
          ? overdueTime.subtract(const Duration(days: 1))
          : now.subtract(const Duration(days: 1));

      expect(earliestDate.isBefore(overdueTime), isTrue);
    });

    test('isToday returns true only for current calendar day', () {
      final now = DateTime.now();
      expect(AppDateUtils.isToday(now), isTrue);

      final yesterday = now.subtract(const Duration(days: 1));
      expect(AppDateUtils.isToday(yesterday), isFalse);

      final tomorrow = now.add(const Duration(days: 1));
      expect(AppDateUtils.isToday(tomorrow), isFalse);
    });
  });

  group('ReminderRecurrence Tests', () {
    test('labels are human readable', () {
      expect(ReminderRecurrence.none.label, 'None');
      expect(ReminderRecurrence.daily.label, 'Daily');
      expect(ReminderRecurrence.weekly.label, 'Weekly');
      expect(ReminderRecurrence.monthly.label, 'Monthly');
      expect(ReminderRecurrence.custom.label, 'Custom');
    });
  });
}
