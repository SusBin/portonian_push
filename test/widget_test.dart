// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:portonian_push/main.dart';

void main() {
  testWidgets('shows the Portonian Push dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PortonianApp());
    await tester.pump();

    expect(find.text('PORTONIAN PUSH'), findsOneWidget);
    expect(find.text('ACTIVATE BEACON'), findsOneWidget);
    expect(find.text('SEND ALERT'), findsOneWidget);
    expect(find.text('Basic Alert Transfer'), findsOneWidget);
    expect(find.text('Alert Feed'), findsOneWidget);
    expect(find.text('Discovered Devices'), findsOneWidget);
    expect(find.text('Scan Log'), findsOneWidget);
  });

  testWidgets('shows hybrid and evaluation sections by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PortonianApp());
    await tester.pump();

    expect(find.text('Hybrid Status'), findsOneWidget);
    expect(find.text('Evaluation Metrics'), findsOneWidget);
    expect(find.text('HYBRID: CHECKING...'), findsOneWidget);
    expect(find.text('Cloud link: unavailable'), findsOneWidget);
    expect(find.text('MANET failover: standby'), findsOneWidget);
    expect(find.text('Reset evaluation metrics'), findsOneWidget);
  });
}
