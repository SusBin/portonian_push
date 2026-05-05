import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:portonian_push/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launches the app and exposes core controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PortonianApp());
    await tester.pump();

    expect(find.text('PORTONIAN PUSH'), findsOneWidget);
    expect(find.text('Basic Alert Transfer'), findsOneWidget);
    expect(find.text('Hybrid Status'), findsOneWidget);
    expect(find.text('Evaluation Metrics'), findsOneWidget);
    expect(find.text('SEND ALERT'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Test alert');
    await tester.tap(find.text('Reset evaluation metrics'));
    await tester.pump();

    expect(find.text('Reset evaluation metrics'), findsOneWidget);
  });
}
