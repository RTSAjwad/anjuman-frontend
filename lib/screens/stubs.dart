import 'package:shadcn_flutter/shadcn_flutter.dart';

// Stub screens — placeholders that will be replaced with real implementations

class DashboardStub extends StatelessWidget {
  const DashboardStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
    );
  }
}

class ClassesStub extends StatelessWidget {
  const ClassesStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'Classes',
      icon: Icons.group_rounded,
    );
  }
}

class DecksStub extends StatelessWidget {
  const DecksStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'Decks',
      icon: Icons.style_rounded,
    );
  }
}

class AssignmentsStub extends StatelessWidget {
  const AssignmentsStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'Assignments',
      icon: Icons.assignment_rounded,
    );
  }
}

class UsersStub extends StatelessWidget {
  const UsersStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'Users',
      icon: Icons.people_rounded,
    );
  }
}

class StudyStub extends StatelessWidget {
  const StudyStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'Study',
      icon: Icons.psychology_rounded,
    );
  }
}

class MyStatsStub extends StatelessWidget {
  const MyStatsStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'My Stats',
      icon: Icons.bar_chart_rounded,
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
        AppBar(
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
