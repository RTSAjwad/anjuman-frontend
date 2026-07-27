import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/auth_provider.dart';
import 'classes_screen.dart';
import 'decks_screen.dart';
import 'users_screen.dart';
import 'browser_screen.dart';
import 'note_types_screen.dart';
import 'stubs.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.role;

    final navItems = _navItemsForRole(role);
    final screens = _screensForRole(role);

    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        if (isWide) {
          return _buildWideLayout(navItems, screens);
        } else {
          return _buildNarrowLayout(navItems, screens);
        }
      },
    );
  }

  Widget _buildWideLayout(
    List<_NavItem> navItems,
    List<Widget> screens,
  ) {
    return Row(
      children: [
        NavigationRail(
          selectedKey: ValueKey(navItems[_selectedIndex].key),
          expanded: false,
          labelType: NavigationLabelType.all,
          labelPosition: NavigationLabelPosition.end,
          onSelected: (key) {
            if (key is ValueKey<int>) {
              setState(() => _selectedIndex = key.value);
            }
          },
          children: navItems
              .map((item) => NavigationItem(
                    key: ValueKey(item.key),
                    label: Text(item.label),
                    child: Icon(item.icon),
                  ))
              .toList(),
        ),
        const VerticalDivider(width: 0),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    List<_NavItem> navItems,
    List<Widget> screens,
  ) {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
        ),
        NavigationBar(
          direction: Axis.horizontal,
          selectedKey: ValueKey(navItems[_selectedIndex].key),
          onSelected: (key) {
            if (key is ValueKey<int>) {
              setState(() => _selectedIndex = key.value);
            }
          },
          children: navItems
              .map((item) => NavigationItem(
                    key: ValueKey(item.key),
                    label: Text(item.label),
                    child: Icon(item.icon),
                  ))
              .toList(),
        ),
      ],
    );
  }

  List<_NavItem> _navItemsForRole(String role) {
    final base = switch (role) {
      'admin' => [
          _NavItem(0, LucideIcons.layoutDashboard, 'Dashboard'),
          _NavItem(1, LucideIcons.users, 'Classes'),
          _NavItem(2, LucideIcons.layers, 'Decks'),
          _NavItem(3, LucideIcons.users, 'Users'),
          _NavItem(4, LucideIcons.shapes, 'Note Types'),
          _NavItem(5, LucideIcons.search, 'Browser'),
        ],
      'teacher' => [
          _NavItem(0, LucideIcons.layoutDashboard, 'Dashboard'),
          _NavItem(1, LucideIcons.users, 'Classes'),
          _NavItem(2, LucideIcons.layers, 'Decks'),
          _NavItem(3, LucideIcons.shapes, 'Note Types'),
          _NavItem(4, LucideIcons.search, 'Browser'),
        ],
      'student' => [
          _NavItem(0, LucideIcons.layoutDashboard, 'Dashboard'),
          _NavItem(1, LucideIcons.layers, 'Decks'),
          _NavItem(2, LucideIcons.users, 'Classes'),
          _NavItem(3, LucideIcons.search, 'Browser'),
        ],
      _ => [
          _NavItem(0, LucideIcons.house, 'Home'),
        ],
    };
    return [...base, _NavItem(base.length, LucideIcons.user, 'Me')];
  }

  List<Widget> _screensForRole(String role) {
    final base = switch (role) {
      'admin' => <Widget>[
          const DashboardStub(),
          const ClassesScreen(),
          const DecksScreen(),
          const UsersScreen(),
          const NoteTypesScreen(provider: null),
          const BrowserScreen(),
        ],
      'teacher' => <Widget>[
          const DashboardStub(),
          const ClassesScreen(),
          const DecksScreen(),
          const NoteTypesScreen(provider: null),
          const BrowserScreen(),
        ],
      'student' => <Widget>[
          const DashboardStub(),
          const DecksScreen(),
          const ClassesScreen(),
          const BrowserScreen(),
        ],
      _ => <Widget>[
          const DashboardStub(),
        ],
    };
    return [...base, const _MeScreen()];
  }
}

class _MeScreen extends StatelessWidget {
  const _MeScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = auth.user;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Me'),
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
          const Divider(),
          GestureDetector(
            onTap: () => auth.logout(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.logOut, size: 20, color: Colors.red),
                  const SizedBox(width: 16),
                  const Text('Sign out', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final int key;
  final IconData icon;
  final String label;

  const _NavItem(this.key, this.icon, this.label);
}
