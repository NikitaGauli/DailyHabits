// =============================================================================
// File: create_collaborative_habit_screen.dart
// Description: Screen for creating a new collaborative habit with title,
//              description, emoji, frequency, privacy, and gamification settings.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'grow_together_controller.dart';

/// Form screen to create a new collaborative habit.
class CreateCollaborativeHabitScreen extends StatefulWidget {
  const CreateCollaborativeHabitScreen({super.key});

  @override
  State<CreateCollaborativeHabitScreen> createState() =>
      _CreateCollaborativeHabitScreenState();
}

class _CreateCollaborativeHabitScreenState
    extends State<CreateCollaborativeHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _emoji = '🎯';
  String _frequency = 'daily';
  String _privacy = 'friends_only';
  int _targetCount = 1;
  int _maxMembers = 50;
  int _xpPerCompletion = 15;

  final List<String> _emojis = [
    '🎯', '💪', '📚', '🏃', '🧘', '💧', '🍎', '😴', '🎨', '🎵',
    '🌱', '🔥', '⭐', '🏋️', '📝', '🧠', '❤️', '🌞', '🍳', '🚀',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Create Collaborative Habit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Emoji Picker ──────────────────────────────────────
            Text('Choose an Emoji',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((e) {
                final selected = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? colors.primary
                            : colors.outline.withValues(alpha: 0.2),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Habit Title',
                hintText: 'e.g., Morning Meditation',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),

            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this habit about?',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            // ── Frequency ─────────────────────────────────────────
            Text('Frequency',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'custom', label: Text('Custom')),
              ],
              selected: {_frequency},
              onSelectionChanged: (v) =>
                  setState(() => _frequency = v.first),
            ),

            const SizedBox(height: 20),

            // ── Privacy ───────────────────────────────────────────
            Text('Privacy',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'private',
                  label: Text('Private'),
                  icon: Icon(Icons.lock, size: 16),
                ),
                ButtonSegment(
                  value: 'friends_only',
                  label: Text('Friends'),
                  icon: Icon(Icons.people, size: 16),
                ),
                ButtonSegment(
                  value: 'public',
                  label: Text('Public'),
                  icon: Icon(Icons.public, size: 16),
                ),
              ],
              selected: {_privacy},
              onSelectionChanged: (v) =>
                  setState(() => _privacy = v.first),
            ),

            const SizedBox(height: 20),

            // ── Settings Row ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Target/Day',
                    value: _targetCount,
                    onChanged: (v) => setState(() => _targetCount = v),
                    min: 1,
                    max: 100,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _NumberField(
                    label: 'Max Members',
                    value: _maxMembers,
                    onChanged: (v) => setState(() => _maxMembers = v),
                    min: 2,
                    max: 100,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _NumberField(
                    label: 'XP/Complete',
                    value: _xpPerCompletion,
                    onChanged: (v) => setState(() => _xpPerCompletion = v),
                    min: 5,
                    max: 100,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: ctrl.isActionLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: ctrl.isActionLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Habit',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ctrl = context.read<GrowTogetherController>();
    final ok = await ctrl.createHabit(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      emoji: _emoji,
      frequency: _frequency,
      privacy: _privacy,
      targetCount: _targetCount,
      maxMembers: _maxMembers,
      xpPerCompletion: _xpPerCompletion,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaborative habit created! 🎉')),
      );
      Navigator.pop(context);
    } else if (mounted && ctrl.actionMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.actionMessage!)),
      );
    }
  }
}

// =============================================================================
// Number Field Helper
// =============================================================================

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.6),
            )),
        const SizedBox(height: 4),
        Row(
          children: [
            InkWell(
              onTap: value > min ? () => onChanged(value - 1) : null,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.remove, size: 16, color: colors.primary),
              ),
            ),
            Expanded(
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            InkWell(
              onTap: value < max ? () => onChanged(value + 1) : null,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, size: 16, color: colors.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
