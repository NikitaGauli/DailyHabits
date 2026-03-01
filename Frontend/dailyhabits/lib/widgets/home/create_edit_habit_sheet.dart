// DailyHabits — Create / Edit Habit Bottom Sheet
//
// A full-featured modal bottom sheet that allows users to create a new habit
// or edit an existing one.  Includes fields for title, description, time,
// category, frequency, as well as interactive icon and color pickers.
//
// The sheet validates input via a [Form] and delegates persistence to the
// caller-supplied [CreateEditHabitSheet.onSave] callback.
//
// See also:
// - [Habit]      — the data model constructed by this sheet.
// - [AppColors]  — predefined palette used by the color picker.

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/habit.dart';

/// A premium bottom sheet for creating or editing a habit.
///
/// When [habit] is `null` the sheet operates in **create** mode; otherwise
/// it pre-fills every field from the existing habit for **edit** mode.
///
/// The [onSave] future is awaited before dismissing the sheet, giving the
/// caller a chance to perform async work (e.g., an API call).  Errors are
/// caught and surfaced via a [SnackBar].
class CreateEditHabitSheet extends StatefulWidget {
  /// The existing habit to edit, or `null` to create a new one.
  final Habit? habit;

  /// Async callback invoked with the new/updated [Habit] on form submission.
  final Future<void> Function(Habit) onSave;

  const CreateEditHabitSheet({super.key, this.habit, required this.onSave});

  @override
  State<CreateEditHabitSheet> createState() => _CreateEditHabitSheetState();
}

// ==========================================================================
//  State
// ==========================================================================

class _CreateEditHabitSheetState extends State<CreateEditHabitSheet> {
  // ── Form key & text controllers ─────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _timeController;

  // ── Selection state ───────────────────────────────────────────────
  late String _category;
  late IconData _selectedIcon;
  late Color _selectedColor;
  late String _frequency;

  // ── Picker data sources ───────────────────────────────────────────

  /// Available habit categories presented in the dropdown.
  final List<String> _categories = [
    'Mindfulness',
    'Health',
    'Learning',
    'Fitness',
    'Productivity',
    'Finance',
    'Social',
  ];

  /// Palette of selectable colors for the habit accent.
  final List<Color> _colors = [
    AppColors.accentTertiary,
    AppColors.accent,
    AppColors.info,
    AppColors.success,
    AppColors.accentSecondary,
    AppColors.alert,
    const Color(0xFF06B6D4),
  ];

  /// Selectable Material icons for the habit tile avatar.
  final List<IconData> _icons = [
    Icons.self_improvement,
    Icons.book,
    Icons.water_drop,
    Icons.fitness_center,
    Icons.menu_book,
    Icons.attach_money,
    Icons.people,
    Icons.code,
    Icons.music_note,
    Icons.bed,
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────

  /// Initializes text controllers and picker defaults from the existing
  /// [widget.habit] (edit mode) or falls back to sensible defaults (create).
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habit?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.habit?.description ?? '',
    );
    _timeController = TextEditingController(text: widget.habit?.time ?? '');
    _category = widget.habit?.category ?? _categories.first;
    _selectedIcon = widget.habit?.icon ?? _icons.first;
    _selectedColor = widget.habit?.color ?? _colors.first;
    _frequency = widget.habit?.frequency ?? 'daily';
  }

  /// Disposes all [TextEditingController]s to prevent memory leaks.
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────

  /// Validates the form, constructs a [Habit], invokes [widget.onSave],
  /// and dismisses the sheet.  Shows a [SnackBar] on failure.
  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      // Build the Habit model from the form fields
      final newHabit = Habit(
        id: widget.habit?.id ?? '', // ID handled by backend for creates
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        time: _timeController.text.trim(),
        category: _category,
        icon: _selectedIcon,
        color: _selectedColor,
        isCompleted: widget.habit?.isCompleted ?? false,
        frequency: _frequency,
        startDate: widget.habit?.startDate ?? DateTime.now(),
      );

      try {
        await widget.onSave(newHabit);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not save habit. Try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    // Themed container with rounded top corners for bottom-sheet appearance
    return Container(
      decoration: BoxDecoration(
        color: tc.bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle indicator ─────────────────────────────────
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.habit == null ? 'New Habit' : 'Edit Habit',
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // ── Title input ─────────────────────────────────────────
              // Title Input
              _buildLabel('Title'),
              _buildTextField(
                controller: _titleController,
                hint: 'e.g. Read for 30 minutes',
                icon: Icons.edit_outlined,
              ),

              const SizedBox(height: 20),

              // ── Description input ───────────────────────────────────
              // Description Input
              _buildLabel('Description (optional)'),
              _buildTextField(
                controller: _descriptionController,
                hint: 'Why does this habit matter to you?',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              // ── Frequency dropdown ───────────────────────────────────
              // Frequency
              _buildLabel('Frequency'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tc.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: tc.border.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _frequency,
                    dropdownColor: tc.surface,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: tc.textSecondary,
                    ),
                    style: TextStyle(color: tc.textPrimary, fontSize: 16),
                    items: ['daily', 'weekly', 'custom'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value[0].toUpperCase() + value.substring(1),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() => _frequency = newValue!);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              // ── Time of day input ────────────────────────────────────
              // Time Input
              _buildLabel('Time'),
              _buildTextField(
                controller: _timeController,
                hint: 'e.g. 8:00 AM',
                icon: Icons.access_time,
              ),

              const SizedBox(height: 20),

              // ── Category dropdown ────────────────────────────────────
              // Category Dropdown
              _buildLabel('Category'),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tc.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: tc.border.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    dropdownColor: tc.surface,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: tc.textSecondary,
                    ),
                    style: TextStyle(color: tc.textPrimary, fontSize: 16),
                    items: _categories.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() => _category = newValue!);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Icon picker (horizontal scroll) ──────────────────────
              // Icon Picker
              _buildLabel('Icon'),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _icons.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final icon = _icons[index];
                    final isSelected = _selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor
                              : tc.border.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: tc.textPrimary, width: 2)
                              : null,
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? tc.textPrimary : Colors.white54,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Color picker (horizontal scroll) ─────────────────────
              // Color Picker
              _buildLabel('Color'),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: tc.textPrimary, width: 2.5)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: tc.textPrimary,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // ── Submit button ────────────────────────────────────────
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: tc.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: _selectedColor.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    widget.habit == null ? 'Add Habit' : 'Save Changes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  // ── Private helpers ───────────────────────────────────────────────

  /// Builds a small, semi-bold section label rendered above each form field.
  Widget _buildLabel(String label) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: tc.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Builds a themed [TextFormField] with an icon, hint text, and optional
  /// multi-line support.  Single-line fields are required; multi-line fields
  /// are optional.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    final tc = context.colors;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: tc.textPrimary),
      maxLines: maxLines,
      validator: (value) =>
          maxLines == 1 && (value == null || value.isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tc.textMuted),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: tc.border.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.border.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _selectedColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
