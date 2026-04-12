import 'package:dailyhabits/models/habit_analysis.dart';
import 'package:dailyhabits/services/habit_service.dart';
import 'package:dailyhabits/services/recommendation_service.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum _FailedAction {
  analyze,
  history,
}

class HabitAnalysisScreen extends StatefulWidget {
  const HabitAnalysisScreen({super.key});

  @override
  State<HabitAnalysisScreen> createState() => _HabitAnalysisScreenState();
}

class _HabitAnalysisScreenState extends State<HabitAnalysisScreen> {
  final RecommendationService _recommendationService = RecommendationService();
  final HabitService _habitService = HabitService();

  bool _isAnalyzing = false;
  bool _isHistoryLoading = true;
  String? _error;
  _FailedAction? _lastFailedAction;

  HabitAnalysisResult? _latestResult;
  List<HabitAnalysisHistoryItem> _history = const [];

  String _friendlyError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception:')) {
      return raw.replaceFirst('Exception:', '').trim();
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isHistoryLoading = true;
      _error = null;
    });

    try {
      final history = await _recommendationService.getHistory(limit: 12);
      setState(() {
        _history = history;
        _lastFailedAction = null;
        if (_latestResult == null && history.isNotEmpty) {
          final first = history.first;
          _latestResult = HabitAnalysisResult(
            clusterGroup: first.clusterId,
            clusterLabel: first.clusterLabel,
            insight: first.insightMessage,
            recommendations: first.recommendations,
            clusterBreakdown: const {},
            sampleCount: 0,
            createdAt: first.createdAt,
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _lastFailedAction = _FailedAction.history;
      });
    } finally {
      setState(() {
        _isHistoryLoading = false;
      });
    }
  }

  Future<void> _analyzeHabits() async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final habits = await _habitService.getHabits();
      HabitAnalysisResult result;

      if (habits.isNotEmpty) {
        try {
          result = await _recommendationService.analyzeHabits(habits);
        } catch (_) {
          // Fall back to server-derived samples when direct payload analysis fails.
          result = await _recommendationService.analyzeFromServerData();
        }
      } else {
        result = await _recommendationService.analyzeFromServerData();
      }

      setState(() {
        _latestResult = result;
        _lastFailedAction = null;
      });

      await _loadHistory();
    } catch (e) {
      final friendly = _friendlyError(e);
      final modelHint = friendly.toLowerCase().contains('kmeans_model.pkl') ||
          friendly.toLowerCase().contains('unable to load kmeans model') ||
          friendly.toLowerCase().contains('model');

      setState(() {
        _error = modelHint
            ? '$friendly\n\nAsk admin to upload kmeans_model.pkl in Backend/DailyHabits/ml_models or set ML_KMEANS_MODEL_PATH.'
            : friendly;
        _lastFailedAction = _FailedAction.analyze;
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        title: const Text('Habit Intelligence'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildActionCard(context),
            const SizedBox(height: 16),
            if (_error != null) _buildErrorCard(context, _error!),
            if (_latestResult != null) ...[
              _buildResultCard(context, _latestResult!),
              const SizedBox(height: 16),
              _buildRecommendationsCard(context, _latestResult!),
              const SizedBox(height: 16),
            ],
            _buildHistoryHeader(context),
            const SizedBox(height: 8),
            if (_isHistoryLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_history.isEmpty)
              _buildEmptyCard(context, 'No analysis history yet. Run your first analysis.')
            else
              ..._history.map((item) => _buildHistoryCard(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyze My Habits',
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get your cluster profile, consistency insight, and practical recommendations generated by the KMeans model.',
            style: TextStyle(color: tc.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeHabits,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_outlined),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze My Habits'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, HabitAnalysisResult result) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cluster Result: ${result.clusterLabel}',
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cluster ID: ${result.clusterGroup}',
            style: TextStyle(color: tc.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            result.insight,
            style: TextStyle(color: tc.textPrimary, height: 1.5),
          ),
          if (result.clusterBreakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.clusterBreakdown.entries
                  .map(
                    (entry) => Chip(
                      label: Text('Cluster ${entry.key}: ${entry.value}'),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(BuildContext context, HabitAnalysisResult result) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalized Suggestions',
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...result.recommendations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.lightbulb_outline, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: tc.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader(BuildContext context) {
    final tc = context.colors;
    return Text(
      'Insight History',
      style: TextStyle(
        color: tc.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, HabitAnalysisHistoryItem item) {
    final tc = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.clusterLabel,
                  style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                item.source == 'weekly' ? 'Weekly' : 'On-demand',
                style: TextStyle(color: tc.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.insightMessage, style: TextStyle(color: tc.textSecondary)),
          const SizedBox(height: 6),
          Text(
            '${item.createdAt.toLocal()}',
            style: TextStyle(color: tc.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final canRetry = !_isAnalyzing && !_isHistoryLoading;

    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Could not complete Habit Intelligence request',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: canRetry
                      ? () {
                          if (_lastFailedAction == _FailedAction.history) {
                            _loadHistory();
                          } else {
                            _analyzeHabits();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    _lastFailedAction == _FailedAction.history
                        ? 'Retry History'
                        : 'Retry Analysis',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: canRetry ? _loadHistory : null,
                  icon: const Icon(Icons.history),
                  label: const Text('Reload History'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: TextStyle(color: tc.textSecondary)),
    );
  }
}
