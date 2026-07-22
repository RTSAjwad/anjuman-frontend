import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../models/study.dart';

class StudyScreen extends StatefulWidget {
  final int deckId;
  final StudyProvider? provider;

  const StudyScreen({super.key, required this.deckId, this.provider});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late StudyProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? context.read<StudyProvider>();
    _provider.addListener(_onProviderChanged);
    _provider.startDeckStudy(widget.deckId);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = _provider.deckTitle ?? 'Study';

    Widget body;
    if (_provider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_provider.error != null) {
      body = _errorView(context, _provider);
    } else if (_provider.isComplete) {
      body = _completedView(context, _provider);
    } else if (_provider.cards.isEmpty) {
      body = _emptyView(context, _provider);
    } else {
      body = _cardView(context, _provider);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: _provider.isLoading || _provider.totalCount == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: _CardCountBar(provider: _provider),
                ),
              ),
      ),
      body: body,
    );
  }

  Widget _errorView(BuildContext context, StudyProvider provider) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load cards', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(provider.error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _provider.startDeckStudy(widget.deckId),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView(BuildContext context, StudyProvider provider) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text('All caught up!',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('No cards due right now.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: () => _provider.startDeckStudy(widget.deckId),
                child: const Text('Check again'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to decks'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completedView(BuildContext context, StudyProvider provider) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('No cards due',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Come back later for more reviews.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _cardView(BuildContext context, StudyProvider provider) {
    final theme = Theme.of(context);
    final card = _provider.currentCard!;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        _provider.showBack ? card.back : card.front,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!provider.showBack && !provider.isSubmitting)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: FilledButton.icon(
                onPressed: () => _provider.flipCard(),
                icon: const Icon(Icons.touch_app),
                label: const Text('Show Answer'),
              ),
            ),
          if (provider.showBack && !provider.isSubmitting)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RatingButton(
                      label: 'Again',
                      sublabel: _intervalLabel(
                          _provider.currentCard, '1', 'Re-study'),
                      rating: 1,
                      color: Colors.red.shade600,
                      onPressed: _submitRating,
                    ),
                    const SizedBox(width: 8),
                    _RatingButton(
                      label: 'Hard',
                      sublabel: _intervalLabel(
                          _provider.currentCard, '2', '~1-2 days'),
                      rating: 2,
                      color: Colors.orange.shade600,
                      onPressed: _submitRating,
                    ),
                    const SizedBox(width: 8),
                    _RatingButton(
                      label: 'Good',
                      sublabel:
                          _intervalLabel(_provider.currentCard, '3', 'Growing'),
                      rating: 3,
                      color: Colors.green.shade600,
                      onPressed: _submitRating,
                    ),
                    const SizedBox(width: 8),
                    _RatingButton(
                      label: 'Easy',
                      sublabel:
                          _intervalLabel(provider.currentCard, '4', 'Long'),
                      rating: 4,
                      color: Colors.blue.shade600,
                      onPressed: _submitRating,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _submitRating(int rating) {
    _provider.submitRating(rating);
  }

  String _intervalLabel(StudyCard? card, String rating, String fallback) {
    final interval = card?.predictedInterval?[rating];
    if (interval == null) return fallback;
    if (interval == 0) return 'Today';
    if (interval == 1) return '1 day';
    return '$interval days';
  }
}

class _CardCountBar extends StatelessWidget {
  final StudyProvider provider;

  const _CardCountBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (provider.newCount > 0)
            _StatChip(
              icon: Icons.fiber_new,
              label: '${provider.newCount} new',
              color: Colors.blue.shade600,
            ),
          if (provider.learningCount > 0 || provider.relearningCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _StatChip(
                icon: Icons.school,
                label:
                    '${provider.learningCount + provider.relearningCount} learning',
                color: Colors.orange.shade600,
              ),
            ),
          if (provider.dueCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _StatChip(
                icon: Icons.schedule,
                label: '${provider.dueCount} due',
                color: Colors.green.shade600,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final int rating;
  final Color color;
  final void Function(int) onPressed;

  const _RatingButton({
    required this.label,
    required this.sublabel,
    required this.rating,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 72,
        child: Material(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onPressed(rating),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      )),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: TextStyle(
                        color: color.withAlpha(180),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
