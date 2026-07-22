import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'classes_screen.dart';
import 'decks_screen.dart';
import 'users_screen.dart';
import 'browser_screen.dart';
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

    // Clamp index if role changed
    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          if (isWide) {
            return _buildWideLayout(navItems, screens);
          } else {
            return _buildNarrowLayout(navItems, screens);
          }
        },
      ),
    );
  }

  Widget _buildWideLayout(
    List<_NavItem> navItems,
    List<Widget> screens,
  ) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          labelType: NavigationRailLabelType.all,
          destinations: navItems
              .map((item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon, fill: 1),
                    label: Text(item.label),
                  ))
              .toList(),
        ),
        const VerticalDivider(width: 1),
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
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: navItems
              .map((item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon, fill: 1),
                    label: item.label,
                  ))
              .toList(),
        ),
      ],
    );
  }

  List<_NavItem> _navItemsForRole(String role) {
    final base = switch (role) {
      'admin' => const [
          _NavItem(Icons.dashboard_rounded, 'Dashboard'),
          _NavItem(Icons.group_rounded, 'Classes'),
          _NavItem(Icons.style_rounded, 'Decks'),
          _NavItem(Icons.people_rounded, 'Users'),
          _NavItem(Icons.search_rounded, 'Browser'),
        ],
      'teacher' => const [
          _NavItem(Icons.dashboard_rounded, 'Dashboard'),
          _NavItem(Icons.group_rounded, 'Classes'),
          _NavItem(Icons.style_rounded, 'Decks'),
          _NavItem(Icons.search_rounded, 'Browser'),
        ],
      'student' => const [
          _NavItem(Icons.dashboard_rounded, 'Dashboard'),
          _NavItem(Icons.style_rounded, 'Decks'),
          _NavItem(Icons.group_rounded, 'Classes'),
          _NavItem(Icons.search_rounded, 'Browser'),
        ],
      _ => const [
          _NavItem(Icons.home_rounded, 'Home'),
        ],
    };
    return [...base, const _NavItem(Icons.person_rounded, 'Me')];
  }

  List<Widget> _screensForRole(String role) {
    final base = switch (role) {
      'admin' => <Widget>[
          const DashboardStub(),
          const ClassesScreen(),
          const DecksScreen(),
          const UsersScreen(),
          const BrowserScreen(),
        ],
      'teacher' => <Widget>[
          const DashboardStub(),
          const ClassesScreen(),
          const DecksScreen(),
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
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    (user?.email ?? '?')[0].toUpperCase(),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
                  style: theme.textTheme.titleMedium,
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)),
            onTap: () => auth.logout(),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}
