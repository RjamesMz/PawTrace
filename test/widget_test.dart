import 'package:flutter_test/flutter_test.dart';
import 'package:pawtrace_app/main.dart';

void main() {
  testWidgets('PawTrace smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PawTraceApp());
    expect(find.byType(PawTraceApp), findsOneWidget);
  });
}
