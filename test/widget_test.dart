import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App widget test harness', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('ChatsApp')),
        ),
      ),
    );

    expect(find.text('ChatsApp'), findsOneWidget);
  });
}
