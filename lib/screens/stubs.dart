import 'package:flutter/material.dart';

// Stub screens — placeholders that will be replaced with real implementations

class DashboardStub extends StatelessWidget {
  const DashboardStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      theme: Theme.of(context).colorScheme.primaryContainer,
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
      theme: Theme.of(context).colorScheme.secondaryContainer,
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
      theme: Theme.of(context).colorScheme.tertiaryContainer,
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
      theme: Theme.of(context).colorScheme.errorContainer,
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
      theme: Theme.of(context).colorScheme.surfaceContainerHighest,
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
      theme: Theme.of(context).colorScheme.secondaryContainer,
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
      theme: Theme.of(context).colorScheme.tertiaryContainer,
    );
  }
}

class _StubPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color theme;

  const _StubPage({
    required this.title,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
