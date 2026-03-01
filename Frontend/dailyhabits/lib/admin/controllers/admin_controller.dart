// =============================================================================
// File: admin_controller.dart
// Description: Provider-based state management for the Admin Dashboard.
//              Holds the admin profile, active page, and data caches.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/admin/services/admin_api_service.dart';

// =============================================================================
// Navigation
// =============================================================================

enum AdminPage {
  dashboard,
  users,
  reports,
  moderation,
  analytics,
  settings,
  featureFlags,
  notifications,
  auditLogs,
}

// =============================================================================
// Controller
// =============================================================================

class AdminController extends ChangeNotifier {
  final AdminApiService _api = AdminApiService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  AdminProfile? _profile;
  AdminProfile? get profile => _profile;

  AdminPage _currentPage = AdminPage.dashboard;
  AdminPage get currentPage => _currentPage;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // Dashboard data
  OverviewStats? _overviewStats;
  OverviewStats? get overviewStats => _overviewStats;

  List<GrowthDataPoint> _growthTrends = [];
  List<GrowthDataPoint> get growthTrends => _growthTrends;

  // Users
  PaginatedResponse<AdminUser>? _usersPage;
  PaginatedResponse<AdminUser>? get usersPage => _usersPage;
  int _usersCurrentPage = 1;
  int get usersCurrentPage => _usersCurrentPage;
  String _usersSearch = '';

  // Reports
  PaginatedResponse<Report>? _reportsPage;
  PaginatedResponse<Report>? get reportsPage => _reportsPage;
  int _reportsCurrentPage = 1;
  String? _reportsStatusFilter;

  // Moderation
  PaginatedResponse<ModerationItem>? _moderationPage;
  PaginatedResponse<ModerationItem>? get moderationPage => _moderationPage;

  // Audit logs
  PaginatedResponse<AuditLogEntry>? _auditLogsPage;
  PaginatedResponse<AuditLogEntry>? get auditLogsPage => _auditLogsPage;


  // Settings & Flags
  PaginatedResponse<SystemSetting>? _settingsPage;
  PaginatedResponse<SystemSetting>? get settingsPage => _settingsPage;

  PaginatedResponse<FeatureFlag>? _featureFlagsPage;
  PaginatedResponse<FeatureFlag>? get featureFlagsPage => _featureFlagsPage;

  // Campaigns
  PaginatedResponse<NotificationCampaign>? _campaignsPage;
  PaginatedResponse<NotificationCampaign>? get campaignsPage => _campaignsPage;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void navigateTo(AdminPage page) {
    _currentPage = page;
    _error = null;
    notifyListeners();
    _loadDataForPage(page);
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _setLoading(true);
    try {
      _profile = await _api.getMyProfile();
      _error = null;
      notifyListeners();
      // Pre‑load dashboard data
      await _loadDashboard();
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to initialize admin panel.';
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Permission helper
  // ---------------------------------------------------------------------------

  bool hasPermission(String perm) => _profile?.hasPermission(perm) ?? false;

  // ---------------------------------------------------------------------------
  // Page loaders
  // ---------------------------------------------------------------------------

  Future<void> _loadDataForPage(AdminPage page) async {
    switch (page) {
      case AdminPage.dashboard:
        await _loadDashboard();
        break;
      case AdminPage.users:
        await loadUsers();
        break;
      case AdminPage.reports:
        await loadReports();
        break;
      case AdminPage.moderation:
        await loadModeration();
        break;
      case AdminPage.analytics:
        await _loadDashboard();
        break;
      case AdminPage.settings:
        await loadSettings();
        break;
      case AdminPage.featureFlags:
        await loadFeatureFlags();
        break;
      case AdminPage.notifications:
        await loadCampaigns();
        break;
      case AdminPage.auditLogs:
        await loadAuditLogs();
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  Future<void> _loadDashboard() async {
    _setLoading(true);
    try {
      final results = await Future.wait([
        _api.getOverviewStats(),
        _api.getGrowthTrends(days: 30),
      ]);
      _overviewStats = results[0] as OverviewStats;
      _growthTrends = results[1] as List<GrowthDataPoint>;
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load dashboard data.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshDashboard() => _loadDashboard();

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  Future<void> loadUsers({int page = 1, String search = ''}) async {
    _usersCurrentPage = page;
    _usersSearch = search;
    _setLoading(true);
    try {
      _usersPage = await _api.getUsers(
        page: page,
        search: search.isNotEmpty ? search : null,
      );
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load users.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> suspendUser(int id, {String? reason}) async {
    try {
      await _api.suspendUser(id, reason: reason);
      await loadUsers(page: _usersCurrentPage, search: _usersSearch);
    } on ApiException catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  Future<void> activateUser(int id) async {
    try {
      await _api.activateUser(id);
      await loadUsers(page: _usersCurrentPage, search: _usersSearch);
    } on ApiException catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  Future<void> loadReports({int page = 1, String? status}) async {
    _reportsCurrentPage = page;
    _reportsStatusFilter = status;
    _setLoading(true);
    try {
      _reportsPage = await _api.getReports(page: page, status: status);
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load reports.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resolveReport(String id,
      {required String action, required String resolution}) async {
    try {
      await _api.resolveReport(id, action: action, resolution: resolution);
      await loadReports(
          page: _reportsCurrentPage, status: _reportsStatusFilter);
    } on ApiException catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Moderation
  // ---------------------------------------------------------------------------

  Future<void> loadModeration({int page = 1}) async {
    _setLoading(true);
    try {
      _moderationPage = await _api.getModerationQueue(page: page);
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load moderation queue.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> moderationDecide(String id,
      {required String decision, String? notes}) async {
    try {
      await _api.moderationDecision(id, decision: decision, notes: notes);
      await loadModeration();
    } on ApiException catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Audit Logs
  // ---------------------------------------------------------------------------

  Future<void> loadAuditLogs({int page = 1}) async {
    _setLoading(true);
    try {
      _auditLogsPage = await _api.getAuditLogs(page: page);
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load audit logs.';
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<void> loadSettings() async {
    _setLoading(true);
    try {
      _settingsPage = await _api.getSettings();
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load settings.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSetting(String key, String value) async {
    try {
      await _api.updateSetting(key, value);
      await loadSettings();
    } on ApiException catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Feature Flags
  // ---------------------------------------------------------------------------

  Future<void> loadFeatureFlags() async {
    _setLoading(true);
    try {
      _featureFlagsPage = await _api.getFeatureFlags();
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load feature flags.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleFlag(String id) async {
    try {
      await _api.toggleFeatureFlag(id);
      await loadFeatureFlags();
    } on ApiException catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Notification Campaigns
  // ---------------------------------------------------------------------------

  Future<void> loadCampaigns() async {
    _setLoading(true);
    try {
      _campaignsPage = await _api.getCampaigns();
      _error = null;
    } on ApiException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Failed to load campaigns.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendCampaign(String id) async {
    try {
      await _api.sendCampaign(id);
      await loadCampaigns();
    } on ApiException catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
