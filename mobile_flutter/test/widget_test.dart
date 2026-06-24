import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/app/app.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const AiInterviewApp());
    expect(find.byType(AiInterviewApp), findsOneWidget);
  });
}
