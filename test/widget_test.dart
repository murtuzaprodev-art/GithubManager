import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:github_manager_pro/providers/app_state_provider.dart';
import 'package:github_manager_pro/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the login screen is shown after initializing.
    await tester.pump(); // Triggers post-frame callback
    await tester.pump(const Duration(milliseconds: 200)); // Completes storage future
    await tester.pump(); // Renders the state change
    expect(find.text('GitHub Manager Pro'), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
  });
}

