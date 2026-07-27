import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _provider.startDeckStudy(widget.deckId);
      }
    });
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
    final colors = Theme.of(context).colorScheme;

    Widget body;
    if (_provider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_provider.error != null) {
      body = _errorView(context, _provider, colors);
    } else if (_provider.isComplete) {
      body = _completedView(context, _provider, colors);
    } else if (_provider.cards.isEmpty) {
      body = _emptyView(context, _provider, colors);
    } else {
      body = _cardView(context, _provider, colors);
    }

    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton.ghost(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(title),
          subtitle: _provider.isLoading || _provider.totalCount == 0
              ? null
              : _CardCountBar(provider: _provider),
        ),
      ],
      child: body,
    );
  }

  Widget _errorView(
      BuildContext context, StudyProvider provider, ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.destructive),
            const SizedBox(height: 16),
            const Text('Failed to load cards'),
            const SizedBox(height: 8),
            Text(
              provider.error ?? '',
              style: TextStyle(color: colors.mutedForeground, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Button.secondary(
              onPressed: () => _provider.startDeckStudy(widget.deckId),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView(
      BuildContext context, StudyProvider provider, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 64, color: Color(0xFF22C55E)),
          const SizedBox(height: 16),
          const Text('All caught up!').semiBold(),
          const SizedBox(height: 8),
          Text(
            'No cards due right now.',
            style: TextStyle(color: colors.mutedForeground),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button.secondary(
                onPressed: () => _provider.startDeckStudy(widget.deckId),
                child: const Text('Check again'),
              ),
              const SizedBox(width: 12),
              Button.outline(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to decks'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completedView(
      BuildContext context, StudyProvider provider, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 64, color: colors.primary),
          const SizedBox(height: 16),
          const Text('No cards due').semiBold(),
          const SizedBox(height: 8),
          Text(
            'Come back later for more reviews.',
            style: TextStyle(color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _cardView(
      BuildContext context, StudyProvider provider, ColorScheme colors) {
    final card = _provider.currentCard!;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Html(
                  data: _provider.showBack ? card.back : card.front,
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                    ),
                  },
                ),
              ),
            ),
          ),
          if (!provider.showBack && !provider.isSubmitting)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Button.primary(
                leading: const Icon(Icons.touch_app, size: 18),
                onPressed: () => _provider.flipCard(),
                child: const Text('Show Answer'),
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
                    Expanded(
                      child: Button(
                        onPressed: () => _submitRating(1),
                        style: const ButtonStyle.primary()
                            .withBackgroundColor(
                                color: Color(0xFFDC2626),
                                hoverColor: Color(0xFFB91C1C))
                            .withForegroundColor(color: Colors.black),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Again',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _intervalLabel(
                                  _provider.currentCard, '1', 'Re-study'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button(
                        onPressed: () => _submitRating(2),
                        style: const ButtonStyle.primary()
                            .withBackgroundColor(
                                color: Color(0xFFEA580C),
                                hoverColor: Color(0xFFC2410C))
                            .withForegroundColor(color: Colors.black),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Hard',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _intervalLabel(
                                  _provider.currentCard, '2', '~1-2 days'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button(
                        onPressed: () => _submitRating(3),
                        style: const ButtonStyle.primary()
                            .withBackgroundColor(
                                color: Color(0xFF16A34A),
                                hoverColor: Color(0xFF15803D))
                            .withForegroundColor(color: Colors.black),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Good',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _intervalLabel(
                                  _provider.currentCard, '3', 'Growing'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button(
                        onPressed: () => _submitRating(4),
                        style: const ButtonStyle.primary()
                            .withBackgroundColor(
                                color: Color(0xFF2563EB),
                                hoverColor: Color(0xFF1D4ED8))
                            .withForegroundColor(color: Colors.black),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Easy',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _intervalLabel(
                                  _provider.currentCard, '4', 'Long'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
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
    final hasNew = provider.newCount > 0;
    final hasLearning =
        provider.learningCount > 0 || provider.relearningCount > 0;
    final hasDue = provider.dueCount > 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (hasNew)
            _StatChip(
              icon: Icons.fiber_new,
              label: '${provider.newCount} new',
              color: const Color(0xFF3B82F6),
            ),
          if (hasLearning)
            Padding(
              padding: EdgeInsets.only(left: hasNew ? 12 : 0),
              child: _StatChip(
                icon: Icons.school,
                label:
                    '${provider.learningCount + provider.relearningCount} learning',
                color: const Color(0xFFF97316),
              ),
            ),
          if (hasDue)
            Padding(
              padding: EdgeInsets.only(left: hasNew || hasLearning ? 12 : 0),
              child: _StatChip(
                icon: Icons.schedule,
                label: '${provider.dueCount} due',
                color: const Color(0xFF22C55E),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

enum DeckSortField { title, newCount, learning, due, cards }
