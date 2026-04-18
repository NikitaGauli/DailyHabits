// =============================================================================
// File: admin_api_service.dart
// Description: Centralized API service for the Admin Dashboard. Communicates
//              with the Django admin_panel endpoints at /api/admin/*.
//              Uses the singleton pattern consistent with existing services.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';

import '../../services/pdf_file_helper_stub.dart'
  if (dart.library.html) '../../services/pdf_file_helper_web.dart'
  if (dart.library.io) '../../services/pdf_file_helper_mobile.dart';

// =============================================================================
// Admin API Service
// =============================================================================

class AdminApiService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static final AdminApiService _instance = AdminApiService._internal();
  factory AdminApiService() => _instance;
  AdminApiService._internal();

  static String get _base => '${ApiConfig.baseUrl}/admin';

  final AuthService _authService = AuthService();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Builds a URI from [path] appending optional [queryParams].
  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final url = '$_base$path';
    final uri = Uri.parse(url);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  /// Generic GET that decodes JSON body or throws.
  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final headers = await _headers();
    final response = await http
        .get(_uri(path, query), headers: headers)
        .timeout(ApiConfig.timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  /// Generic POST.
  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final headers = await _headers();
    final response = await http
        .post(_uri(path), headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConfig.timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  /// Generic PATCH.
  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final response = await http
        .patch(_uri(path), headers: headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  /// Generic DELETE.
  Future<void> delete(String path) async {
    final headers = await _headers();
    final response = await http
        .delete(_uri(path), headers: headers)
        .timeout(ApiConfig.timeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  // ===========================================================================
  //  ADMIN PROFILE & AUTH
  // ===========================================================================

  /// GET /api/admin/me/ — returns the authenticated admin's profile.
  Future<AdminProfile> getMyProfile() async {
    final data = await _get('/me/');
    return AdminProfile.fromJson(data);
  }

  // ===========================================================================
  //  OVERVIEW / ANALYTICS
  // ===========================================================================

  Future<OverviewStats> getOverviewStats() async {
    final data = await _get('/analytics/overview/');
    return OverviewStats.fromJson(data);
  }

  Future<List<GrowthDataPoint>> getGrowthTrends({int days = 30}) async {
    final data = await _get('/analytics/growth/', {'days': '$days'});
    final list = data as List<dynamic>;
    return list
        .map((e) => GrowthDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EngagementMetrics> getEngagementMetrics({int days = 30}) async {
    final data = await _get('/analytics/engagement/', {'days': '$days'});
    return EngagementMetrics.fromJson(data);
  }

  Future<void> exportAnalyticsReport({
    int days = 30,
    String format = 'csv',
  }) async {
    final normalized = format.toLowerCase() == 'pdf' ? 'pdf' : 'csv';
    final headers = await _headers();
    headers['Accept'] = normalized == 'pdf'
        ? 'application/pdf, text/csv, application/json;q=0.9'
        : 'text/csv, application/pdf, application/json;q=0.9';

    final response = await http
        .get(
          _uri('/analytics/export/', {
            'days': '$days',
            'format': normalized,
          }),
          headers: headers,
        )
        .timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }

    final contentType = response.headers['content-type'] ??
        (normalized == 'pdf' ? 'application/pdf' : 'text/csv');
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName = _extractFileName(disposition) ??
        'analytics_${days}d.${normalized == 'pdf' ? 'pdf' : 'csv'}';

    if (response.bodyBytes.isEmpty) {
      throw ApiException(500, 'Empty export file received.');
    }

    await saveExportToDevice(response.bodyBytes, contentType, fileName);
  }

  String? _extractFileName(String disposition) {
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return match?.group(1);
  }

  // ===========================================================================
  //  USERS
  // ===========================================================================

  Future<PaginatedResponse<AdminUser>> getUsers({
    int page = 1,
    String? search,
    String? ordering,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (ordering != null) query['ordering'] = ordering;
    final data = await _get('/users/', query);
    return PaginatedResponse.fromJson(data, AdminUser.fromJson);
  }

  Future<AdminUser> getUser(int id) async {
    final data = await _get('/users/$id/');
    return AdminUser.fromJson(data);
  }

  Future<void> suspendUser(int id, {String? reason}) async {
    await _post('/users/$id/suspend/', reason != null ? {'reason': reason} : {});
  }

  Future<void> activateUser(int id) async {
    await _post('/users/$id/activate/');
  }

  Future<Map<String, dynamic>> getUserAnalytics(int id) async {
    final data = await _get('/users/$id/analytics/');
    return data as Map<String, dynamic>;
  }

  // ===========================================================================
  //  REPORTS
  // ===========================================================================

  Future<PaginatedResponse<Report>> getReports({
    int page = 1,
    String? status,
    String? priority,
    String? category,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (status != null) query['status'] = status;
    if (priority != null) query['priority'] = priority;
    if (category != null) query['category'] = category;
    final data = await _get('/reports/', query);
    return PaginatedResponse.fromJson(data, Report.fromJson);
  }

  Future<void> resolveReport(
    String id, {
    required String action,
    required String resolution,
  }) async {
    await _post('/reports/$id/resolve/', {
      'action': action,
      'resolution': resolution,
    });
  }

  // ===========================================================================
  //  MODERATION
  // ===========================================================================

  Future<PaginatedResponse<ModerationItem>> getModerationQueue({
    int page = 1,
    String? status,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (status != null) query['status'] = status;
    final data = await _get('/moderation/', query);
    return PaginatedResponse.fromJson(data, ModerationItem.fromJson);
  }

  Future<void> moderationDecision(
    String id, {
    required String decision,
    String? notes,
  }) async {
    await _post('/moderation/$id/decide/', {
      'decision': decision,
      if (notes != null) 'notes': notes,
    });
  }

  // ===========================================================================
  //  AUDIT LOGS
  // ===========================================================================

  Future<PaginatedResponse<AuditLogEntry>> getAuditLogs({
    int page = 1,
    String? action,
    String? severity,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (action != null) query['action'] = action;
    if (severity != null) query['severity'] = severity;
    final data = await _get('/audit-logs/', query);
    return PaginatedResponse.fromJson(data, AuditLogEntry.fromJson);
  }

  // ===========================================================================
  //  SYSTEM SETTINGS
  // ===========================================================================

  Future<PaginatedResponse<SystemSetting>> getSettings({int page = 1}) async {
    final data = await _get('/settings/', {'page': '$page'});
    return PaginatedResponse.fromJson(data, SystemSetting.fromJson);
  }

  Future<SystemSetting> updateSetting(String key, String value) async {
    final data = await _patch('/settings/$key/', {'value': value});
    return SystemSetting.fromJson(data);
  }

  // ===========================================================================
  //  FEATURE FLAGS
  // ===========================================================================

  Future<PaginatedResponse<FeatureFlag>> getFeatureFlags({int page = 1}) async {
    final data = await _get('/feature-flags/', {'page': '$page'});
    return PaginatedResponse.fromJson(data, FeatureFlag.fromJson);
  }

  Future<FeatureFlag> toggleFeatureFlag(String id) async {
    final data = await _post('/feature-flags/$id/toggle/');
    return FeatureFlag.fromJson(data);
  }

  // ===========================================================================
  //  NOTIFICATION CAMPAIGNS
  // ===========================================================================

  Future<PaginatedResponse<NotificationCampaign>> getCampaigns({
    int page = 1,
  }) async {
    final data = await _get('/campaigns/', {'page': '$page'});
    return PaginatedResponse.fromJson(data, NotificationCampaign.fromJson);
  }

  Future<NotificationCampaign> createCampaign(
      Map<String, dynamic> body) async {
    final data = await _post('/campaigns/', body);
    return NotificationCampaign.fromJson(data);
  }

  Future<void> sendCampaign(String id) async {
    await _post('/campaigns/$id/send/');
  }

  Future<void> cancelCampaign(String id) async {
    await _post('/campaigns/$id/cancel/');
  }
}

// =============================================================================
// Exception
// =============================================================================

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';

  String get userMessage {
    if (statusCode == 401) return 'Session expired. Please log in again.';
    if (statusCode == 403) return 'You do not have permission for this action.';
    if (statusCode == 404) return 'Resource not found.';
    if (statusCode >= 500) return 'Server error. Please try again later.';
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('detail')) return data['detail'];
    } catch (_) {}
    return 'An unexpected error occurred.';
  }
}
