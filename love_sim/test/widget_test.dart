import 'package:flutter_test/flutter_test.dart';
import 'package:love_sim/main.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const LoveSimApp());
    expect(find.byType(LoveSimApp), findsOneWidget);
  });
}
