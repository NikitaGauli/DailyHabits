// =============================================================================
// File: share_habit_sheet.dart
// Description: Bottom sheet for sharing a habit with friends. Includes a friend
//              selector, visibility picker, and permission toggles.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';

/// A modal bottom sheet that lets the user share a habit with selected friends.
///
/// Displays:
/// 1. **Visibility picker** — private / friends only / public toggle chips
/// 2. **Friend list** — multi-select from loaded friends
/// 3. **Permission toggles** — can comment, can react
/// 4. **Share button** — triggers [onShare] callback
class ShareHabitSheet extends StatefulWidget {
  /// The habit ID to share.
  final int habitId;

  /// The habit title for display.
  final String habitTitle;

  /// Current visibility level.
  final String currentVisibility;

  /// List of friend maps with `id`, `name`, `currentStreak`.
  final List<Map<String, dynamic>> friends;

  /// Called when user taps Share: (friendIds, visibility, canComment, canReact).
  final void Function(
    List<int> friendIds,
    String visibility,
    bool canComment,
    bool canReact,
  )
  onShare;

  /// Called when user changes visibility only.
  final void Function(String visibility)? onVisibilityChanged;

  const ShareHabitSheet({
    super.key,
    required this.habitId,
    required this.habitTitle,
    required this.currentVisibility,
    required this.friends,
    required this.onShare,
    this.onVisibilityChanged,
  });

  @override
  State<ShareHabitSheet> createState() => _ShareHabitSheetState();
}

class _ShareHabitSheetState extends State<ShareHabitSheet> {
  late String _visibility;
  final Set<int> _selectedFriendIds = {};
  bool _canComment = true;
  bool _canReact = true;

  @override
  void initState() {
    super.initState();
    _visibility = widget.currentVisibility;
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tc.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ────────────────────────────────────────────────
          Text(
            'Share "${widget.habitTitle}"',
            style: AppTextStyles.h3.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Visibility picker ────────────────────────────────────
          _buildVisibilityPicker(tc),
          const SizedBox(height: 20),

          // ── Friend selector ──────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Share with friends',
              style: AppTextStyles.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
                color: tc.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildFriendList(tc),
          const SizedBox(height: 16),

          // ── Permission toggles ──────────────────────────────────
          _buildToggle(tc, 'Allow comments', _canComment, (v) {
            setState(() => _canComment = v);
          }),
          const SizedBox(height: 8),
          _buildToggle(tc, 'Allow reactions', _canReact, (v) {
            setState(() => _canReact = v);
          }),
          const SizedBox(height: 24),

          // ── Share button ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedFriendIds.isEmpty
                  ? null
                  : () {
                      widget.onShare(
                        _selectedFriendIds.toList(),
                        _visibility,
                        _canComment,
                        _canReact,
                      );
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: tc.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                _selectedFriendIds.isEmpty
                    ? 'Select friends to share'
                    : 'Share with ${_selectedFriendIds.length} friend${_selectedFriendIds.length > 1 ? 's' : ''}',
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Visibility picker ────────────────────────────────────────────────────
  Widget _buildVisibilityPicker(ThemeColors tc) {
    const options = [
      ('private', Icons.lock_outline, 'Private'),
      ('friends_only', Icons.people_outline, 'Friends'),
      ('public', Icons.public, 'Public'),
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = _visibility == opt.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() => _visibility = opt.$1);
                widget.onVisibilityChanged?.call(opt.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tc.primary.withValues(alpha: 0.12)
                      : tc.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? tc.primary
                        : tc.textMuted.withValues(alpha: 0.15),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      opt.$2,
                      size: 22,
                      color: isSelected ? tc.primary : tc.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt.$3,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected ? tc.primary : tc.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Friend list ──────────────────────────────────────────────────────────
  Widget _buildFriendList(ThemeColors tc) {
    if (widget.friends.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No friends yet. Add friends to share habits!',
          style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.friends.length,
        itemBuilder: (context, i) {
          final friend = widget.friends[i];
          final fId = friend['id'] as int;
          final name = friend['name'] ?? 'Friend';
          final isSelected = _selectedFriendIds.contains(fId);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedFriendIds.remove(fId);
                } else {
                  _selectedFriendIds.add(fId);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? tc.primary.withValues(alpha: 0.08)
                    : tc.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? tc.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: tc.primary.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'F',
                      style: TextStyle(
                        color: tc.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: isSelected ? tc.primary : tc.textMuted,
                      size: 22,
                      key: ValueKey(isSelected),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Toggle switch ────────────────────────────────────────────────────────
  Widget _buildToggle(
    ThemeColors tc,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: tc.primary,
        ),
      ],
    );
  }
}
