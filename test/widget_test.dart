import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_sample_project/main.dart';

void main() {
  testWidgets('FocusSenseApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FocusSenseApp(startAtOnboarding: true));

    // Verify that onboarding screen is displayed.
    expect(find.text('Welcome to FocusSense'), findsOneWidget);
  });
}
