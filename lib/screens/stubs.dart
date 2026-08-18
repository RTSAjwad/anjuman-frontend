import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../widgets/narrow_app_bar.dart';

// Stub screens — placeholders that will be replaced with real implementations

class DashboardStub extends StatelessWidget {
  const DashboardStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubPage(
      title: 'Dashboard',
      icon: LucideIcons.layoutDashboard,
    );
  }
}

class ClassesStub extends StatelessWidget {
  const ClassesStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubPage(
      title: 'Classes',
      icon: LucideIcons.users,
    );
  }
}

class DecksStub extends StatelessWidget {
  const DecksStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubPage(
      title: 'Decks',
      icon: LucideIcons.layers,
    );
  }
}

class AssignmentsStub extends StatelessWidget {
  const AssignmentsStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubPage(
      title: 'Assignments',
      icon: LucideIcons.clipboardList,
    );
  }
}

class UsersStub extends StatelessWidget {
  const UsersStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubPage(
      title: 'Users',
      icon: LucideIcons.users,
    );
  }
}

class StudyStub extends StatelessWidget {
  const StudyStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubPage(
      title: 'Study',
      icon: LucideIcons.brain,
    );
  }
}

class MyStatsStub extends StatelessWidget {
  const MyStatsStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubPage(
      title: 'My Stats',
      icon: LucideIcons.chartBar,
    );
  }
}

class _StubPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _StubPage({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        NarrowAppBar(
          title: Text(title),
        ),
      ],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.mutedForeground),
            const SizedBox(height: 16),
            Text(title).semiBold(),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(
                color: colors.mutedForeground,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
