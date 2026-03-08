// =============================================================================
// File: pdf_export_service.dart
// Project: DailyHabits — Data Export Module
//
// Handles downloading data exports (PDF, CSV, JSON) from the Django backend
// and saving them to the device. Supports both mobile (native file system)
// and web (browser download) platforms.
//
// Platform-specific file operations are isolated via conditional imports:
//   - pdf_file_helper_web.dart   → browser Blob download (package:web)
//   - pdf_file_helper_mobile.dart → dart:io + path_provider + open_filex
//   - pdf_file_helper_stub.dart   → fallback stub (throws UnsupportedError)
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';

// Conditional import — compiler picks the right file per target platform.
import 'pdf_file_helper_stub.dart'
    if (dart.library.html) 'pdf_file_helper_web.dart'
    if (dart.library.io) 'pdf_file_helper_mobile.dart';

// =============================================================================
// Export Result — encapsulates success / failure outcome
// =============================================================================

/// The outcome of a data export operation.
class PdfExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  const PdfExportResult._({
    required this.success,
    this.filePath,
    this.errorMessage,
  });

  factory PdfExportResult.ok(String? path) =>
      PdfExportResult._(success: true, filePath: path);

  factory PdfExportResult.error(String message) =>
      PdfExportResult._(success: false, errorMessage: message);
}

// =============================================================================
// PDF Export Service  (handles PDF, CSV, JSON)
// =============================================================================

class PdfExportService {
  final AuthService _authService = AuthService();

  // ---------------------------------------------------------------------------
  // URL builders
  // ---------------------------------------------------------------------------

  /// PDF report endpoint (on-the-fly generation).
  String get _reportUrl => '${ApiConfig.baseUrl}/exports/habit-report/';

  /// CSV / JSON export endpoint (on-the-fly generation).
  String _dataUrl(String format, String dateFrom, String dateTo) =>
      '${ApiConfig.baseUrl}/exports/export-data/'
      '?format=$format&dateFrom=$dateFrom&dateTo=$dateTo';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Downloads a Habit Analytics Report PDF from the backend.
  Future<PdfExportResult> exportHabitReport() async {
    return _download(
      url: _reportUrl,
      expectedContentType: 'pdf',
      acceptHeader: 'application/pdf, application/json;q=0.9',
    );
  }

  /// Downloads a CSV or JSON export file for the given date range.
  Future<PdfExportResult> exportData({
    required String format,
    required String dateFrom,
    required String dateTo,
  }) async {
    final isJson = format == 'json';
    return _download(
      url: _dataUrl(format, dateFrom, dateTo),
      expectedContentType: isJson ? 'json' : 'csv',
      acceptHeader: isJson
          ? 'application/json'
          : 'text/csv, application/json;q=0.9',
    );
  }

  /// Opens a previously saved export file with the device's default viewer.
  Future<bool> openFile(String filePath) async {
    try {
      return await openPdfFile(filePath);
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — shared download logic
  // ---------------------------------------------------------------------------

  Future<PdfExportResult> _download({
    required String url,
    required String expectedContentType,
    required String acceptHeader,
  }) async {
    try {
      // 1. Auth check
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return PdfExportResult.error(
          'Authentication required. Please log in again.',
        );
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': acceptHeader,
      };

      // 2. Fetch data
      debugPrint('Export: requesting $url');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 408) {
        return PdfExportResult.error(
          'Request timed out. Please check your connection and try again.',
        );
      }
      if (response.statusCode == 401) {
        return PdfExportResult.error(
          'Session expired. Please log in again.',
        );
      }
      if (response.statusCode != 200) {
        // Try to extract error message from JSON body
        try {
          final body = response.body;
          if (body.contains('message')) {
            return PdfExportResult.error(
              'Server error (${response.statusCode}). Please try again later.',
            );
          }
        } catch (_) {}
        return PdfExportResult.error(
          'Server error (${response.statusCode}). Please try again later.',
        );
      }

      // Verify content type
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains(expectedContentType)) {
        return PdfExportResult.error(
          'Unexpected response format from server.',
        );
      }

      final Uint8List bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return PdfExportResult.error('Received empty file.');
      }

      debugPrint('Export: received ${bytes.length} bytes ($contentType)');

      // 3. Determine filename from Content-Disposition or generate one
      final disposition = response.headers['content-disposition'] ?? '';
      String fileName = _extractFileName(disposition);
      if (fileName.isEmpty) {
        final ext = _extForContentType(expectedContentType);
        final now = DateTime.now();
        fileName = 'DailyHabits_Export_'
            '${now.year}-${_pad(now.month)}-${_pad(now.day)}.$ext';
      }

      // 4. Save to device (platform-specific)
      final filePath = await saveExportToDevice(bytes, contentType, fileName);
      return PdfExportResult.ok(filePath);
    } catch (e) {
      debugPrint('Export error: $e');
      return PdfExportResult.error(
        'Failed to export. Please try again.',
      );
    }
  }

  /// Extracts the filename from a Content-Disposition header value.
  static String _extractFileName(String disposition) {
    if (disposition.isEmpty) return '';
    final match = RegExp(r'filename="?([^";\s]+)"?').firstMatch(disposition);
    return match?.group(1) ?? '';
  }

  /// Maps a content-type keyword to a file extension.
  static String _extForContentType(String ct) => switch (ct) {
        'pdf' => 'pdf',
        'csv' => 'csv',
        'json' => 'json',
        _ => 'dat',
      };

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
