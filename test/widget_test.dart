import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/main/app.dart';

void main() {
  testWidgets('App loads onboarding welcome', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Jewel Flow'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('I already have an account'), findsNothing);
  });
}
