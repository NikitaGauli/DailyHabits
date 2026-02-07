import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dailyhabits/screens/splash/splash_screen.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/screens/home/home_controller.dart';
import 'package:dailyhabits/screens/notifications/notification_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // System chrome is updated dynamically inside MyApp based on theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider(create: (_) => NotificationController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DailyHabits',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
