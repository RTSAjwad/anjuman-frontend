import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/browser_provider.dart';
import 'providers/class_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/study_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/decks_screen.dart';
import 'screens/users_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/note_types_screen.dart';
import 'screens/stubs.dart';

void main() {
  runApp(const AnkiClassroomApp());
}

final _interTypography = Typography.geist().copyWith(
  sans: () => GoogleFonts.interTextTheme().bodyMedium!,
);

// Fixed branch indices (must match StatefulShellBranch order below).
class _NavItem {
  final int branchIndex;
  final String path;
  final IconData icon;
  final String label;
  const _NavItem(this.branchIndex, this.path, this.icon, this.label);
}

List<_NavItem> _navForRole(String role) {
  return switch (role) {
    'admin' => const [
        _NavItem(0, '/dashboard', LucideIcons.layoutDashboard, 'Dashboard'),
        _NavItem(1, '/classes', LucideIcons.users, 'Classes'),
        _NavItem(2, '/decks', LucideIcons.layers, 'Decks'),
        _NavItem(3, '/users', LucideIcons.users, 'Users'),
        _NavItem(4, '/note-types', LucideIcons.shapes, 'Note Types'),
        _NavItem(5, '/browser', LucideIcons.search, 'Browser'),
        _NavItem(6, '/me', LucideIcons.user, 'Me'),
      ],
    'teacher' => const [
        _NavItem(0, '/dashboard', LucideIcons.layoutDashboard, 'Dashboard'),
        _NavItem(1, '/classes', LucideIcons.users, 'Classes'),
        _NavItem(2, '/decks', LucideIcons.layers, 'Decks'),
        _NavItem(4, '/note-types', LucideIcons.shapes, 'Note Types'),
        _NavItem(5, '/browser', LucideIcons.search, 'Browser'),
        _NavItem(6, '/me', LucideIcons.user, 'Me'),
      ],
    'student' => const [
        _NavItem(0, '/dashboard', LucideIcons.layoutDashboard, 'Dashboard'),
        _NavItem(2, '/decks', LucideIcons.layers, 'Decks'),
        _NavItem(1, '/classes', LucideIcons.users, 'Classes'),
        _NavItem(5, '/browser', LucideIcons.search, 'Browser'),
        _NavItem(6, '/me', LucideIcons.user, 'Me'),
      ],
    _ => const [
        _NavItem(0, '/dashboard', LucideIcons.house, 'Home'),
        _NavItem(6, '/me', LucideIcons.user, 'Me'),
      ],
  };
}

class AnkiClassroomApp extends StatelessWidget {
  const AnkiClassroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Builder(
        builder: (context) {
          final router = GoRouter(
            refreshListenable: context.read<AuthProvider>(),
            initialLocation: '/decks',
            redirect: (context, state) {
              final auth = context.read<AuthProvider>();
              final isLogin = state.matchedLocation == '/login';
              if (!auth.isAuthenticated && !isLogin) return '/login';
              if (auth.isAuthenticated && isLogin) return '/decks';
              return null;
            },
            routes: [
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(),
              ),
              StatefulShellRoute.indexedStack(
                builder: (context, state, navigationShell) {
                  return MultiProvider(
                    providers: [
                      ChangeNotifierProvider(
                        create: (_) => ClassProvider(
                            context.read<AuthProvider>().apiClient),
                      ),
                      ChangeNotifierProvider(
                        create: (_) => DeckProvider(
                            context.read<AuthProvider>().apiClient),
                      ),
                      ChangeNotifierProvider(
                        create: (_) => StudyProvider(
                            context.read<AuthProvider>().apiClient),
                      ),
                      ChangeNotifierProvider(
                        create: (_) => UserProvider(
                            context.read<AuthProvider>().apiClient),
                      ),
                      ChangeNotifierProvider(
                        create: (_) => BrowserProvider(
                            context.read<AuthProvider>().apiClient),
                      ),
                    ],
                    child: _ShellScaffold(navigationShell: navigationShell),
                  );
                },
                branches: [
                  // 0: Dashboard
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/dashboard',
                        builder: (context, state) => const DashboardStub(),
                      ),
                    ],
                  ),
                  // 1: Classes
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/classes',
                        builder: (context, state) => const ClassesScreen(),
                      ),
                    ],
                  ),
                  // 2: Decks
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/decks',
                        redirect: (context, state) {
                          final study = state.uri.queryParameters['study'];
                          final fullscreen =
                              state.uri.queryParameters['fullscreen'];
                          final size = MediaQuery.of(context).size;
                          if (study != null &&
                              size.width < 600 &&
                              fullscreen != '1') {
                            return '/decks?study=$study&fullscreen=1';
                          }
                          return null;
                        },
                        builder: (context, state) => const DecksScreen(),
                      ),
                    ],
                  ),
                  // 3: Users
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/users',
                        builder: (context, state) => const UsersScreen(),
                      ),
                    ],
                  ),
                  // 4: Note Types
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/note-types',
                        builder: (context, state) =>
                            const NoteTypesScreen(provider: null),
                      ),
                    ],
                  ),
                  // 5: Browser
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/browser',
                        builder: (context, state) => const BrowserScreen(),
                      ),
                    ],
                  ),
                  // 6: Me
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/me',
                        builder: (context, state) {
                          return _MeScreen(auth: context.read<AuthProvider>());
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          return ShadcnApp.router(
            title: 'Anki Classroom',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorSchemes.lightNeutral,
              typography: _interTypography,
            ),
            darkTheme: ThemeData.dark(
              colorScheme: ColorSchemes.darkNeutral,
              typography: _interTypography,
            ),
            themeMode: ThemeMode.dark,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

class _MeScreen extends StatelessWidget {
  final AuthProvider auth;
  const _MeScreen({required this.auth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = auth.user;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Me'),
          trailing: [
            IconButton.outline(
              icon: const Icon(LucideIcons.logOut, size: 20, color: Colors.red),
              onPressed: () => auth.logout(),
            ),
          ],
        ),
      ],
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Avatar(
                  initials: '?',
                  size: 72,
                  borderRadius: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
                  style: theme.typography.h4,
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _ShellScaffold({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.role;
    final navItems = _navForRole(role);

    final currentBranchIndex = navigationShell.currentIndex;
    final selectedNavPos =
        navItems.indexWhere((n) => n.branchIndex == currentBranchIndex);
    final clampedPos = selectedNavPos.clamp(0, navItems.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        if (isWide) {
          return Row(
            children: [
              NavigationRail(
                selectedKey: ValueKey(navItems[clampedPos].branchIndex),
                expanded: false,
                labelType: NavigationLabelType.all,
                labelPosition: NavigationLabelPosition.bottom,
                onSelected: (key) {
                  if (key is ValueKey<int>) {
                    navigationShell.goBranch(key.value);
                  }
                },
                children: navItems
                    .map((item) => NavigationItem(
                          key: ValueKey(item.branchIndex),
                          label: Text(item.label),
                          child: Icon(item.icon),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 0),
              Expanded(child: navigationShell),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(child: navigationShell),
              NavigationBar(
                direction: Axis.horizontal,
                selectedKey: ValueKey(navItems[clampedPos].branchIndex),
                onSelected: (key) {
                  if (key is ValueKey<int>) {
                    navigationShell.goBranch(key.value);
                  }
                },
                children: navItems
                    .map((item) => NavigationItem(
                          key: ValueKey(item.branchIndex),
                          label: Text(item.label),
                          child: Icon(item.icon),
                        ))
                    .toList(),
              ),
            ],
          );
        }
      },
    );
  }
}
