// =============================================================================
// File: forgot_password_screen.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: OTP-based forgot-password screen. Collects the user's email
//              and requests a 6-digit OTP from the backend. On success,
//              navigates to the OTP verification + password reset screen.
//              Always shows a generic success to prevent user enumeration.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/screens/auth/reset_password_screen.dart';

// =============================================================================
// ForgotPasswordScreen Widget
// =============================================================================

/// Full-screen form that collects the user's email address and dispatches
/// an OTP-based forgot-password request.
///
/// On success, navigates to [ResetPasswordScreen] where the user enters
/// the 6-digit OTP and sets a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Submit handler — request OTP
  // ---------------------------------------------------------------------------

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService()
          .requestPasswordResetOTP(_emailCtrl.text.trim());

      if (!mounted) return;

      if (result['success'] == true) {
        final otpTtl = result['otp_ttl_seconds'] as int? ?? 600;

        // Navigate to the OTP verification + reset screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              email: _emailCtrl.text.trim().toLowerCase(),
              otpTtlSeconds: otpTtl,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Something went wrong.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      // Even on network error, navigate forward to prevent enumeration
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: _emailCtrl.text.trim().toLowerCase(),
            otpTtlSeconds: 600,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                child: _buildFormCard(tc),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form card
  // ---------------------------------------------------------------------------

  Widget _buildFormCard(ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tc.border, width: 1.5),
      ),
      child: Form(
        key: _formKey,
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
              child: const Icon(Icons.lock_reset_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),

            // ── Title ──
            Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your email and we\'ll send you\na 6-digit reset code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tc.textSecondary),
            ),
            const SizedBox(height: 32),

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

            // ── Email field ──
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSubmit(),
              style: TextStyle(color: tc.textPrimary),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: TextStyle(color: tc.textMuted),
                prefixIcon: Icon(Icons.email_outlined, color: tc.textMuted),
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
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Submit button ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tc.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Send OTP Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Info chip ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: tc.accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'A 6-digit code will be sent to your email',
                      style: TextStyle(
                        fontSize: 12,
                        color: tc.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Back to login ──
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Back to Login',
                style: TextStyle(
                  color: tc.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
