import 'package:flutter/material.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/features/reminders/domain/models/reminder_item.dart';

class ReminderRecurrenceSelector extends StatefulWidget {
  const ReminderRecurrenceSelector({
    super.key,
    required this.selectedRecurrence,
    required this.onRecurrenceSelected,
    this.customTextController,
    this.onCustomTextChanged,
  });

  final ReminderRecurrence selectedRecurrence;
  final ValueChanged<ReminderRecurrence> onRecurrenceSelected;
  final TextEditingController? customTextController;
  final ValueChanged<String>? onCustomTextChanged;

  /// Parses weekday string (e.g. "Mon, Wed, Fri", "Weekdays", "Every day") into 1..7 (Mon..Sun)
  static Set<int> parseWeekdays(String? text) => ReminderWeekdayUtils.parseWeekdays(text);

  /// Formats a set of 1..7 weekdays into a human-readable alarm label
  static String formatWeekdays(Set<int> days) => ReminderWeekdayUtils.formatWeekdays(days);


  @override
  State<ReminderRecurrenceSelector> createState() => _ReminderRecurrenceSelectorState();
}

class _ReminderRecurrenceSelectorState extends State<ReminderRecurrenceSelector> {
  late Set<int> _selectedDays;

  static const _daysMeta = [
    (day: 1, letter: 'M', name: 'Monday'),
    (day: 2, letter: 'T', name: 'Tuesday'),
    (day: 3, letter: 'W', name: 'Wednesday'),
    (day: 4, letter: 'T', name: 'Thursday'),
    (day: 5, letter: 'F', name: 'Friday'),
    (day: 6, letter: 'S', name: 'Saturday'),
    (day: 7, letter: 'S', name: 'Sunday'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDays = ReminderRecurrenceSelector.parseWeekdays(widget.customTextController?.text);
    if (_selectedDays.isEmpty && widget.selectedRecurrence == ReminderRecurrence.custom) {
      _selectedDays = {DateTime.now().weekday};
      _updateText();
    }
  }

  @override
  void didUpdateWidget(ReminderRecurrenceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRecurrence == ReminderRecurrence.custom &&
        oldWidget.selectedRecurrence != ReminderRecurrence.custom &&
        _selectedDays.isEmpty) {
      _selectedDays = {DateTime.now().weekday};
      _updateText();
    } else if (widget.customTextController?.text != oldWidget.customTextController?.text) {
      final parsed = ReminderRecurrenceSelector.parseWeekdays(widget.customTextController?.text);
      if (parsed.isNotEmpty || _selectedDays.isNotEmpty) {
        _selectedDays = parsed;
      }
    }
  }

  void _updateText() {
    final text = ReminderRecurrenceSelector.formatWeekdays(_selectedDays);
    widget.customTextController?.text = text;
    widget.onCustomTextChanged?.call(text);
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _updateText();
    });
  }

  void _setPreset(Set<int> days) {
    setState(() {
      _selectedDays = Set<int>.from(days);
      _updateText();
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = ReminderRecurrenceSelector.formatWeekdays(_selectedDays);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ReminderRecurrence.values.map((r) {
              final isSelected = r == widget.selectedRecurrence;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${r.label} Recurrence',
                  child: GestureDetector(
                    onTap: () {
                      widget.onRecurrenceSelected(r);
                      if (r == ReminderRecurrence.custom && _selectedDays.isEmpty) {
                        setState(() {
                          _selectedDays = {DateTime.now().weekday};
                          _updateText();
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                        boxShadow: isSelected ? AppColors.cardShadow : null,
                      ),
                      child: Center(
                        child: Text(
                          r.label,
                          style: AppTypography.labelMd.copyWith(
                            color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (widget.selectedRecurrence == ReminderRecurrence.custom) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alarm_on_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Repeat on',
                      style: AppTypography.labelMdPrimary().copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      summary.isEmpty ? 'No days selected' : summary,
                      style: AppTypography.labelMd.copyWith(
                        color: summary.isEmpty ? AppColors.error : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Standard alarm circular day-of-week buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _daysMeta.map((meta) {
                    final isDaySelected = _selectedDays.contains(meta.day);
                    return Semantics(
                      button: true,
                      selected: isDaySelected,
                      label: meta.name,
                      child: GestureDetector(
                        onTap: () => _toggleDay(meta.day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDaySelected ? AppColors.primary : AppColors.surfaceContainerLow,
                            border: Border.all(
                              color: isDaySelected
                                  ? AppColors.primary
                                  : AppColors.outline.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            boxShadow: isDaySelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              meta.letter,
                              style: AppTypography.labelMd.copyWith(
                                color: isDaySelected
                                    ? AppColors.onPrimary
                                    : AppColors.onSurfaceVariant,
                                fontWeight: isDaySelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Quick preset pills
                Row(
                  children: [
                    _PresetChip(
                      label: 'Weekdays',
                      isSelected: _selectedDays.length == 5 && _selectedDays.containsAll({1, 2, 3, 4, 5}),
                      onTap: () => _setPreset({1, 2, 3, 4, 5}),
                    ),
                    const SizedBox(width: 8),
                    _PresetChip(
                      label: 'Weekends',
                      isSelected: _selectedDays.length == 2 && _selectedDays.containsAll({6, 7}),
                      onTap: () => _setPreset({6, 7}),
                    ),
                    const SizedBox(width: 8),
                    _PresetChip(
                      label: 'Every day',
                      isSelected: _selectedDays.length == 7,
                      onTap: () => _setPreset({1, 2, 3, 4, 5, 6, 7}),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

