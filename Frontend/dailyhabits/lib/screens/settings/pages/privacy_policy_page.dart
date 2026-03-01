// =============================================================================
// File: privacy_policy_page.dart
// Project: DailyHabits — Settings Module
//
// Displays the application’s privacy policy in a rich, formatted layout.
// The policy document is fetched asynchronously from the backend and rendered
// with a decorative header (icon, title, version chip, last-updated chip),
// a content body that auto-detects section headings vs. paragraph text,
// and a footer showing the effective date.
//
// Data source: [SettingsController.loadPrivacyPolicy] → [PrivacyPolicyModel].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Full-page view of the application’s privacy policy.
///
/// Fetches the policy document on first build and shows a spinner until
/// the data arrives. The layout includes a branded header, version/date
/// metadata chips, the parsed policy body, and an effective-date footer.
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

/// State for [PrivacyPolicyPage].
///
/// Triggers [SettingsController.loadPrivacyPolicy] once via a post-frame
/// callback to avoid calling Provider during the initial build.
class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsController>().loadPrivacyPolicy();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final policy = ctrl.privacyPolicy;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy'), centerTitle: true),
      body: policy == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.privacy_tip,
                            color: colors.primary, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          policy.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MetaChip(
                                label: 'Version ${policy.version}',
                                icon: Icons.tag),
                            const SizedBox(width: 8),
                            _MetaChip(
                                label: 'Updated ${policy.lastUpdated}',
                                icon: Icons.update),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Policy Content ────────────────────────────
                  _PolicyContent(content: policy.content),

                  const SizedBox(height: 24),

                  // ── Effective Date ────────────────────────────
                  Center(
                    child: Text(
                      'Effective since ${policy.effectiveDate}',
                      style: TextStyle(
                          fontSize: 13, color: colors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// =============================================================================
//  PRIVATE WIDGETS — Metadata chip and content renderer.
// =============================================================================

/// A small rounded chip displaying an icon and label for metadata
/// (e.g. version number, last-updated date).
class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: colors.primary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Renders the plain-text privacy policy content with automatic formatting.
///
/// Splits the content on double-newlines into paragraphs. Lines that are
/// short, single-line, and fully uppercase are treated as section headings
/// and rendered in bold with extra spacing. All other text is rendered as
/// regular paragraphs with comfortable line height.
class _PolicyContent extends StatelessWidget {
  final String content;
  const _PolicyContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Split on double-newlines to identify distinct paragraphs.
    final paragraphs = content.split(RegExp(r'\n\n+'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        final trimmed = para.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();

        // Check if it's a section heading (starts with uppercase, single line, short)
        if (!trimmed.contains('\n') && trimmed.length < 60 && trimmed == trimmed.toUpperCase()) {
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              trimmed,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            trimmed,
            style: TextStyle(
              fontSize: 15,
              color: colors.textPrimary,
              height: 1.6,
            ),
          ),
        );
      }).toList(),
    );
  }
}
