import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/widgets/app_confirmation_dialog.dart';
import 'package:my_logs/core/widgets/app_snackbar.dart';
import 'package:my_logs/features/tasks/application/task_providers.dart';
import 'package:my_logs/features/tasks/domain/models/task_item.dart';
import 'package:my_logs/features/tasks/presentation/widgets/task_date_picker_tile.dart';
import 'package:my_logs/features/tasks/presentation/widgets/task_priority_selector.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.taskId});
  final String? taskId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;

  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    if (widget.taskId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final items = ref.read(taskListProvider).valueOrNull ?? [];
        final task = items.where((t) => t.id == widget.taskId).firstOrNull;
        if (task == null) return;
        _titleCtrl.text = task.title;
        _descCtrl.text = task.description ?? '';
        setState(() {
          _priority = task.priority;
          _dueDate = task.dueDate;
        });
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<void> _save() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();
    final now = DateTime.now();

    try {
      if (_isEdit) {
        final existing = (ref.read(taskListProvider).valueOrNull ?? [])
            .where((t) => t.id == widget.taskId)
            .firstOrNull;
        if (existing != null) {
          await ref.read(taskListProvider.notifier).updateItem(existing.copyWith(
                title: _titleCtrl.text.trim(),
                description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                priority: _priority,
                dueDate: _dueDate,
                updatedAt: now,
              ));
        }
      } else {
        final activeWorkspaceId = ref.read(activeWorkspaceIdProvider).valueOrNull ?? '';
        await ref.read(taskListProvider.notifier).add(TaskItem(
              id: '',
              workspaceId: activeWorkspaceId,
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              priority: _priority,
              dueDate: _dueDate,
              createdAt: now,
              updatedAt: now,
            ));
      }

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          _isEdit ? 'Task updated successfully' : 'Task created successfully',
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/tasks');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(context, 'Failed to save task: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.primary,
          onPressed: () => context.canPop() ? context.pop() : context.go('/tasks'),
        ),
        title: Text(_isEdit ? 'Edit Task' : 'New Task',
            style: AppTypography.headlineLgMobile.copyWith(color: AppColors.primary)),
        centerTitle: false,
        actions: [
          if (_isEdit && widget.taskId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.error,
              onPressed: () async {
                final confirm = await showAppConfirmationDialog(
                  context: context,
                  title: 'Delete Task',
                  message: 'Are you sure you want to delete this task?',
                  confirmLabel: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  confirmColor: AppColors.error,
                );
                if (confirm == true && context.mounted) {
                  try {
                    await ref.read(taskListProvider.notifier).delete(widget.taskId!);
                    if (context.mounted) {
                      AppSnackBar.showSuccess(context, 'Task deleted');
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/tasks');
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackBar.showError(context, 'Failed to delete task: $e');
                    }
                  }
                }
              },
            ),
          TextButton(
            onPressed: _isSubmitting ? null : _save,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Text('Save', style: AppTypography.labelMdPrimary()),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.containerPadding),
          children: [
            _label('Title *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              decoration: const InputDecoration(hintText: 'Task title...'),
              style: AppTypography.bodyLg,
            ),
            const SizedBox(height: AppSpacing.stackGap),
            _label('Description'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Optional details...'),
              style: AppTypography.bodyLg,
            ),
            const SizedBox(height: AppSpacing.stackGap),
            _label('Priority'),
            const SizedBox(height: 8),
            TaskPrioritySelector(
              selectedPriority: _priority,
              onPrioritySelected: (p) => setState(() => _priority = p),
            ),
            const SizedBox(height: AppSpacing.stackGap),
            _label('Due Date'),
            const SizedBox(height: 6),
            TaskDatePickerTile(
              dueDate: _dueDate,
              onTap: _pickDate,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: AppTypography.labelMdVariant());
}
