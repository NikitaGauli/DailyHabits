// =============================================================================
// File: streak_card.dart
// Description: Card widget showing current streak, best streak, multiplier,
//              and streak freeze management with buy button.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/gamification_models.dart';

/// A themed card displaying streak stats and streak freeze controls.
class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final StreakFreezeInfo? freezes;
  final double multiplier;
  final Future<String> Function() onBuyFreeze;
  final bool isActioning;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    this.freezes,
    required this.multiplier,
    required this.onBuyFreeze,
    required this.isActioning,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: Streak flame + stats
          Row(
            children: [
              // Animated flame icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B35).withValues(alpha: 0.15),
                      const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$currentStreak',
                          style: TextStyle(
                            color: tc.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          ' day streak',
                          style: TextStyle(
                            color: tc.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Best: $bestStreak days',
                          style: TextStyle(
                            color: tc.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${multiplier}x XP',
                            style: const TextStyle(
                              color: Color(0xFF14B8A6),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: tc.border.withValues(alpha: 0.08), height: 1),
          ),

          // Streak Freezes row
          if (freezes != null)
            Row(
              children: [
                const Icon(Icons.ac_unit_rounded, color: Color(0xFF3B82F6), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Streak Freezes',
                        style: TextStyle(
                          color: tc.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${freezes!.available}/${freezes!.max} available · ${freezes!.cost} coins each',
                        style: TextStyle(
                          color: tc.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Buy freeze button
                _BuyFreezeButton(
                  available: freezes!.available,
                  max: freezes!.max,
                  isActioning: isActioning,
                  onBuy: onBuyFreeze,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Buy Freeze Button
// =============================================================================

class _BuyFreezeButton extends StatelessWidget {
  final int available;
  final int max;
  final bool isActioning;
  final Future<String> Function() onBuy;

  const _BuyFreezeButton({
    required this.available,
    required this.max,
    required this.isActioning,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final canBuy = available < max && !isActioning;

    return Material(
      color: canBuy
          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
          : tc.surfaceVariant,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: canBuy
            ? () async {
                final msg = await onBuy();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: isActioning
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tc.primary,
                  ),
                )
              : Text(
                  available >= max ? 'Full' : 'Buy',
                  style: TextStyle(
                    color: canBuy ? const Color(0xFF3B82F6) : tc.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
