import 'package:flutter/material.dart';
import '../../services/insight_service.dart';
import '../../models/insight.dart';

class InsightController extends ChangeNotifier {
  final InsightService _service = InsightService();

  bool isLoading = true;
  MotivationalQuote? dailyQuote;
  List<Insight> insights = [];
  List<Recommendation> recommendations = [];

  InsightController() {
    loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await _service.getDailySummary();

      if (data.containsKey('quote')) dailyQuote = data['quote'];
      if (data.containsKey('insights')) insights = data['insights'];
      if (data.containsKey('recommendations')) {
        recommendations = data['recommendations'];
      }
    } catch (e) {
      debugPrint('Error loading insights: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
