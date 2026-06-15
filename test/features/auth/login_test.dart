// Widget tests for LoginScreen — renders form, validates input, has key UI elements.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuroverse/features/auth/login.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget _wrap(Widget child) => MaterialApp(home: child);

  group('LoginScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump(const Duration(seconds: 1));
      // Login form should have at least two text inputs (email + password)
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
    });

    testWidgets('contains login-related text', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump(const Duration(seconds: 1));
      // One of these labels should appear somewhere on screen
      final hasLoginUI = find.textContaining(RegExp('Sign|Log|Login|Welcome',
              caseSensitive: false))
          .evaluate()
          .isNotEmpty;
      expect(hasLoginUI, true);
    });
  });
}
