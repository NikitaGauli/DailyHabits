// =============================================================================
// File: export_data_page.dart
// Project: DailyHabits — Settings Module
//
// Enables the user to request a data export of their habit-tracking history.
// Supports CSV, JSON, and PDF formats with a configurable date range.
//
// Layout:
//   • Format selector — ChoiceChips for CSV / JSON / PDF.
//   • Date range picker — Inline date-range selection (defaults to last 30 days).
//   • Export button — Submits the export request with a loading indicator.
//   • Past exports list — Displays previously requested exports with statuses.
//
// This is a [StatefulWidget] because it manages local transient state
// (selected format, date range, loading flag) that does not belong in the
// controller.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../models/settings_models.dart';
import '../settings_controller.dart';

/// Data-export settings page allowing users to download their habit data.
///
/// Users select a format, a date range, and tap "Export Data" to queue an
/// export job on the backend. Previous exports are listed below with their
/// current status (pending / completed / failed).
class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

/// State for [ExportDataPage].
///
/// Manages local form inputs ([_format], [_range]) and the [_isExporting]
/// loading indicator. On init, sets a sensible default date range (last
/// 30 days) and triggers a background fetch of past exports.
class _ExportDataPageState extends State<ExportDataPage> {
  /// The currently selected export format key ("csv", "json", or "pdf").
  String _format = 'csv';

  /// The selected date range for the export.
  DateTimeRange? _range;

  /// Whether an export request is currently in flight.
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // Default to the last 30 days so the user has a sensible starting range.
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch any existing export requests once the widget tree is ready.
      context.read<SettingsController>().loadExports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Data'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Format Selector ────────────────────────────────────
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Format',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: _formats.entries.map((e) {
                      final selected = _format == e.key;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(e.value['label']!),
                            avatar: Icon(
                              _formatIcons[e.key],
                              size: 18,
                              color: selected
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                            selected: selected,
                            onSelected: (_) => setState(() => _format = e.key),
                            selectedColor:
                                colors.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: selected
                                  ? colors.primary
                                  : colors.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Date Range ─────────────────────────────────────────
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date Range',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range, color: colors.primary),
                          const SizedBox(width: 12),
                          Text(
                            _range != null
                                ? '${DateFormat('MMM d, y').format(_range!.start)}  —  ${DateFormat('MMM d, y').format(_range!.end)}'
                                : 'Select date range',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Export Button ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isExporting ? null : () => _export(ctrl),
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              label: Text(_isExporting ? 'Exporting...' : 'Export Data'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Past Exports ──────────────────────────────────────
          if (ctrl.exports.isNotEmpty) ...[
            Text('Past Exports',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...ctrl.exports.map((ex) => _ExportTile(export_: ex)),
          ],
        ],
      ),
    );
  }

  /// Opens the system date-range picker and updates [_range] on selection.
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  /// Submits the export request to the backend.
  ///
  /// Validates that a date range is selected, sets the loading flag, and
  /// shows a snackbar with the outcome. The loading flag is always cleared
  /// in the `finally` block.
  Future<void> _export(SettingsController ctrl) async {
    if (_range == null) return;
    setState(() => _isExporting = true);
    try {
      final dateFrom = DateFormat('yyyy-MM-dd').format(_range!.start);
      final dateTo = DateFormat('yyyy-MM-dd').format(_range!.end);
      final result = await ctrl.requestExport(
        format: _format,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['success'] == true
              ? 'Export requested! It will appear below when ready.'
              : result['error'] ?? 'Export failed'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Supported export format definitions with display labels.
  static final Map<String, Map<String, String>> _formats = {
    'csv': {'label': 'CSV'},
    'json': {'label': 'JSON'},
    'pdf': {'label': 'PDF'},
  };

  /// Icons associated with each export format.
  static final Map<String, IconData> _formatIcons = {
    'csv': Icons.table_chart_outlined,
    'json': Icons.data_object,
    'pdf': Icons.picture_as_pdf_outlined,
  };
}

// =============================================================================
//  PRIVATE WIDGETS — Export history tile.
// =============================================================================

/// Displays a single past export request as a card tile.
///
/// Shows the format icon, title, date range subtitle, and a color-coded
/// status badge (completed = green, failed = red, pending = amber).
class _ExportTile extends StatelessWidget {
  final ExportRequest export_;
  const _ExportTile({required this.export_});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = switch (export_.status) {
      'completed' => AppColors.success,
      'failed' => AppColors.error,
      _ => AppColors.warning,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          _formatIcon(export_.format),
          color: colors.primary,
        ),
        title: Text(
          '${export_.format.toUpperCase()} Export',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${export_.dateFrom} — ${export_.dateTo}',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _capitalize(export_.status),
            style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// Maps a format string to its corresponding Material icon.
  IconData _formatIcon(String f) => switch (f) {
        'csv' => Icons.table_chart_outlined,
        'json' => Icons.data_object,
        'pdf' => Icons.picture_as_pdf_outlined,
        _ => Icons.file_present,
      };

  /// Capitalizes the first letter of a status string for badge display.
  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
