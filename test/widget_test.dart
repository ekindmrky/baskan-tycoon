import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:presidento/logic/game_provider.dart';
import 'package:presidento/main.dart';

void main() {
  testWidgets('PresidentoApp builds with main menu', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: GameProvider(),
        child: const PresidentoApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Yeni Oyun'), findsOneWidget);
  });
}
