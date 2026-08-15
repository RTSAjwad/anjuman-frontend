import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/browser_provider.dart';
import 'providers/card_state_provider.dart';
import 'providers/class_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/study_provider.dart';
import 'providers/user_provider.dart';
import 'widgets/narrow_app_bar.dart';
import 'widgets/drawer_context.dart';
import 'config/breakpoints.dart';
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
                        create: (_) => CardStateProvider(),
                      ),
                      ChangeNotifierProxyProvider<CardStateProvider,
                          StudyProvider>(
                        create: (_) => StudyProvider(
                            context.read<AuthProvider>().apiClient,
                            CardStateProvider()),
                        update: (_, cardState, study) =>
                            study!..cardState = cardState,
                      ),
                      ChangeNotifierProxyProvider<CardStateProvider,
                          BrowserProvider>(
                        create: (_) => BrowserProvider(
                            context.read<AuthProvider>().apiClient,
                            CardStateProvider()),
                        update: (_, cardState, browser) =>
                            browser!..cardState = cardState,
                      ),
                      ChangeNotifierProvider(
                        create: (_) => UserProvider(
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
            builder: (context, child) {
              // Prevent content from being drawn behind the Android status bar
              // (Flutter 3.44+ enables edge-to-edge rendering by default).
              return SafeArea(child: child ?? const SizedBox.shrink());
            },
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
        NarrowAppBar(
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

class _ShellScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _ShellScaffold({required this.navigationShell});

  @override
  State<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<_ShellScaffold>
    with SingleTickerProviderStateMixin {
  bool _drawerOpen = false;
  late final AnimationController _drawerController;
  late final Animation<Offset> _drawerSlide;

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _drawerSlide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _drawerController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  void _openDrawer() {
    setState(() => _drawerOpen = true);
    _drawerController.forward();
  }

  void _closeDrawer() {
    _drawerController.reverse().then((_) {
      if (mounted) setState(() => _drawerOpen = false);
    });
  }

  List<Widget> _buildNavChildren(String role, int selectedIndex) {
    final items = <Widget>[];

    // Dashboard (standalone)
    items.add(NavigationItem(
      key: const ValueKey(0),
      label: const Text('Dashboard'),
      child: const Icon(LucideIcons.layoutDashboard),
    ));
    items.add(const NavigationDivider());

    // Content group
    final contentChildren = <Widget>[];
    if (role == 'admin' || role == 'teacher' || role == 'student') {
      contentChildren.add(NavigationItem(
        key: const ValueKey(5),
        label: const Text('Browser'),
        child: const Icon(LucideIcons.search),
      ));
      contentChildren.add(NavigationItem(
        key: const ValueKey(2),
        label: const Text('Decks'),
        child: const Icon(LucideIcons.layers),
      ));
    }
    if (role == 'admin' || role == 'teacher') {
      contentChildren.add(NavigationItem(
        key: const ValueKey(4),
        label: const Text('Note Types'),
        child: const Icon(LucideIcons.shapes),
      ));
    }
    items.add(NavigationGroup(
      label: const Text('Content'),
      children: contentChildren,
    ));
    items.add(const NavigationDivider());

    // Organisation group
    final orgChildren = <Widget>[];
    if (role == 'admin' || role == 'teacher' || role == 'student') {
      orgChildren.add(NavigationItem(
        key: const ValueKey(1),
        label: const Text('Classes'),
        child: const Icon(LucideIcons.users),
      ));
    }
    if (role == 'admin') {
      orgChildren.add(NavigationItem(
        key: const ValueKey(3),
        label: const Text('Users'),
        child: const Icon(LucideIcons.users),
      ));
    }
    orgChildren.add(NavigationItem(
      key: const ValueKey(6),
      label: const Text('Me'),
      child: const Icon(LucideIcons.user),
    ));
    items.add(NavigationGroup(
      label: const Text('Organisation'),
      children: orgChildren,
    ));

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.role;
    final currentIndex = widget.navigationShell.currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width;
        final showNavRail = width >= Breakpoints.expanded;
        final navChildren = _buildNavChildren(role, currentIndex);

        Widget navRail = NavigationRail(
          selectedKey: ValueKey(currentIndex),
          expanded: width >= Breakpoints.large,
          labelType: NavigationLabelType.all,
          labelPosition: NavigationLabelPosition.bottom,
          onSelected: (key) {
            if (key is ValueKey<int>) {
              widget.navigationShell.goBranch(key.value);
            }
          },
          children: navChildren,
        );

        if (showNavRail) {
          _drawerOpen = false;
          return Row(
            children: [
              navRail,
              const VerticalDivider(width: 0),
              Expanded(child: widget.navigationShell),
            ],
          );
        } else {
          // Compact or Medium: hamburger drawer with stack
          return DrawerContext(
            onOpenDrawer: _openDrawer,
            child: Stack(
              children: [
                // Main content
                widget.navigationShell,
                // Backdrop
                if (_drawerOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeDrawer,
                      child: Container(color: Colors.black.withAlpha(128)),
                    ),
                  ),
                // Drawer
                if (_drawerOpen)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: SlideTransition(
                      position: _drawerSlide,
                      child: Container(
                        color: Theme.of(context).colorScheme.background,
                        child: NavigationRail(
                          selectedKey: ValueKey(currentIndex),
                          expanded: true,
                          labelType: NavigationLabelType.all,
                          labelPosition: NavigationLabelPosition.bottom,
                          onSelected: (key) {
                            if (key is ValueKey<int>) {
                              widget.navigationShell.goBranch(key.value);
                              _closeDrawer();
                            }
                          },
                          children: navChildren,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}
