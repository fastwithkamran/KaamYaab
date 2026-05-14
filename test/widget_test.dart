import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaamyaab/main.dart';

void main() {
  testWidgets('KaamYaab app smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: KaamYaabApp()),
    );
    // Allow async init (AuthService, LanguageService) to settle
    await tester.pump(const Duration(milliseconds: 300));

    // App should render without throwing
    expect(tester.takeException(), isNull);
  });
}
