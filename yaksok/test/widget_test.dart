import 'package:flutter_test/flutter_test.dart';
import 'package:yaksok/main.dart';

void main() {
  testWidgets('YakSok app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const YakSokApp());
    expect(find.text('약쏙'), findsWidgets);
  });
}
