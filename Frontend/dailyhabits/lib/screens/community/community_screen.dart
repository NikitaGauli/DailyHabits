// =============================================================================
// File: community_screen.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: The primary Community hub screen, organised as a five-tab layout
//              powered by TabController. Tabs include: Feed, Friends, Groups,
//              Invite (referral), and Joined Dashboard. Each tab is implemented
//              as a private widget that delegates data operations to
//              [CommunityController].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/app_animations.dart';
import 'package:dailyhabits/widgets/common/shimmer_loading.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';
import 'package:dailyhabits/screens/grow_together/grow_together_screen.dart';
import 'package:dailyhabits/screens/community/group_detail_screen.dart';
import 'community_controller.dart';
import 'widgets/feed_post_card.dart';
import 'widgets/friend_tiles.dart';
import 'widgets/group_cards.dart';
import 'widgets/shared_habit_card.dart';

/// Top-level entry point for the Community feature.
///
/// Manages a [TabController] with five tabs and creates a
/// [CommunityController] for shared state management across all tabs.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

/// Stateful implementation of [CommunityScreen].
///
/// Uses [SingleTickerProviderStateMixin] to drive the [TabController].
/// The controller and tab bar are initialised in [initState] and properly
/// disposed in [dispose] to prevent memory leaks.
class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  /// Controller for the five-tab navigation bar.
  late TabController _tab;

  /// Shared state controller for all community data operations.
  late CommunityController _ctrl;

  /// Guards against showing the loading spinner after the first paint.
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _ctrl = CommunityController();
    _ctrl.loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Consumer<CommunityController>(
        builder: (context, ctrl, _) {
          if (!_didInit && !ctrl.isLoading) _didInit = true;

          return Scaffold(
            backgroundColor: context.colors.bg,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, ctrl),
                  Expanded(
                    child: ctrl.isLoading && !_didInit
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            children: List.generate(
                              4,
                              (_) => const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: ShimmerBox(
                                  width: double.infinity,
                                  height: 120,
                                  borderRadius: 20,
                                ),
                              ),
                            ),
                          )
                        : TabBarView(
                            controller: _tab,
                            children: [
                              _FeedTab(ctrl: ctrl),
                              _FriendsTab(ctrl: ctrl),
                              _GroupsTab(ctrl: ctrl),
                              _InviteTab(ctrl: ctrl),
                              _JoinedTab(ctrl: ctrl),
                            ],
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

  // ═══════════════════════════════════════════════════════════════
  //  HEADER + TAB BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, CommunityController ctrl) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Community',
                  style: AppTextStyles.h2.copyWith(color: tc.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Grow Together',
                onPressed: () => Navigator.push(
                  context,
                  AppPageRoute.slideUp(const GrowTogetherScreen()),
                ),
                icon: Icon(Icons.group_work_rounded, color: AppColors.secondary),
              ),
              IconButton(
                onPressed: () => ctrl.loadAll(),
                icon: Icon(Icons.refresh_rounded, color: tc.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassContainer(
            padding: const EdgeInsets.all(4),
            borderRadius: BorderRadius.circular(30),
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: tc.primary,
                borderRadius: BorderRadius.circular(26),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: tc.textSecondary,
              labelStyle: AppTextStyles.button.copyWith(fontSize: 13),
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: const [
                Tab(text: 'Feed'),
                Tab(text: 'Friends'),
                Tab(text: 'Groups'),
                Tab(text: 'Invite'),
                Tab(text: 'Joined'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// =============================================================================
//  TAB 1 — FEED
//  Displays a paginated list of community feed posts with like and comment
//  interactions. Supports pull-to-refresh and infinite scroll pagination.
// =============================================================================

/// Social feed tab showing posts from friends and group members.
class _FeedTab extends StatelessWidget {
  final CommunityController ctrl;
  const _FeedTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final hasShared = ctrl.sharedHabits.isNotEmpty;
    final hasFeed = ctrl.feedPosts.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ctrl.loadFeed(reset: true),
          ctrl.loadSharedHabits(),
        ]);
      },
      color: tc.primary,
      child: (!hasShared && !hasFeed)
          ? _emptyState(
              context,
              icon: Icons.dynamic_feed_outlined,
              title: 'Your feed is quiet',
              subtitle:
                  'Add friends or join groups to see their progress here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              // shared habits header + cards + feed posts + sentinel
              itemCount:
                  (hasShared ? ctrl.sharedHabits.length + 1 : 0) +
                  ctrl.feedPosts.length +
                  1,
              itemBuilder: (context, i) {
                // ── Shared With You header ──
                if (hasShared && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, size: 18, color: tc.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Shared With You',
                          style: AppTextStyles.h3.copyWith(
                            color: tc.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ── Shared habit cards ──
                if (hasShared && i > 0 && i <= ctrl.sharedHabits.length) {
                  final sh = ctrl.sharedHabits[i - 1];
                  return SharedHabitCard(
                    habit: sh,
                    onReact: (type) => ctrl.reactToHabit(sh.habitId, type),
                    onComment: () =>
                        _showHabitCommentSheet(context, sh.habitId),
                    onJoin: () => ctrl.joinHabit(sh.habitId),
                  );
                }

                // ── Feed posts ──
                final feedIdx =
                    i - (hasShared ? ctrl.sharedHabits.length + 1 : 0);
                if (feedIdx < ctrl.feedPosts.length) {
                  final post = ctrl.feedPosts[feedIdx];
                  return FeedPostCard(
                    post: post,
                    onLike: () => ctrl.toggleLike(post['id']),
                    onComment: () => _showCommentSheet(context, post['id']),
                  );
                }

                // ── Infinite scroll sentinel ──
                if (ctrl.hasMoreFeed) {
                  ctrl.loadFeed();
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tc.primary,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
    );
  }

  /// Shows a modal bottom sheet for composing and submitting a comment
  /// on the post identified by [postId].
  void _showCommentSheet(BuildContext context, int postId) {
    final tc = context.colors;
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add a comment',
                style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                style: TextStyle(color: tc.textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write something supportive…',
                  hintStyle: TextStyle(color: tc.textMuted),
                  filled: true,
                  fillColor: tc.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (textCtrl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      // Fire and forget — controller refreshes feed
                      ctrl.loadFeed(reset: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tc.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Post Comment',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows a bottom sheet for adding comments to a shared habit.
  void _showHabitCommentSheet(BuildContext context, int habitId) {
    final tc = context.colors;
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add a comment',
                style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                style: TextStyle(color: tc.textPrimary),
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: 'Cheer them on\u2026',
                  hintStyle: TextStyle(color: tc.textMuted),
                  counterText: '',
                  filled: true,
                  fillColor: tc.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final text = textCtrl.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.pop(ctx);
                      ctrl.commentOnHabit(habitId, text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tc.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Post Comment',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
//  TAB 2 — FRIENDS
//  Provides user search, incoming friend request management, and a list of
//  current friends with streak badges. Feedback snackbars surface controller
//  action results.
// =============================================================================

/// Friends management tab with search, requests, and friend list.
class _FriendsTab extends StatefulWidget {
  final CommunityController ctrl;
  const _FriendsTab({required this.ctrl});

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Consumes the controller’s one-shot [actionMessage] and shows a
  /// floating snackbar coloured by success or failure.
  void _showFeedback(BuildContext context, CommunityController ctrl) {
    if (ctrl.actionMessage != null) {
      final msg = ctrl.actionMessage!;
      final ok = ctrl.actionSuccess;
      ctrl.actionMessage = null; // consume it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? context.colors.success : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final ctrl = widget.ctrl;

    // Post-frame callback ensures the snackbar fires after the current build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFeedback(context, ctrl);
    });

    return RefreshIndicator(
      onRefresh: () => ctrl.loadFriends(),
      color: tc.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        children: [
          // search bar
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.search, color: tc.textMuted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: tc.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Find people…',
                      hintStyle: TextStyle(color: tc.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) {
                      setState(() => _showSearch = v.length >= 2);
                      ctrl.searchUsers(v);
                    },
                  ),
                ),
                if (_showSearch)
                  IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _showSearch = false);
                      ctrl.searchUsers('');
                    },
                    icon: Icon(Icons.close, size: 18, color: tc.textMuted),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // search results
          if (_showSearch) ...[
            _sectionLabel(context, 'Search Results'),
            if (ctrl.isSearching)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tc.primary,
                  ),
                ),
              )
            else if (ctrl.searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No users found',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
                ),
              )
            else
              ...ctrl.searchResults.map(
                (u) => UserSearchTile(
                  user: u,
                  onAdd: () async {
                    await ctrl.sendFriendRequest(u['id']);
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],

          // incoming requests
          if (ctrl.incomingRequests.isNotEmpty) ...[
            _sectionLabel(context, 'Friend Requests'),
            ...ctrl.incomingRequests.map(
              (r) => FriendRequestTile(
                request: r,
                onAccept: () async {
                  await ctrl.acceptRequest(r['friendshipId']);
                },
                onReject: () async {
                  await ctrl.rejectRequest(r['friendshipId']);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // my friends
          _sectionLabel(
            context,
            'My Friends',
            trailing: '${ctrl.friends.length}',
          ),
          if (ctrl.friends.isEmpty)
            _emptyState(
              context,
              icon: Icons.people_outline,
              title: 'No friends yet',
              subtitle: 'Search for people above to send friend requests.',
            )
          else
            ...ctrl.friends.map(
              (f) => FriendTile(
                friend: f,
                onAction: () async {
                  await ctrl.removeFriend(f['id']);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Renders a bold section label with an optional trailing count badge.
  Widget _sectionLabel(BuildContext context, String title, {String? trailing}) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              color: tc.textPrimary,
              fontSize: 16,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tc.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailing,
                style: AppTextStyles.caption.copyWith(
                  color: tc.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
//  TAB 3 — GROUPS
//  Lists the user's groups with action chips for creating or joining groups,
//  and group cards with inline leave / invite-code-copy actions.
// =============================================================================

/// Groups management tab with create, join, and browse functionality.
class _GroupsTab extends StatelessWidget {
  final CommunityController ctrl;
  const _GroupsTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return RefreshIndicator(
      onRefresh: () => ctrl.loadGroups(),
      color: tc.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        children: [
          // action chips
          Row(
            children: [
              Expanded(
                child: _actionChip(
                  context,
                  icon: Icons.add_circle_outline,
                  label: 'Create Group',
                  onTap: () => _showCreateDialog(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionChip(
                  context,
                  icon: Icons.login_rounded,
                  label: 'Join with Code',
                  onTap: () => _showJoinDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // my groups
          _sectionTitle(context, 'My Groups', count: ctrl.myGroups.length),
          const SizedBox(height: 8),
          if (ctrl.myGroups.isEmpty)
            _emptyState(
              context,
              icon: Icons.group_outlined,
              title: 'No groups yet',
              subtitle: 'Create a group or join one using an invite code.',
            )
          else
            ...ctrl.myGroups.map(
              (g) => GroupCard(
                group: g,
                onTap: () async {
                  final dynamic gid = g['id'];
                  final int? groupId = gid is int ? gid : int.tryParse('$gid');
                  if (groupId == null || groupId <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to open this group right now.')),
                    );
                    return;
                  }

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: ctrl,
                        child: GroupDetailScreen(
                          groupId: groupId,
                          groupName: g['name'] ?? 'Group',
                        ),
                      ),
                    ),
                  );
                  ctrl.loadGroups();
                },
                onLeave: () => ctrl.leaveGroup(g['id']),
                onDelete: () => _confirmDeleteGroup(context, g),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a tappable icon-and-label chip used for primary group actions.
  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final tc = context.colors;
    return GlassContainer(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: tc.primary, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  fontSize: 13,
                  color: tc.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders a section heading with an optional numeric [count] badge.
  Widget _sectionTitle(BuildContext context, String title, {int? count}) {
    final tc = context.colors;
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.h3.copyWith(color: tc.textPrimary, fontSize: 16),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tc.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: tc.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Opens a dialog for creating a new group with a name and
  /// optional description.
  void _showCreateDialog(BuildContext context) {
    final tc = context.colors;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final memberCtrl = TextEditingController();
    final members = <String>[];

    bool isValidEmail(String value) {
      final v = value.trim();
      if (v.isEmpty || !v.contains('@')) return false;
      final parts = v.split('@');
      return parts.length == 2 && parts[0].isNotEmpty && parts[1].contains('.');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tc.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('New Group', style: TextStyle(color: tc.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(tc, nameCtrl, 'Group name'),
                const SizedBox(height: 12),
                _dialogField(tc, descCtrl, 'Description (optional)'),
                const SizedBox(height: 14),
                Text(
                  'Add Members (Optional)',
                  style: AppTextStyles.caption.copyWith(
                    color: tc.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _dialogField(tc, memberCtrl, 'Enter member email'),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          final email = memberCtrl.text.trim().toLowerCase();
                          if (!isValidEmail(email)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid email address')),
                            );
                            return;
                          }
                          if (members.contains(email)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Member already added')),
                            );
                            return;
                          }
                          setDialogState(() {
                            members.add(email);
                            memberCtrl.clear();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tc.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
                if (members.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: members
                        .map(
                          (email) => Chip(
                            label: Text(email),
                            onDeleted: () {
                              setDialogState(() {
                                members.remove(email);
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: tc.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  ctrl.createGroup(
                    nameCtrl.text.trim(),
                    descCtrl.text.trim(),
                    initialMembers: members,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(members.isEmpty ? 'Create' : 'Create + Invite'),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a dialog prompting for an invite code to join an existing group.
  void _showJoinDialog(BuildContext context) {
    final tc = context.colors;
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Join Group', style: TextStyle(color: tc.textPrimary)),
        content: _dialogField(tc, codeCtrl, 'Paste invite code'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: tc.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                ctrl.joinGroup(codeCtrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tc.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  /// A themed text field used inside create / join dialogs.
  Widget _dialogField(ThemeColors tc, TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: tc.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tc.textMuted),
        filled: true,
        fillColor: tc.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Confirm group deletion for admin users.
  void _confirmDeleteGroup(BuildContext context, Map<String, dynamic> group) {
    final tc = context.colors;
    final groupId = group['id'] is int ? group['id'] as int : int.tryParse('${group['id']}');
    final groupName = group['name'] ?? 'this group';

    if (groupId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Group', style: TextStyle(color: tc.textPrimary)),
        content: Text(
          'Delete "$groupName" for all members? This cannot be undone.',
          style: TextStyle(color: tc.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: tc.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.deleteGroup(groupId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tc.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  TAB 4 — INVITE / REFERRAL
//  Displays the user's referral code, invite stats, and a share button.
//  Provides a hero card, stat counters, and clipboard copy functionality.
// =============================================================================

/// Referral / invite tab that surfaces the user’s unique referral code
/// and tracks how many people they’ve invited and how many joined.
class _InviteTab extends StatelessWidget {
  final CommunityController ctrl;
  const _InviteTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final ref = ctrl.referralData;

    return RefreshIndicator(
      onRefresh: () => ctrl.loadReferral(),
      color: tc.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        children: [
          // hero card
          GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: tc.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: tc.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Invite Friends',
                  style: AppTextStyles.h2.copyWith(color: tc.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Share your referral code and build habits together.',
                  style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // stats row
          Row(
            children: [
              Expanded(
                child: _statCard(
                  context,
                  '${ref?['totalInvited'] ?? 0}',
                  'Invited',
                  Icons.outgoing_mail,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  context,
                  '${ref?['totalJoined'] ?? 0}',
                  'Joined',
                  Icons.how_to_reg_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // referral code + copy
          if (ref != null) ...[
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Referral Code',
                          style: AppTextStyles.caption.copyWith(
                            color: tc.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ref['code'] ?? '—',
                          style: AppTextStyles.h3.copyWith(
                            color: tc.primary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: ref['code'] ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                    icon: Icon(Icons.copy_rounded, color: tc.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // share button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ctrl.loadReferral();
                if (context.mounted && ctrl.referralData != null) {
                  Clipboard.setData(
                    ClipboardData(text: ctrl.referralData!['code'] ?? ''),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Referral code copied!')),
                  );
                }
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text(
                'Share Referral Code',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a centred stat card with an icon, large value, and caption.
  Widget _statCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final tc = context.colors;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: tc.primary, size: 26),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.bold,
              color: tc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tc.textMuted),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  TAB 5 — JOINED DASHBOARD
//  Presents a summary view of the user's social footprint: friends count,
//  groups joined, community streak, group details, and recent friend activity.
// =============================================================================

/// Joined dashboard tab showing community membership at a glance.
class _JoinedTab extends StatelessWidget {
  final CommunityController ctrl;
  const _JoinedTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final data = ctrl.joinedData;

    return RefreshIndicator(
      onRefresh: () => ctrl.loadJoined(),
      color: tc.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        children: [
          // hero stats
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  context,
                  '${data?['totalFriends'] ?? 0}',
                  'Friends',
                  Icons.people_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  context,
                  '${data?['totalGroups'] ?? 0}',
                  'Groups',
                  Icons.groups_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  context,
                  '${data?['communityStreak'] ?? 0}',
                  'Streak',
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // groups section
          Text(
            'Your Groups',
            style: AppTextStyles.h3.copyWith(
              color: tc.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if ((data?['groups'] as List?)?.isEmpty ?? true)
            _emptyState(
              context,
              icon: Icons.group_outlined,
              title: 'No groups joined',
              subtitle: 'Join a group in the Groups tab to see it here.',
            )
          else
            ...(data!['groups'] as List).map((g) {
              final group = g as Map<String, dynamic>;
              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tc.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.group, color: tc.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['name'] ?? '',
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tc.textPrimary,
                            ),
                          ),
                          Text(
                            '${group['memberCount'] ?? 0} members',
                            style: AppTextStyles.caption.copyWith(
                              color: tc.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tc.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        group['myRole'] ?? '',
                        style: AppTextStyles.caption.copyWith(
                          color: tc.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 22),

          // recent friend activity
          Text(
            'Friend Activity',
            style: AppTextStyles.h3.copyWith(
              color: tc.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if ((data?['recentFriendActivity'] as List?)?.isEmpty ?? true)
            _emptyState(
              context,
              icon: Icons.dynamic_feed_outlined,
              title: 'No recent activity',
              subtitle:
                  'When your friends complete habits, their updates appear here.',
            )
          else
            ...(data!['recentFriendActivity'] as List).map(
              (p) => FeedPostCard(post: p as Map<String, dynamic>),
            ),
        ],
      ),
    );
  }

  /// Builds a compact stat widget for the hero row (friends, groups, streak).
  Widget _heroStat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final tc = context.colors;
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: tc.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.bold,
              color: tc.textPrimary,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tc.textMuted),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  SHARED HELPERS
//  Utility widgets used across multiple community tabs.
// =============================================================================

/// Displays a centred empty-state placeholder with an icon, title, and
/// subtitle. Used when a tab has no content to show.
Widget _emptyState(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  final tc = context.colors;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, color: tc.border, size: 56),
        const SizedBox(height: 14),
        Text(
          title,
          style: AppTextStyles.bodyLg.copyWith(
            color: tc.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
