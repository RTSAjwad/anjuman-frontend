import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anki_classroom_frontend/main.dart';
import 'package:anki_classroom_frontend/services/api_client.dart';

void main() {
  testWidgets('App shows login screen when not authenticated',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: AnkiClassroomApp(apiClient: ApiClient()),
      ),
    );
    await tester.pumpAndSettle();

    // Should show the login screen with the app title
    expect(find.text('Anki Classroom'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
