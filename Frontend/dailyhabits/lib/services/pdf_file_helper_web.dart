// =============================================================================
// File: pdf_file_helper_web.dart
// Web implementation — triggers a browser download using package:web.
// =============================================================================

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser file-save dialog for the given PDF [bytes].
Future<String?> savePdfToDevice(Uint8List bytes) async {
  final now = DateTime.now();
  final fileName =
      'DailyHabits_Report_'
      '${now.year}-${_pad(now.month)}-${_pad(now.day)}.pdf';
  return saveExportToDevice(bytes, 'application/pdf', fileName);
}

/// Triggers a browser download for any export file type.
Future<String?> saveExportToDevice(
    Uint8List bytes, String mimeType, String fileName) async {
  final jsArray = <JSUint8Array>[bytes.toJS].toJS;
  final blob = web.Blob(jsArray, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();

  web.URL.revokeObjectURL(url);
  return null;
}

/// Not applicable on web — always returns `false`.
Future<bool> openPdfFile(String filePath) async => false;

String _pad(int n) => n.toString().padLeft(2, '0');
