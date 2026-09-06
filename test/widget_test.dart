import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AniDash widget environment renders', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: Text('AniDash'))),
        ),
      ),
    );

    expect(find.text('AniDash'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
