import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/app.dart';

void main() {
  testWidgets('shows the empty server list', (tester) async {
    await tester.pumpWidget(const TrueNasMobileApp());
    expect(find.text('No servers yet'), findsOneWidget);
    expect(find.text('Add server'), findsOneWidget);
  });
}
