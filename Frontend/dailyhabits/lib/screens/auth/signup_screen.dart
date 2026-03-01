// **signup_screen.dart** — User Registration Screen
//
// This file implements the account creation flow for DailyHabits, including:
//   - A theme-aware gradient background with a centred card layout.
//   - Name, email, and password form fields with real-time validation
//     (minimum 8 characters, not purely numeric).
//   - A social sign-up (Google) placeholder button.
//   - Navigation back to [LoginScreen] for existing users.
//
// On successful registration the user is immediately logged in and
// redirected to [HomePage], bypassing the login form entirely.
//
// Authentication is delegated to [AuthService.register], which persists
// tokens to `SharedPreferences` for seamless session continuity.
//
// See also:
//   - [LoginScreen] for existing-user authentication.
//   - [AuthService] for the underlying REST registration API.
//   - [HomePage] for the post-signup entry point.

// =============================================================================
// Imports
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/screens/auth/login_screen.dart';
import 'package:dailyhabits/screens/home/home_page.dart';
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/google_auth_service.dart';
import 'package:dailyhabits/theme/app_theme.dart';

// =============================================================================
// SignupScreen Widget
// =============================================================================

/// ---------------------------------------------------------------------------
/// SignupScreen
/// ---------------------------------------------------------------------------
/// A professional signup screen with theme-aware styling.
/// Allows users to create an account using name, email, and password.
/// Includes social login placeholders and navigation to login screen.
/// ---------------------------------------------------------------------------
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  /// Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// UI state flags
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    /// Dispose controllers to avoid memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// -------------------------------------------------------------------------
  /// Handles user signup process
  /// -------------------------------------------------------------------------
  /// - Validates form input
  /// - Displays loading indicator
  /// - Simulates API request
  /// - Navigates to HomePage on success
  /// -------------------------------------------------------------------------
  Future<void> _handleSignup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService().register(
        _emailController.text.trim(),
        _nameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        // Navigate to HomePage — initState will trigger loadData()
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Registration failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Navigates user to login screen
  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// -------------------------------------------------------------------------
  /// Handles Google sign-up / sign-in flow
  /// -------------------------------------------------------------------------
  /// Steps:
  /// 1. Initiates Google Sign-In via [GoogleAuthService]
  /// 2. Sends the Google ID token to the Django backend
  /// 3. Backend verifies the token and returns JWT tokens
  /// 4. On success, navigates to [HomePage]
  /// 5. On failure, shows an error SnackBar
  /// -------------------------------------------------------------------------
  Future<void> _handleGoogleSignup() async {
    if (_isGoogleLoading || _isLoading) return;

    setState(() => _isGoogleLoading = true);

    try {
      final result = await GoogleAuthService().signInWithGoogle();

      if (!mounted) return;

      if (result['success'] == true) {
        // Navigate to HomePage on successful Google auth
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else if (result['cancelled'] != true) {
        // Show error only if user didn't cancel
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Google sign-in failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSignupForm(),
            ),
          ),
        ),
      ),
    );
  }

  /// Gradient background wrapper for the entire signup screen.
  Widget _buildBackground({required Widget child}) {
    final tc = context.colors;
    return Container(
      decoration: BoxDecoration(gradient: tc.bgGradient),
      child: child,
    );
  }

  /// Wraps the signup card inside a [Form] widget for validation.
  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// The main signup card containing header, fields, buttons, and links.
  Widget _buildCard() {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tc.border, width: 1.5),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildFormFields(),
          const SizedBox(height: 24),
          _buildSignupButton(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildSocialButtons(),
          const SizedBox(height: 20),
          _buildLoginLink(),
        ],
      ),
    );
  }

  /// App icon, title ("Get Started"), and subtitle displayed at the card top.
  Widget _buildHeader() {
    final tc = context.colors;
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: tc.accent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Get Started',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Build habits that stick',
          style: TextStyle(fontSize: 15, color: tc.textSecondary),
        ),
      ],
    );
  }

  /// Name, email, and password input fields with inline validation.
  Widget _buildFormFields() {
    final tc = context.colors;
    return Column(
      children: [
        _GlassTextField(
          controller: _nameController,
          hintText: 'Full name',
          prefixIcon: Icons.person_outline_rounded,
          validator: (value) =>
              value == null || value.isEmpty ? 'Enter your name' : null,
        ),
        const SizedBox(height: 16),
        _GlassTextField(
          controller: _emailController,
          hintText: 'Email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter your email';
            }
            if (!value.contains('@')) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _GlassTextField(
          controller: _passwordController,
          hintText: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: tc.textMuted,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter a password';
            }
            if (value.length < 8) {
              return 'At least 8 characters';
            }
            if (RegExp(r'^\d+$').hasMatch(value)) {
              return 'Password can\'t be entirely numeric';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Primary "Create Account" button with loading state support.
  Widget _buildSignupButton() {
    return _SolidButton(
      label: 'Create Account',
      isLoading: _isLoading,
      onPressed: _handleSignup,
    );
  }

  /// Separator text between the signup button and social sign-up options.
  Widget _buildDivider() {
    final tc = context.colors;
    return Text(
      'or sign up with',
      style: TextStyle(
        fontSize: 14,
        color: tc.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Google sign-up button with loading state support.
  Widget _buildSocialButtons() {
    return _SocialButton(
      icon: Icons.g_mobiledata_rounded,
      label: 'Continue with Google',
      isLoading: _isGoogleLoading,
      onPressed: _handleGoogleSignup,
    );
  }

  /// "Already have an account? Log In" navigation link to [LoginScreen].
  Widget _buildLoginLink() {
    final tc = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: tc.textSecondary),
        ),
        TextButton(
          onPressed: _navigateToLogin,
          child: Text(
            'Log In',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              color: tc.accent,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared Private Widgets
// =============================================================================

/// ---------------------------------------------------------------------------
/// Theme-aware glass-morphism style text field.
///
/// Used across auth screens for a consistent, modern input appearance.
/// Supports optional obscuring (for passwords), custom validators, and
/// a trailing suffix icon (e.g. visibility toggle).
/// ---------------------------------------------------------------------------
class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: tc.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: tc.textMuted),
        prefixIcon: Icon(prefixIcon, color: tc.textMuted),
        suffixIcon: suffixIcon,
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
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Full-width solid primary action button with loading spinner.
///
/// Disables tap handling and shows a [CircularProgressIndicator] when
/// [isLoading] is `true`.
/// ---------------------------------------------------------------------------
class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: tc.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Outlined social login button (icon + label).
///
/// Currently used for Google sign-up. Additional providers can be added
/// by instantiating more [_SocialButton] widgets with different icons.
/// ---------------------------------------------------------------------------
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tc.textPrimary,
          side: BorderSide(color: tc.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tc.textMuted,
                ),
              )
            : Icon(icon, size: 24, color: tc.textPrimary),
        label: Text(
          isLoading ? 'Signing in...' : label,
          style: TextStyle(
            color: isLoading ? tc.textMuted : tc.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
