// =============================================================================
// File: daily_bonus_card.dart
// Description: Card widget for displaying and claiming the daily login bonus.
//              Shows a "Claim" button when unclaimed and a success state after.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// A prominent card that allows the user to claim their daily login bonus.
class DailyBonusCard extends StatelessWidget {
  final bool loginClaimed;
  final Future<bool> Function() onClaimLogin;
  final bool isActioning;

  const DailyBonusCard({
    super.key,
    required this.loginClaimed,
    required this.onClaimLogin,
    required this.isActioning,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: loginClaimed
            ? LinearGradient(
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.08),
                  const Color(0xFF14B8A6).withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  const Color(0xFFFF6B35).withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: loginClaimed
              ? const Color(0xFF22C55E).withValues(alpha: 0.15)
              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: loginClaimed
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: loginClaimed
                    ? const Icon(Icons.check_circle_rounded,
                        key: ValueKey('claimed'),
                        color: Color(0xFF22C55E),
                        size: 26)
                    : const Text('🎁',
                        key: ValueKey('gift'),
                        style: TextStyle(fontSize: 24)),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loginClaimed ? 'Bonus Claimed!' : 'Daily Login Bonus',
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loginClaimed
                      ? 'Come back tomorrow for more rewards'
                      : 'Tap to claim +5 XP and +1 coin',
                  style: TextStyle(
                    color: tc.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Claim button
          if (!loginClaimed)
            Material(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: isActioning
                    ? null
                    : () async {
                        final success = await onClaimLogin();
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('🎉 Daily bonus claimed!'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF22C55E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: isActioning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Claim',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
