import 'package:flutter/material.dart';
import 'package:dailyhabits/screens/auth/login_screen.dart';
import 'package:dailyhabits/screens/onboarding/widgets/onboarding_page.dart';
import 'package:dailyhabits/screens/onboarding/widgets/page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// OnboardingCarousel
/// ---------------------------------------------------------------------------
/// Swipeable onboarding flow with smooth transitions, skip/next buttons,
/// and persistent completion state.
/// ---------------------------------------------------------------------------
class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({super.key});

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = const [
    OnboardingPageData(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC855F7), Color(0xFFE91E8C)],
      ),
      imagePath: 'assets/images/onboarding_habits.png',
      title: 'Build Better Habits',
      description:
          'Track your daily progress and achieve\nyour goals one step at a time',
      overlayIcon: Icons.adjust_outlined,
      iconSize: 80,
    ),
    OnboardingPageData(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      ),
      imagePath: 'assets/images/onboarding_progress.png',
      title: 'Track Your Progress',
      description: 'Visualize your journey with beautiful\ncharts and insights',
      showCalendar: true,
    ),
    OnboardingPageData(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFA855F7), Color(0xFF9333EA)],
      ),
      imagePath: 'assets/images/onboarding_motivated.png',
      title: 'Stay Motivated',
      description: 'Get personalized reminders and celebrate\nevery milestone',
      overlayIcon: Icons.emoji_events_outlined,
      iconSize: 80,
      isLastPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChange(int pageIndex) {
    setState(() => _currentPage = pageIndex);
  }

  void _handleNextAction() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Onboarding Pages
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _handlePageChange,
            itemBuilder: (context, index) => OnboardingPageWidget(
              pageData: _pages[index],
              onSkip: _skipOnboarding,
            ),
          ),

          // Bottom Controls (Page indicator + Next/Get Started button)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PageIndicator(
                      pageCount: _pages.length,
                      currentPage: _currentPage,
                    ),
                    const SizedBox(height: 32),
                    _PrimaryActionButton(
                      label: _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      onPressed: _handleNextAction,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary Action Button
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFA855F7),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}
