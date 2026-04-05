import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailyhabits/screens/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders core controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);

    // Smoke-check: obscured password field has visibility toggle.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Toggling should swap the icon.
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
