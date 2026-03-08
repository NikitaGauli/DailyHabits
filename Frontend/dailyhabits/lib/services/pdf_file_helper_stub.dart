// =============================================================================
// File: pdf_file_helper_stub.dart
// Stub implementation — conditionally replaced by web or mobile variants.
// =============================================================================

import 'dart:typed_data';

/// Saves export bytes to the device and returns the file path (mobile) or
/// triggers a browser download (web). Stub throws [UnsupportedError].
Future<String?> savePdfToDevice(Uint8List bytes) {
  throw UnsupportedError('savePdfToDevice is not supported on this platform');
}

/// Saves any export file (PDF, CSV, JSON) to the device.
Future<String?> saveExportToDevice(
    Uint8List bytes, String mimeType, String fileName) {
  throw UnsupportedError(
      'saveExportToDevice is not supported on this platform');
}

/// Opens a previously saved file with the system viewer.
/// Stub throws [UnsupportedError].
Future<bool> openPdfFile(String filePath) {
  throw UnsupportedError('openPdfFile is not supported on this platform');
}
