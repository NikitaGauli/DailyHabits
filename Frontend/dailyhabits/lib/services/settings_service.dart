import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/models/settings_models.dart';

/// Service layer for all settings-related API operations.
///
/// Covers: app settings, privacy, security, sessions, audit logs,
/// profile, exports, privacy policy, FAQs, support tickets, and
/// account deletion.
class SettingsService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─── App Settings ──────────────────────────────────────────────

  Future<UserAppSettings?> getSettings() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/user-settings/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return UserAppSettings.fromJson(data['settings']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateSettings(Map<String, dynamic> fields) async {
    try {
      final h = await _headers();
      final r = await http.put(
        Uri.parse('/user-settings/update_settings/'),
        headers: h,
        body: jsonEncode(fields),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Privacy Settings ──────────────────────────────────────────

  Future<PrivacySettingsModel?> getPrivacySettings() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/privacy-settings/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return PrivacySettingsModel.fromJson(data['settings']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updatePrivacySettings(Map<String, dynamic> fields) async {
    try {
      final h = await _headers();
      final r = await http.put(
        Uri.parse('/privacy-settings/update_settings/'),
        headers: h,
        body: jsonEncode(fields),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Security Settings ─────────────────────────────────────────

  Future<SecuritySettingsModel?> getSecuritySettings() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/security-settings/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return SecuritySettingsModel.fromJson(data['settings']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateSecuritySettings(Map<String, dynamic> fields) async {
    try {
      final h = await _headers();
      final r = await http.put(
        Uri.parse('/security-settings/update_settings/'),
        headers: h,
        body: jsonEncode(fields),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final h = await _headers();
      final r = await http.post(
        Uri.parse('/security-settings/change_password/'),
        headers: h,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      return jsonDecode(r.body);
    } catch (e) {
      return {'success': false, 'error': 'Failed to change password: '};
    }
  }

  // ─── Login Sessions ────────────────────────────────────────────

  Future<List<LoginSessionModel>> getLoginSessions() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/login-sessions/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return (data['sessions'] as List)
              .map((e) => LoginSessionModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> revokeSession(int sessionId) async {
    try {
      final h = await _headers();
      final r = await http.post(
        Uri.parse('/login-sessions//revoke/'),
        headers: h,
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> revokeAllSessions() async {
    try {
      final h = await _headers();
      final r = await http.post(
        Uri.parse('/login-sessions/revoke_all/'),
        headers: h,
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Audit Logs ────────────────────────────────────────────────

  Future<List<AuditLogEntry>> getAuditLogs({String? category}) async {
    try {
      final h = await _headers();
      var url = '/settings-audit-logs/';
      if (category != null) url += '?category=';
      final r = await http.get(Uri.parse(url), headers: h);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return (data['logs'] as List)
              .map((e) => AuditLogEntry.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── User Profile ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/auth/profile/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) return data['user'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    try {
      final h = await _headers();
      final r = await http.patch(
        Uri.parse('/auth/profile/'),
        headers: h,
        body: jsonEncode(fields),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Data Exports ──────────────────────────────────────────────

  Future<List<ExportRequest>> getExports() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/exports/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return (data['exports'] as List)
              .map((e) => ExportRequest.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> requestExport({
    required String format,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final h = await _headers();
      final r = await http.post(
        Uri.parse('/exports/request/'),
        headers: h,
        body: jsonEncode({
          'format': format,
          'dateFrom': dateFrom,
          'dateTo': dateTo,
        }),
      );
      return jsonDecode(r.body);
    } catch (e) {
      return {'success': false, 'message': 'Export failed: '};
    }
  }

  Future<String?> getExportDownloadUrl(int exportId) async {
    return '/exports/download/?id=';
  }

  // ─── Privacy Policy ────────────────────────────────────────────

  Future<PrivacyPolicyModel?> getPrivacyPolicy() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/privacy-policy/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return PrivacyPolicyModel.fromJson(data['policy']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── FAQs ──────────────────────────────────────────────────────

  Future<List<FAQItem>> getFAQs() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/faqs/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return (data['faqs'] as List)
              .map((e) => FAQItem.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── Support Tickets ───────────────────────────────────────────

  Future<List<SupportTicket>> getTickets() async {
    try {
      final h = await _headers();
      final r = await http.get(
        Uri.parse('/support-tickets/'),
        headers: h,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['success'] == true) {
          return (data['tickets'] as List)
              .map((e) => SupportTicket.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createTicket({
    required String subject,
    required String description,
    String category = 'general',
    String priority = 'medium',
    String? screenshotUrl,
  }) async {
    try {
      final h = await _headers();
      final r = await http.post(
        Uri.parse('/support-tickets/'),
        headers: h,
        body: jsonEncode({
          'subject': subject,
          'description': description,
          'category': category,
          'priority': priority,
          if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
        }),
      );
      return jsonDecode(r.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create ticket: '};
    }
  }

  // ─── Account Deletion ──────────────────────────────────────────

  Future<Map<String, dynamic>> requestDeletion({String reason = ''}) async {
    try {
      final h = await _headers();
      final r = await http.post(
        Uri.parse('/auth/request-deletion/'),
        headers: h,
        body: jsonEncode({'reason': reason}),
      );
      return jsonDecode(r.body);
    } catch (e) {
      return {'success': false, 'message': 'Request failed: '};
    }
  }
}
