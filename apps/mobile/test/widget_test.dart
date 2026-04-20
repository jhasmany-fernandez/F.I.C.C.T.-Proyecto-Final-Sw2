import 'package:flutter_test/flutter_test.dart';

import 'package:ficct_final_app/src/app.dart';

void main() {
  testWidgets('renders the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FicctFinalApp());

    expect(find.text('FICCT Final App'), findsOneWidget);
    expect(find.text('Base Flutter lista para crecer'), findsOneWidget);
    expect(find.textContaining('http://localhost:3000/api'), findsOneWidget);
  });
}
