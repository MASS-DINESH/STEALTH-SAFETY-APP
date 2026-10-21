import 'package:flutter_test/flutter_test.dart';
import 'package:safety_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalSafetyApp());
    expect(find.byType(PersonalSafetyApp), findsOneWidget);
  });
}
