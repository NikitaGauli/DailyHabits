// =============================================================================
// File: coin_wallet_chip.dart
// Description: Small chip widget that displays the user's coin balance with
//              an animated coin icon. Used in the gamification header.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// A compact chip showing the user's virtual currency balance.
class CoinWalletChip extends StatelessWidget {
  final int balance;

  const CoinWalletChip({
    super.key,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFF59E0B),
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            _formatBalance(balance),
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBalance(int balance) {
    if (balance >= 10000) {
      return '${(balance / 1000).toStringAsFixed(1)}k';
    }
    return '$balance';
  }
}
