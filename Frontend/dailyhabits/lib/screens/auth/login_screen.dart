import 'package:flutter/material.dart';
import 'package:dailyhabits/screens/auth/signup_screen.dart';
import 'package:dailyhabits/screens/home/home_page.dart';
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// ---------------------------------------------------------------------------
/// LoginScreen
/// ---------------------------------------------------------------------------
/// Professional login screen with theme-aware styling.
/// Saves login state to SharedPreferences for SplashScreen navigation.
/// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Text controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// UI state flags
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles user login and saves login status
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService().login(
        _emailController.text.trim(),
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
            content: Text(result['message'] ?? 'Login failed'),
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

  /// Navigate to Signup screen
  void _navigateToSignup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }

  /// Gradient background
  Widget _buildBackground({required Widget child}) {
    final tc = context.colors;
    return Container(
      decoration: BoxDecoration(gradient: tc.bgGradient),
      child: child,
    );
  }

  /// Login form
  Widget _buildLoginForm() {
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

  /// Login card
  Widget _buildCard() {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: tc.border,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildFormFields(),
          const SizedBox(height: 12),
          _buildForgotPassword(),
          const SizedBox(height: 20),
          _buildLoginButton(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildSocialButtons(),
          const SizedBox(height: 20),
          _buildSignupLink(),
        ],
      ),
    );
  }

  /// Card header
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
            Icons.login_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick up where you left off',
          style: TextStyle(
            fontSize: 15,
            color: tc.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Form fields
  Widget _buildFormFields() {
    final tc = context.colors;
    return Column(
      children: [
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
          validator: (value) => (value == null || value.isEmpty)
              ? 'Enter your password'
              : null,
        ),
      ],
    );
  }

  /// Forgot password
  Widget _buildForgotPassword() {
    final tc = context.colors;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset coming soon'),
            ),
          );
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Forgot Password?',
          style: TextStyle(color: tc.accent, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Login button
  Widget _buildLoginButton() {
    return _SolidButton(
      label: 'Log in',
      isLoading: _isLoading,
      onPressed: _handleLogin,
    );
  }

  /// Divider
  Widget _buildDivider() {
    final tc = context.colors;
    return Text(
      'or sign in with',
      style: TextStyle(
        fontSize: 14,
        color: tc.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Social login buttons
  Widget _buildSocialButtons() {
    return _SocialButton(
      icon: Icons.g_mobiledata_rounded,
      label: 'Google',
      onPressed: () {},
    );
  }

  /// Signup link
  Widget _buildSignupLink() {
    final tc = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "New here? ",
          style: TextStyle(color: tc.textSecondary),
        ),
        TextButton(
          onPressed: _navigateToSignup,
          child: Text(
            'Create Account',
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

/// ---------------------------------------------------------------------------
/// Theme-aware TextField
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
        prefixIcon: Icon(
          prefixIcon,
          color: tc.textMuted,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: tc.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: tc.inputBorder,
            width: 1,
          ),
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
/// Solid button
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
/// Social button
/// ---------------------------------------------------------------------------
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tc.textPrimary,
          side: BorderSide(
            color: tc.border,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 24, color: tc.textPrimary),
        label: Text(
          label,
          style: TextStyle(
            color: tc.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
