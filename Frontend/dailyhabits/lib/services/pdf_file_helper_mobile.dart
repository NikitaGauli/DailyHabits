// =============================================================================
// File: pdf_file_helper_mobile.dart
// Mobile / desktop implementation — saves via dart:io, opens via open_filex.
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Writes PDF [bytes] to the app's documents directory.
Future<String?> savePdfToDevice(Uint8List bytes) async {
  final now = DateTime.now();
  final fileName =
      'DailyHabits_Report_'
      '${now.year}-${_pad(now.month)}-${_pad(now.day)}_'
      '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.pdf';
  return saveExportToDevice(bytes, 'application/pdf', fileName);
}

/// Writes any export file to the app's documents directory and returns
/// the absolute file path.
Future<String?> saveExportToDevice(
    Uint8List bytes, String mimeType, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Opens a file at [filePath] with the device's default viewer.
Future<bool> openPdfFile(String filePath) async {
  try {
    final result = await OpenFilex.open(filePath);
    return result.type == ResultType.done;
  } catch (_) {
    return false;
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');
