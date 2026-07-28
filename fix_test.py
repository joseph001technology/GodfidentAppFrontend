import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    f.write(
        "import 'package:flutter_test/flutter_test.dart';\n"
        "\n"
        "import 'package:godfident/main.dart';\n"
        "\n"
        "void main() {\n"
        "  testWidgets('app launches', (tester) async {\n"
        "    await tester.pumpWidget(const GodfidentApp());\n"
        "    expect(find.byType(GodfidentApp), findsOneWidget);\n"
        "  });\n"
        "}\n"
    )
