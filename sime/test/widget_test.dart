import 'package:flutter_test/flutter_test.dart';
import 'package:sime/main.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const SimeApp());
    expect(find.byType(SimeApp), findsOneWidget);
  });
}
