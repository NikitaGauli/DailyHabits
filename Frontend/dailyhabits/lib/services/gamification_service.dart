// =============================================================================
// File: gamification_service.dart
// Description: Service layer for all gamification API interactions.
//              Handles dashboard, XP history, wallet, streak freezes,
//              challenges, leaderboard, daily bonus, and milestones.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/gamification_models.dart';

// =============================================================================
// Gamification Service
// =============================================================================

/// Service for communicating with the gamification backend endpoints.
///
/// All requests are authenticated via JWT tokens from [AuthService].
/// Endpoints live under `/api/gamification/`.
class GamificationService {
  // ---------------------------------------------------------------------------
  // Configuration & Dependencies
  // ---------------------------------------------------------------------------

  final AuthService _authService = AuthService();

  String get _baseUrl => '${ApiConfig.baseUrl}/gamification';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  /// Fetches the composite gamification dashboard for the authenticated user.
  ///
  /// Includes level/XP, wallet, streak info, active challenges, daily bonus
  /// status, and recent activity.
  Future<GamificationDashboard?> getDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return GamificationDashboard.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // XP History
  // ---------------------------------------------------------------------------

  /// Fetches the paginated XP event history.
  Future<List<XPEvent>> getXPHistory({int page = 1, int pageSize = 20}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/xp-history/?limit=$pageSize'),        
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['events'] as List?)
                  ?.map((e) => XPEvent.fromJson(e))
                  .toList() ??
              [];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Daily Login Bonus
  // ---------------------------------------------------------------------------

  /// Claims the daily login bonus. Returns the XP and coins awarded, or null.
  Future<Map<String, dynamic>?> claimDailyLogin() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/claim-login/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Wallet
  // ---------------------------------------------------------------------------

  /// Fetches the user's virtual currency wallet.
  Future<Wallet?> getWallet() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/wallet/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Wallet.fromJson(data['wallet'] ?? {});
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Streak Freezes
  // ---------------------------------------------------------------------------

  /// Fetches the user's streak freeze tokens.
  Future<StreakFreezeInfo?> getStreakFreezes() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/freezes/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return StreakFreezeInfo.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Purchases a streak freeze token (costs coins).
  /// Returns a result map with success status and updated balance.
  Future<Map<String, dynamic>?> buyStreakFreeze() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/buy-freeze/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Challenges
  // ---------------------------------------------------------------------------

  /// Fetches the user's challenges (active + completed).
  Future<List<Challenge>> getMyChallenges() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/challenges/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['challenges'] as List?)
                  ?.map((c) => Challenge.fromJson(c))
                  .toList() ??
              [];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches community challenges available to join.
  Future<List<Challenge>> getCommunityChallenges() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/community-challenges/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['challenges'] as List?)
                  ?.map((c) => Challenge.fromJson(c))
                  .toList() ??
              [];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Creates a new challenge.
  Future<Challenge?> createChallenge({
    required String title,
    required String description,
    required String scope,
    required String difficulty,
    required DateTime startDate,
    required DateTime endDate,
    required int target,
    required String criteriaType,
    int xpReward = 100,
    int coinReward = 20,
    int maxParticipants = 1,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/create/'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
          'scope': scope,
          'difficulty': difficulty,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'criteria': {'type': criteriaType, 'target': target},
          'xp_reward': xpReward,
          'coin_reward': coinReward,
          'max_participants': maxParticipants,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['challenge'] != null) {
          return Challenge.fromJson(data['challenge']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Joins an existing challenge.
  Future<bool> joinChallenge(int challengeId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/$challengeId/join/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------

  /// Fetches leaderboard data for a given board type.
  /// [boardType] can be 'weekly', 'monthly', or 'alltime'.
  Future<Leaderboard?> getLeaderboard({String boardType = 'weekly'}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/leaderboard/?type=$boardType'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Leaderboard.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Milestones
  // ---------------------------------------------------------------------------

  /// Fetches all milestone rewards and which ones the user has reached.
  Future<Map<String, dynamic>?> getMilestones() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/milestones/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Triggers a manual milestone check for the authenticated user.
  Future<List<MilestoneReward>> checkMilestones() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/check-milestones/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['newMilestones'] as List?)
                  ?.map((m) => MilestoneReward.fromJson(m))
                  .toList() ??
              [];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Admin / Seed (development only)
  // ---------------------------------------------------------------------------

  /// Seeds default milestone rewards (staff-only endpoint).
  Future<bool> seedMilestones() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/seed/'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
