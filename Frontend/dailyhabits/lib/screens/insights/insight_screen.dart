import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'insight_controller.dart';
import '../../models/insight.dart';

class InsightScreen extends StatelessWidget {
  const InsightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InsightController(),
      child: const _InsightView(),
    );
  }
}

class _InsightView extends StatelessWidget {
  const _InsightView();

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final controller = Provider.of<InsightController>(context);

    if (controller.isLoading) {
      return Scaffold(
        backgroundColor: tc.bg,
        body: Center(
          child: CircularProgressIndicator(color: tc.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 32),

                if (controller.dailyQuote != null)
                  _buildQuoteCard(context, controller.dailyQuote!),

                const SizedBox(height: 32),

                if (controller.insights.isNotEmpty) ...[
                  Text(
                    'Smart Insights',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...controller.insights.map(
                    (insight) => _buildInsightCard(context, insight),
                  ),
                ] else
                  _buildEmptyState(
                    context,
                    'No insights available yet. Keep tracking your habits!',
                  ),

                const SizedBox(height: 32),

                if (controller.recommendations.isNotEmpty) ...[
                  Text(
                    'Recommended Actions',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...controller.recommendations.map(
                    (rec) => _buildRecommendationCard(context, rec),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tc = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insights',
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Daily wisdom and performance analysis',
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: tc.accent,
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuoteCard(BuildContext context, MotivationalQuote quote) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tc.card, tc.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tc.card.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: tc.textSecondary,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            '"${quote.quote}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 18,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '- ${quote.author}',
            style: TextStyle(
              color: tc.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, Insight insight) {
    final tc = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(insight.icon, color: insight.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context, Recommendation rec) {
    final tc = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppColors.success,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  rec.message,
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: AppColors.success, size: 14),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final tc = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: tc.textMuted),
        ),
      ),
    );
  }
}
