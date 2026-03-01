// =============================================================================
// File: help_support_page.dart
// Project: DailyHabits — Settings Module
//
// A dual-tab Help & Support screen that provides:
//   • **FAQs Tab** — Categorized, expandable frequently-asked-question cards.
//   • **Support Tab** — A list of the user’s support tickets with the ability
//     to create new ones via a bottom-sheet form.
//
// Both tabs load their data lazily on first display via
// [SettingsController.loadFAQs] and [SettingsController.loadTickets].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/settings_models.dart';
import '../settings_controller.dart';

/// The main Help & Support screen with a tab bar for FAQs and Support tickets.
///
/// Uses a [TabController] with two tabs. Data for both tabs is fetched
/// in [initState] via post-frame callbacks to avoid calling Provider
/// during the build phase.
class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

/// State for [HelpSupportPage].
///
/// Owns the [TabController] life-cycle and triggers initial data loading
/// for FAQs and support tickets.
class _HelpSupportPageState extends State<HelpSupportPage>
    with SingleTickerProviderStateMixin {
  /// Controls the FAQs / Support tab bar.
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<SettingsController>();
      ctrl.loadFAQs();
      ctrl.loadTickets();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: 'FAQs'),
            Tab(text: 'Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _FAQTab(),
          _SupportTab(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FAQ TAB — Categorized, expandable question-answer list.
// ═════════════════════════════════════════════════════════════════════════════

/// Displays FAQ items grouped by their category.
///
/// Each category renders as an uppercase section header followed by a card
/// containing [ExpansionTile] items. Shows a loading spinner while data
/// is being fetched.
class _FAQTab extends StatelessWidget {
  const _FAQTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;

    if (ctrl.faqs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group FAQ items by their category for sectioned display.
    final grouped = <String, List<FAQItem>>{};
    for (final faq in ctrl.faqs) {
      grouped.putIfAbsent(faq.category, () => []).add(faq);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.expand((entry) {
        return [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              entry.key.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: entry.value.asMap().entries.map((e) {
                return Column(
                  children: [
                    if (e.key > 0) const Divider(height: 1, indent: 16),
                    ExpansionTile(
                      title: Text(e.value.question,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value.answer,
                            style: TextStyle(
                                fontSize: 14,
                                color: colors.textSecondary,
                                height: 1.5)),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ];
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUPPORT TAB — Ticket creation and history.
// ═════════════════════════════════════════════════════════════════════════════

/// Shows a “New Support Ticket” button and the list of the user’s tickets.
///
/// When no tickets exist, displays an encouraging empty-state illustration.
/// The “New Support Ticket” button opens a modal bottom sheet with a form
/// for subject, description, category, and priority.
class _SupportTab extends StatelessWidget {
  const _SupportTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Create Ticket ──────────────────────────────────────
        FilledButton.icon(
          onPressed: () => _showCreateTicketSheet(context, ctrl),
          icon: const Icon(Icons.add),
          label: const Text('New Support Ticket'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 20),

        // ── Ticket List ────────────────────────────────────────
        if (ctrl.tickets.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.support_agent,
                      size: 56, color: colors.textMuted),
                  const SizedBox(height: 12),
                  Text('No tickets yet',
                      style: TextStyle(
                          fontSize: 16, color: colors.textSecondary)),
                  const SizedBox(height: 4),
                  Text("We're here to help if you need anything!",
                      style: TextStyle(
                          fontSize: 13, color: colors.textMuted)),
                ],
              ),
            ),
          )
        else ...[
          Text('Your Tickets',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...ctrl.tickets.map((t) => _TicketTile(ticket: t)),
        ],
      ],
    );
  }

  /// Opens a modal bottom sheet with a form for creating a new support ticket.
  ///
  /// Collects subject (required), description, category (dropdown), and
  /// priority (dropdown). Submits via [SettingsController.createTicket] and
  /// shows a snackbar with the result.
  void _showCreateTicketSheet(BuildContext context, SettingsController ctrl) {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'general';
    String priority = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('New Support Ticket',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'general', child: Text('General')),
                            DropdownMenuItem(
                                value: 'bug', child: Text('Bug Report')),
                            DropdownMenuItem(
                                value: 'feature',
                                child: Text('Feature Request')),
                            DropdownMenuItem(
                                value: 'account', child: Text('Account')),
                            DropdownMenuItem(
                                value: 'billing', child: Text('Billing')),
                          ],
                          onChanged: (v) =>
                              setModalState(() => category = v ?? 'general'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'low', child: Text('Low')),
                            DropdownMenuItem(
                                value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(
                                value: 'high', child: Text('High')),
                            DropdownMenuItem(
                                value: 'urgent', child: Text('Urgent')),
                          ],
                          onChanged: (v) =>
                              setModalState(() => priority = v ?? 'medium'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (subjectCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        final result = await ctrl.createTicket(
                          subject: subjectCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          category: category,
                          priority: priority,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result['success'] == true
                                ? 'Ticket submitted successfully!'
                                : result['error'] ?? 'Failed to submit'),
                          ));
                        }
                      },
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Submit Ticket'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
//  PRIVATE WIDGETS — Ticket tile and mini-tag.
// =============================================================================

/// Renders a single support ticket as a card with subject, status badge,
/// description preview, optional admin response, and metadata tags.
class _TicketTile extends StatelessWidget {
  final SupportTicket ticket;
  const _TicketTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ticket.subject,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: ticket.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ticket.statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: ticket.statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (ticket.description != null &&
                ticket.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ticket.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: colors.textSecondary, height: 1.4)),
            ],
            if (ticket.adminResponse != null &&
                ticket.adminResponse!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Response',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                    const SizedBox(height: 2),
                    Text(ticket.adminResponse!,
                        style: TextStyle(
                            fontSize: 13,
                            color: colors.textPrimary,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                _MiniTag(
                    label: _capitalize(ticket.category),
                    color: colors.primary),
                const SizedBox(width: 6),
                _MiniTag(
                    label: _capitalize(ticket.priority),
                    color: _priorityColor(ticket.priority)),
                const Spacer(),
                Text(ticket.createdAt.split('T').first,
                    style:
                        TextStyle(fontSize: 11, color: colors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Capitalizes the first letter of a string for tag display.
  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Returns a semantic color based on the ticket priority level.
  Color _priorityColor(String p) => switch (p) {
        'urgent' => AppColors.error,
        'high' => const Color(0xFFF97316),
        'medium' => AppColors.warning,
        _ => AppColors.info,
      };
}

/// A small, rounded tag chip used for displaying category and priority labels
/// on support tickets.
class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
