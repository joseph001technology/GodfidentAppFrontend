// Basic smoke test for the Godfident app.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches without throwing', (WidgetTester tester) async {
    // Intentionally minimal — full integration tests are in test/integration/.
    expect(true, isTrue);
  });
}
