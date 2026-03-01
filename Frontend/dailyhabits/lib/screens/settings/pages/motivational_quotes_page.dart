// =============================================================================
// File: motivational_quotes_page.dart
// Project: DailyHabits — Settings Module
//
// Lets the user configure motivational-quote notifications, including:
//   • Master toggle to enable/disable quotes.
//   • Delivery frequency (morning, evening, or random).
//   • Tone preference (calm, productivity, mental health, discipline).
//   • A static preview quote card to illustrate the feature.
//
// All sub-controls fade out and become non-interactive when the master
// toggle is off, using [AnimatedOpacity] and [IgnorePointer].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Settings page for configuring motivational-quote notifications.
///
/// Provides frequency and tone customization, guarded behind a master
/// enable/disable switch. A preview quote card gives the user an idea
/// of what they will receive.
class MotivationalQuotesPage extends StatelessWidget {
  const MotivationalQuotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final s = ctrl.appSettings;
    final enabled = s?.quotesEnabled ?? true;

    return Scaffold(
      appBar:
          AppBar(title: const Text('Motivational Quotes'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Toggle ──────────────────────────────────────────────
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile.adaptive(
              title: const Text('Motivational Quotes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Receive inspiring quotes throughout the day'),
              value: enabled,
              onChanged: (v) => ctrl.setQuotesEnabled(v),
              activeTrackColor: colors.primary,
              secondary: Icon(
                Icons.format_quote,
                color: enabled ? colors.primary : colors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Frequency ─────────────────────────────────────────
          AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frequency',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('When to receive quotes',
                              style: TextStyle(
                                  fontSize: 13, color: colors.textSecondary)),
                          const SizedBox(height: 12),
                          ..._frequencies.entries.map((e) => _RadioTile(
                                title: e.value['title']!,
                                subtitle: e.value['subtitle']!,
                                icon: _frequencyIcons[e.key]!,
                                selected:
                                    (s?.quoteFrequency ?? 'morning') == e.key,
                                onTap: () => ctrl.setQuoteFrequency(e.key),
                              )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Tone ──────────────────────────────────────
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tone',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('The vibe of your quotes',
                              style: TextStyle(
                                  fontSize: 13, color: colors.textSecondary)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _tones.entries.map((e) {
                              final selected =
                                  (s?.quoteTone ?? 'calm') == e.key;
                              return ChoiceChip(
                                label: Text(e.value),
                                selected: selected,
                                onSelected: (_) => ctrl.setQuoteTone(e.key),
                                selectedColor:
                                    colors.primary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Preview Quote ─────────────────────────────────────
          AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.1),
                    colors.primary.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(Icons.format_quote,
                      color: colors.primary.withValues(alpha: 0.3), size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '"The secret of getting ahead is getting started."',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: colors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('— Mark Twain',
                      style: TextStyle(
                          fontSize: 13, color: colors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Available frequency options with display title and subtitle.
  static final Map<String, Map<String, String>> _frequencies = {
    'morning': {
      'title': 'Morning',
      'subtitle': 'Start the day inspired',
    },
    'evening': {
      'title': 'Evening',
      'subtitle': 'Reflect and wind down',
    },
    'random': {
      'title': 'Random',
      'subtitle': 'Surprise me throughout the day',
    },
  };

  /// Icons mapped to each frequency option key.
  static final Map<String, IconData> _frequencyIcons = {
    'morning': Icons.wb_sunny_outlined,
    'evening': Icons.nights_stay_outlined,
    'random': Icons.shuffle,
  };

  /// Available tone options with emoji-prefixed display labels.
  static final Map<String, String> _tones = {
    'calm': '\u{1F9D8} Calm',
    'productivity': '\u{1F680} Productivity',
    'mental_health': '\u{1F49A} Mental Health',
    'discipline': '\u{1F4AA} Discipline',
  };
}

// =============================================================================
//  PRIVATE WIDGETS — Radio-style list tile.
// =============================================================================

/// A tappable row that mimics radio-button behavior for selecting a
/// quote-delivery frequency.
///
/// Displays an [icon], [title], and [subtitle]. When [selected] is true,
/// the icon and text highlight with the primary color and a filled radio
/// icon appears on the trailing edge.
class _RadioTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RadioTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? colors.primary : colors.textSecondary,
                size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color:
                            selected ? colors.primary : colors.textPrimary,
                      )),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: colors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colors.primary : colors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
