// =============================================================================
// File: websocket_service.dart
// Description: Real-time WebSocket client for the DailyHabits notification
//              system. Connects to the Django Channels backend to receive
//              instant notification delivery and badge count updates.
//
// Architecture:
//   The service establishes a persistent WebSocket connection after user
//   login and automatically reconnects with exponential backoff on failure.
//   Incoming events are dispatched to registered listeners (typically the
//   [NotificationController]) for state updates and UI rendering.
//
// Protocol:
//   - Connection URL: ws://<host>:<port>/ws/notifications/?token=<jwt>
//   - Server → Client events:
//       • new_notification — A new notification was created
//       • badge_update     — Unread count changed
//       • pong             — Keepalive response
//   - Client → Server events:
//       • ping             — Keepalive heartbeat
//       • mark_read        — Mark a notification as read via WebSocket
//
// Security:
//   JWT access tokens are passed via query string to the WebSocket
//   handshake. The Django Channels consumer validates the token and
//   rejects unauthorized connections with close code 4001.
//
// See also:
//   - [NotificationController] — Consumes WebSocket events for state mgmt.
//   - [ApiConfig]              — Platform-aware host resolution.
//   - notifications/consumers.py — Server-side WebSocket handler.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/notification_model.dart';

// =============================================================================
// Callback Type Definitions
// =============================================================================

/// Called when a new notification arrives via WebSocket.
typedef OnNotificationReceived = void Function(AppNotification notification);

/// Called when the server sends an updated unread badge count.
typedef OnBadgeUpdate = void Function(int unreadCount);

/// Called when the WebSocket connection state changes.
typedef OnConnectionStateChanged = void Function(WebSocketConnectionState state);

// =============================================================================
// Connection State Enum
// =============================================================================

/// Represents the current state of the WebSocket connection.
enum WebSocketConnectionState {
  /// Not connected; no active connection attempt.
  disconnected,

  /// Actively attempting to establish a connection.
  connecting,

  /// Connected and authenticated; ready to receive events.
  connected,

  /// Connection lost; waiting before next reconnection attempt.
  reconnecting,
}

// =============================================================================
// WebSocket Notification Service
// =============================================================================

/// Manages a persistent WebSocket connection to the Django Channels backend
/// for real-time notification delivery.
///
/// **Usage:**
/// ```dart
/// final ws = WebSocketNotificationService();
/// ws.onNotificationReceived = (notification) { /* update UI */ };
/// ws.onBadgeUpdate = (count) { /* update badge */ };
/// await ws.connect();
/// ```
///
/// **Reconnection Strategy:**
/// Uses exponential backoff starting at 1 second, doubling on each failure
/// up to a maximum of 30 seconds. The backoff resets on successful connection.
///
/// **Keepalive:**
/// Sends a ``ping`` message every 30 seconds to prevent idle connection
/// timeouts from proxies and load balancers.
class WebSocketNotificationService {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  /// Shared [AuthService] for retrieving the JWT access token.
  final AuthService _authService = AuthService();

  // ---------------------------------------------------------------------------
  // Connection State
  // ---------------------------------------------------------------------------

  /// The active WebSocket channel, or `null` if disconnected.
  WebSocketChannel? _channel;

  /// Subscription to the WebSocket message stream.
  StreamSubscription? _subscription;

  /// Current connection state.
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  /// Whether [connect] has been called and [disconnect] has not.
  bool _shouldBeConnected = false;

  // ---------------------------------------------------------------------------
  // Reconnection Backoff
  // ---------------------------------------------------------------------------

  /// Timer for scheduling reconnection attempts.
  Timer? _reconnectTimer;

  /// Current reconnection delay in seconds (exponential backoff).
  int _reconnectDelaySec = 1;

  /// Maximum reconnection delay in seconds.
  static const int _maxReconnectDelaySec = 30;

  /// Base reconnection delay in seconds.
  static const int _baseReconnectDelaySec = 1;

  // ---------------------------------------------------------------------------
  // Keepalive
  // ---------------------------------------------------------------------------

  /// Timer for periodic ping messages.
  Timer? _pingTimer;

  /// Interval between keepalive pings.
  static const Duration _pingInterval = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Event Callbacks
  // ---------------------------------------------------------------------------

  /// Called when a new notification is received from the server.
  OnNotificationReceived? onNotificationReceived;

  /// Called when the server sends a badge count update.
  OnBadgeUpdate? onBadgeUpdate;

  /// Called when the connection state changes.
  OnConnectionStateChanged? onConnectionStateChanged;

  /// Returns the current connection state.
  WebSocketConnectionState get connectionState => _state;

  /// Whether the WebSocket is currently connected and authenticated.
  bool get isConnected => _state == WebSocketConnectionState.connected;

  // ---------------------------------------------------------------------------
  // Connect
  // ---------------------------------------------------------------------------

  /// Establishes a WebSocket connection to the notification server.
  ///
  /// Retrieves a fresh JWT access token from [AuthService], constructs the
  /// platform-appropriate WebSocket URL, and opens the connection.
  ///
  /// If already connected, this method is a no-op.
  /// On failure, automatically schedules a reconnection attempt.
  Future<void> connect() async {
    if (_state == WebSocketConnectionState.connected ||
        _state == WebSocketConnectionState.connecting) {
      return;
    }

    _shouldBeConnected = true;
    _updateState(WebSocketConnectionState.connecting);

    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[WebSocket] No auth token available — skipping connect');
        _updateState(WebSocketConnectionState.disconnected);
        return;
      }

      final wsUrl = _buildWebSocketUrl(token);
      debugPrint('[WebSocket] Connecting to $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for the connection to be established
      await _channel!.ready;

      _updateState(WebSocketConnectionState.connected);
      _resetReconnectDelay();
      _startPingTimer();

      debugPrint('[WebSocket] Connected successfully');

      // Listen for incoming messages
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _updateState(WebSocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  /// Closes the WebSocket connection and cancels all timers.
  ///
  /// Call this on user logout or app disposal to cleanly tear down
  /// the real-time connection.
  void disconnect() {
    _shouldBeConnected = false;
    _cancelTimers();
    _subscription?.cancel();
    _subscription = null;

    if (_channel != null) {
      _channel!.sink.close(ws_status.goingAway);
      _channel = null;
    }

    _updateState(WebSocketConnectionState.disconnected);
    debugPrint('[WebSocket] Disconnected');
  }

  // ---------------------------------------------------------------------------
  // Send Messages
  // ---------------------------------------------------------------------------

  /// Sends a ``mark_read`` event to the server via WebSocket.
  ///
  /// This provides a faster path for marking notifications as read
  /// compared to the HTTP endpoint. The server broadcasts the updated
  /// badge count to all of the user's connected devices.
  void markNotificationRead(int notificationId) {
    _send({
      'type': 'mark_read',
      'notification_id': notificationId,
    });
  }

  /// Sends a raw JSON message over the WebSocket.
  void _send(Map<String, dynamic> data) {
    if (_channel != null && _state == WebSocketConnectionState.connected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  // ---------------------------------------------------------------------------
  // Message Handling
  // ---------------------------------------------------------------------------

  /// Processes an incoming WebSocket message from the server.
  ///
  /// Dispatches to the appropriate callback based on the ``type`` field:
  /// - ``new_notification`` → deserializes and invokes [onNotificationReceived]
  /// - ``badge_update``     → invokes [onBadgeUpdate] with the unread count
  /// - ``pong``             → keepalive acknowledgement (logged, no action)
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      switch (type) {
        case 'new_notification':
          final notifData = data['notification'] as Map<String, dynamic>?;
          if (notifData != null) {
            final notification = AppNotification.fromJson(notifData);
            debugPrint('[WebSocket] New notification: ${notification.title}');
            onNotificationReceived?.call(notification);
          }
          break;

        case 'badge_update':
          final count = data['unread_count'] as int? ?? 0;
          debugPrint('[WebSocket] Badge update: $count');
          onBadgeUpdate?.call(count);
          break;

        case 'pong':
          // Keepalive acknowledged — no action required
          break;

        default:
          debugPrint('[WebSocket] Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('[WebSocket] Error parsing message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Error & Disconnection Handling
  // ---------------------------------------------------------------------------

  /// Handles WebSocket stream errors.
  void _onError(dynamic error) {
    debugPrint('[WebSocket] Stream error: $error');
    _handleDisconnection();
  }

  /// Handles WebSocket stream completion (connection closed).
  void _onDone() {
    debugPrint('[WebSocket] Connection closed');
    _handleDisconnection();
  }

  /// Common handler for unexpected disconnections.
  ///
  /// Cleans up the current connection and schedules a reconnection
  /// attempt if the service is supposed to be connected.
  void _handleDisconnection() {
    _stopPingTimer();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_shouldBeConnected) {
      _updateState(WebSocketConnectionState.reconnecting);
      _scheduleReconnect();
    } else {
      _updateState(WebSocketConnectionState.disconnected);
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnection Logic (Exponential Backoff)
  // ---------------------------------------------------------------------------

  /// Schedules a reconnection attempt with exponential backoff.
  ///
  /// The delay starts at [_baseReconnectDelaySec] and doubles on each
  /// consecutive failure, capped at [_maxReconnectDelaySec].
  /// A small random jitter (0–500 ms) is added to prevent thundering-herd
  /// reconnection storms across multiple clients.
  void _scheduleReconnect() {
    if (!_shouldBeConnected) return;

    _reconnectTimer?.cancel();
    final jitter = Random().nextInt(500);
    final delay = Duration(seconds: _reconnectDelaySec, milliseconds: jitter);

    debugPrint(
      '[WebSocket] Reconnecting in ${delay.inMilliseconds}ms '
      '(attempt delay: ${_reconnectDelaySec}s)',
    );

    _reconnectTimer = Timer(delay, () async {
      if (_shouldBeConnected) {
        await connect();
      }
    });

    // Exponential backoff: double the delay for the next attempt
    _reconnectDelaySec = min(
      _reconnectDelaySec * 2,
      _maxReconnectDelaySec,
    );
  }

  /// Resets the reconnection delay to the base value after a successful
  /// connection.
  void _resetReconnectDelay() {
    _reconnectDelaySec = _baseReconnectDelaySec;
  }

  // ---------------------------------------------------------------------------
  // Keepalive Ping
  // ---------------------------------------------------------------------------

  /// Starts the periodic ping timer.
  ///
  /// Sends a ``{"type": "ping"}`` message every [_pingInterval] to keep
  /// the connection alive through proxies and load balancers that may
  /// close idle connections.
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      _send({'type': 'ping'});
    });
  }

  /// Stops the periodic ping timer.
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Builds the platform-appropriate WebSocket URL with JWT token.
  ///
  /// Derives the WebSocket URL from [ApiConfig.baseUrl] by:
  /// 1. Replacing ``http://`` with ``ws://`` (or ``https://`` → ``wss://``).
  /// 2. Stripping the ``/api`` suffix.
  /// 3. Appending the WebSocket path and token query parameter.
  String _buildWebSocketUrl(String token) {
    final httpBase = ApiConfig.baseUrl; // e.g., http://localhost:8000/api

    // Convert HTTP scheme to WebSocket scheme
    String wsBase = httpBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    // Remove trailing /api to get the root: ws://localhost:8000
    if (wsBase.endsWith('/api')) {
      wsBase = wsBase.substring(0, wsBase.length - 4);
    }

    return '$wsBase/ws/notifications/?token=$token';
  }

  /// Updates the connection state and notifies the listener.
  void _updateState(WebSocketConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      onConnectionStateChanged?.call(newState);
    }
  }

  /// Cancels all active timers (reconnect + ping).
  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopPingTimer();
  }
}
