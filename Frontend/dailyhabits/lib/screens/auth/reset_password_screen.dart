// =============================================================================
// File: reset_password_screen.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: OTP verification + password reset screen. The user enters
//              the 6-digit OTP received via email, then sets a new password.
//              Features: auto-focus OTP fields, countdown timer, resend OTP,
//              password strength meter, success animation, auto-redirect.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/screens/auth/login_screen.dart';

// =============================================================================
// ResetPasswordScreen Widget
// =============================================================================

/// OTP verification + new-password form.
///
/// Receives the user's [email] and OTP TTL from [ForgotPasswordScreen].
/// Lifecycle:
///   1. User enters the 6-digit OTP from their email.
///   2. User sets a new password (with strength meter).
///   3. On submit → verifies OTP + resets password in one API call.
///   4. On success → shows confirmation and auto-redirects to login.
class ResetPasswordScreen extends StatefulWidget {
  /// The email address the OTP was sent to.
  final String email;

  /// OTP time-to-live in seconds (default 600 = 10 minutes).
  final int otpTtlSeconds;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    this.otpTtlSeconds = 600,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  // ── OTP fields ──
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // ── Password fields ──
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // ── Password strength ──
  int _strength = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.transparent;

  // ── State ──
  bool _isSubmitting = false;
  bool _resetSuccess = false;
  String? _errorMessage;

  // ── Countdown timer ──
  late int _secondsRemaining;
  Timer? _timer;
  bool _canResend = false;
  bool _isResending = false;

  // ── Animation ──
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.otpTtlSeconds;
    _startCountdown();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _passwordCtrl.addListener(_evaluateStrength);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _passwordCtrl.removeListener(_evaluateStrength);
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Countdown timer
  // ---------------------------------------------------------------------------

  void _startCountdown() {
    _timer?.cancel();
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _formattedTime {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Resend OTP
  // ---------------------------------------------------------------------------

  Future<void> _handleResend() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final result =
          await AuthService().requestPasswordResetOTP(widget.email);

      if (!mounted) return;

      if (result['success'] == true) {
        // Clear OTP fields and focus first box for new code
        for (final c in _otpCtrls) {
          c.clear();
        }
        _otpFocusNodes[0].requestFocus();

        final newTtl = result['otp_ttl_seconds'] as int? ?? 600;
        setState(() {
          _secondsRemaining = newTtl;
          _canResend = false;
        });
        _startCountdown();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('New OTP sent! Check your email.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to resend OTP.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ---------------------------------------------------------------------------
  // OTP input handler
  // ---------------------------------------------------------------------------

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
  }

  void _onOtpKeyDown(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpCtrls[index].text.isEmpty &&
        index > 0) {
      _otpCtrls[index - 1].clear();
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  String get _otpValue =>
      _otpCtrls.map((c) => c.text).join();

  bool get _isOtpComplete => _otpValue.length == 6;

  // ---------------------------------------------------------------------------
  // Password strength evaluator
  // ---------------------------------------------------------------------------

  void _evaluateStrength() {
    final pwd = _passwordCtrl.text;
    int score = 0;

    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(pwd)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd)) score++;

    score = score.clamp(0, 4);

    String label;
    Color color;
    switch (score) {
      case 0:
        label = '';
        color = Colors.transparent;
      case 1:
        label = 'Weak';
        color = AppColors.error;
      case 2:
        label = 'Fair';
        color = AppColors.warning;
      case 3:
        label = 'Good';
        color = AppColors.info;
      case 4:
        label = 'Strong';
        color = AppColors.success;
      default:
        label = '';
        color = Colors.transparent;
    }

    if (mounted) {
      setState(() {
        _strength = score;
        _strengthLabel = label;
        _strengthColor = color;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Submit handler — verify OTP + reset password
  // ---------------------------------------------------------------------------

  Future<void> _handleReset() async {
    if (_isSubmitting) return;

    // Validate OTP first
    if (!_isOtpComplete) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService().verifyOTPAndResetPassword(
        email: widget.email,
        otp: _otpValue,
        newPassword: _passwordCtrl.text,
        confirmPassword: _confirmCtrl.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => _resetSuccess = true);
        // Auto-redirect to login after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Reset failed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: tc.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _resetSuccess
                    ? _buildSuccessCard(tc)
                    : _buildFormCard(tc),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main form card: OTP entry + new password
  // ---------------------------------------------------------------------------

  Widget _buildFormCard(ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tc.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon ──
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: tc.accent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.pin_rounded,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),

          // ── Title ──
          Text(
            'Enter Reset Code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: tc.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tc.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            widget.email,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tc.accent,
            ),
          ),
          const SizedBox(height: 24),

          // ── Error message ──
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 20, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── OTP input fields ──
          _buildOtpFields(tc),
          const SizedBox(height: 12),

          // ── Countdown timer + resend ──
          _buildTimerRow(tc),
          const SizedBox(height: 24),

          // ── Divider ──
          Row(
            children: [
              Expanded(child: Divider(color: tc.border, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'NEW PASSWORD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tc.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(child: Divider(color: tc.border, thickness: 1)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Password form ──
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildPasswordField(
                  controller: _passwordCtrl,
                  hint: 'New password',
                  obscure: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tc: tc,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a new password';
                    if (v.length < 8) return 'Must be at least 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(v)) {
                      return 'Include at least one uppercase letter';
                    }
                    if (!RegExp(r'[a-z]').hasMatch(v)) {
                      return 'Include at least one lowercase letter';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(v)) {
                      return 'Include at least one number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // ── Strength meter ──
                if (_passwordCtrl.text.isNotEmpty) ...[
                  _buildStrengthMeter(tc),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),

                _buildPasswordField(
                  controller: _confirmCtrl,
                  hint: 'Confirm password',
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  tc: tc,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Submit button ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Back ──
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Use a different email',
              style: TextStyle(
                color: tc.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OTP digit fields (6 boxes)
  // ---------------------------------------------------------------------------

  Widget _buildOtpFields(ThemeColors tc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 48,
          height: 56,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (e) => _onOtpKeyDown(e, i),
            child: TextFormField(
              controller: _otpCtrls[i],
              focusNode: _otpFocusNodes[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tc.textPrimary,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: _otpCtrls[i].text.isNotEmpty
                    ? tc.accent.withValues(alpha: 0.06)
                    : tc.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _otpCtrls[i].text.isNotEmpty
                        ? tc.accent.withValues(alpha: 0.5)
                        : tc.inputBorder,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: tc.accent, width: 2),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => _onOtpChanged(v, i),
            ),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Countdown timer row
  // ---------------------------------------------------------------------------

  Widget _buildTimerRow(ThemeColors tc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_canResend) ...[
          Icon(Icons.timer_outlined, size: 16, color: tc.textMuted),
          const SizedBox(width: 6),
          Text(
            'Code expires in $_formattedTime',
            style: TextStyle(
              fontSize: 13,
              color: _secondsRemaining <= 60
                  ? AppColors.warning
                  : tc.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          Text(
            'Didn\'t receive the code?',
            style: TextStyle(fontSize: 13, color: tc.textMuted),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isResending ? null : _handleResend,
            child: _isResending
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: tc.accent,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Resend',
                    style: TextStyle(
                      fontSize: 13,
                      color: tc.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Password strength meter
  // ---------------------------------------------------------------------------

  Widget _buildStrengthMeter(ThemeColors tc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _strength / 4,
            backgroundColor: tc.surfaceVariant,
            color: _strengthColor,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _strengthLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _strengthColor,
              ),
            ),
            Text(
              _passwordCtrl.text.length >= 8 ? '✓ 8+ chars' : '○ 8+ chars',
              style: TextStyle(
                fontSize: 11,
                color: _passwordCtrl.text.length >= 8
                    ? AppColors.success
                    : tc.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Success card (post-reset)
  // ---------------------------------------------------------------------------

  Widget _buildSuccessCard(ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tc.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Success icon ──
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 50, color: AppColors.success),
          ),
          const SizedBox(height: 24),
          Text(
            'Password Reset!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: tc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your password has been changed successfully.\nAll other sessions have been signed out.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: tc.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // ── Security badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'All devices re-authenticated',
                  style: TextStyle(
                    fontSize: 13,
                    color: tc.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Redirecting to login…',
            style: TextStyle(fontSize: 14, color: tc.textMuted),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            color: tc.accent,
            backgroundColor: tc.surfaceVariant,
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text(
              'Go to Login Now',
              style: TextStyle(
                color: tc.accent,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable password field builder
  // ---------------------------------------------------------------------------

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required ThemeColors tc,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: tc.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tc.textMuted),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: tc.textMuted),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: tc.textMuted,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: tc.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
