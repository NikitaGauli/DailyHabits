class HabitAnalysisResult {
  final int clusterGroup;
  final String clusterLabel;
  final String insight;
  final List<String> recommendations;
  final Map<String, int> clusterBreakdown;
  final int sampleCount;
  final DateTime createdAt;

  HabitAnalysisResult({
    required this.clusterGroup,
    required this.clusterLabel,
    required this.insight,
    required this.recommendations,
    required this.clusterBreakdown,
    required this.sampleCount,
    required this.createdAt,
  });

  static List<String> _normalizeRecommendations(dynamic raw) {
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }

    if (raw is Map<String, dynamic>) {
      final items = raw['items'];
      if (items is List) {
        return items.map((item) => item.toString()).toList();
      }

      return raw.values.map((value) => value.toString()).toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }

    return const [];
  }

  static Map<String, int> _normalizeClusterBreakdown(dynamic raw) {
    if (raw is! Map) {
      return const {};
    }

    final result = <String, int>{};
    raw.forEach((key, value) {
      final parsed = value is num ? value.toInt() : int.tryParse(value.toString());
      result[key.toString()] = parsed ?? 0;
    });
    return result;
  }

  factory HabitAnalysisResult.fromJson(Map<String, dynamic> json) {
    return HabitAnalysisResult(
      clusterGroup: (json['cluster_group'] as num?)?.toInt() ?? 0,
      clusterLabel: json['cluster_label']?.toString() ?? 'Unknown',
      insight: json['insight']?.toString() ?? 'No insight available.',
      recommendations: _normalizeRecommendations(json['recommendations']),
      clusterBreakdown: _normalizeClusterBreakdown(json['cluster_breakdown']),
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class HabitAnalysisHistoryItem {
  final int id;
  final int clusterId;
  final String clusterLabel;
  final String insightMessage;
  final List<String> recommendations;
  final String source;
  final DateTime createdAt;

  HabitAnalysisHistoryItem({
    required this.id,
    required this.clusterId,
    required this.clusterLabel,
    required this.insightMessage,
    required this.recommendations,
    required this.source,
    required this.createdAt,
  });

  factory HabitAnalysisHistoryItem.fromJson(Map<String, dynamic> json) {
    return HabitAnalysisHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      clusterId: (json['cluster_id'] as num?)?.toInt() ?? 0,
      clusterLabel: json['cluster_label']?.toString() ?? 'Unknown',
      insightMessage: json['insight_message']?.toString() ?? '',
      recommendations: HabitAnalysisResult._normalizeRecommendations(json['recommendations']),
      source: json['source']?.toString() ?? 'on_demand',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
