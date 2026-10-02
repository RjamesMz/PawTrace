import 'package:flutter_test/flutter_test.dart';
import 'package:pawtrace_app/main.dart';

void main() {
  testWidgets('PetTrace smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PetTraceApp());
    expect(find.byType(PetTraceApp), findsOneWidget);
  });
}
