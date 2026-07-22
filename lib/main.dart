import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/browser_provider.dart';
import 'providers/class_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/study_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const AnkiClassroomApp());
}

class AnkiClassroomApp extends StatelessWidget {
  const AnkiClassroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Anki Classroom',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => ClassProvider(auth.apiClient),
              ),
              ChangeNotifierProvider(
                create: (_) => DeckProvider(auth.apiClient),
              ),
              ChangeNotifierProvider(
                create: (_) => StudyProvider(auth.apiClient),
              ),
              ChangeNotifierProvider(
                create: (_) => UserProvider(auth.apiClient),
              ),
              ChangeNotifierProvider(
                create: (_) => BrowserProvider(auth.apiClient),
              ),
            ],
            child: const AppShell(),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
