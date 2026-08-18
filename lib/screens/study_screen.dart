import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/riverpod/study_provider.dart';
import '../models/card_record.dart';
import '../models/study.dart';
import '../widgets/card_html_view.dart';
import '../widgets/responsive_dialog.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final int deckId;
  final VoidCallback? onClose;
  final VoidCallback? onFullscreen;
  final bool isFullscreen;

  const StudyScreen({
    super.key,
    required this.deckId,
    this.onClose,
    this.onFullscreen,
    this.isFullscreen = false,
  });

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  final _menuKey = GlobalKey();

  static const _flagColors = {
    1: Color(0xFFE53935),
    2: Color(0xFFF57C00),
    3: Color(0xFF43A047),
    4: Color(0xFF1E88E5),
    5: Color(0xFFD81B60),
    6: Color(0xFF00BCD4),
    7: Color(0xFF8E24AA),
  };

  static const _flagLabels = {
    1: 'Red',
    2: 'Orange',
    3: 'Green',
    4: 'Blue',
    5: 'Pink',
    6: 'Turquoise',
    7: 'Purple',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(studyProvider.notifier).startDeckStudy(widget.deckId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyProvider);
    final notifier = ref.read(studyProvider.notifier);
    final title = state.deckTitle ?? 'Study';
    final colors = Theme.of(context).colorScheme;

    Widget body;
    if (state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null) {
      body = _errorView(context, state, colors);
    } else if (state.isComplete) {
      body = _completedView(context, state, colors);
    } else if (state.dueCardIds.isEmpty) {
      body = _emptyView(context, state, colors);
    } else {
      body = _cardView(context, state, colors);
    }

    return Scaffold(
      headers: [
        AppBar(
          leading: [
            if (widget.isFullscreen)
              IconButton.outline(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                onPressed: () => widget.onClose?.call(),
              ),
          ],
          title: Text(title),
          trailing: [
            if (notifier.currentCard != null &&
                !state.isLoading &&
                !state.isComplete)
              _buildFlagMenu(context),
            if (!widget.isFullscreen && widget.onFullscreen != null)
              IconButton.outline(
                icon: const Icon(LucideIcons.externalLink, size: 20),
                onPressed: () => widget.onFullscreen?.call(),
              ),
            if (!widget.isFullscreen && widget.onClose != null)
              IconButton.outline(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => widget.onClose?.call(),
              ),
          ],
          subtitle: (!state.isLoading && state.totalCount > 0)
              ? _CardCountBar(
                  newCount: notifier.newCount,
                  learningCount: notifier.learningCount,
                  dueCount: notifier.dueCount,
                )
              : null,
        ),
      ],
      child: body,
    );
  }

  Widget _errorView(
      BuildContext context, StudyState state, ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, size: 48, color: colors.destructive),
            const SizedBox(height: 16),
            const Text('Failed to load cards'),
            const SizedBox(height: 8),
            Text(
              state.error ?? '',
              style: TextStyle(color: colors.mutedForeground, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Button.secondary(
              onPressed: () => ref
                  .read(studyProvider.notifier)
                  .startDeckStudy(widget.deckId),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView(
      BuildContext context, StudyState state, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.circleCheck,
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
                onPressed: () => ref
                    .read(studyProvider.notifier)
                    .startDeckStudy(widget.deckId),
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
      BuildContext context, StudyState state, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.trophy, size: 64, color: colors.primary),
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

  Widget _cardView(BuildContext context, StudyState state, ColorScheme colors) {
    final card = ref.read(studyProvider.notifier).currentCard!;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: CardHtmlView(
              html: state.showBack ? card.back : card.front,
            ),
          ),
          if (!state.showBack && !state.isSubmitting)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Button.primary(
                leading: const Icon(LucideIcons.hand, size: 18),
                onPressed: () => ref.read(studyProvider.notifier).flipCard(),
                child: const Text('Show Answer'),
              ),
            ),
          if (state.showBack && !state.isSubmitting)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Button.outline(
                        onPressed: () => _submitRating(1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Again',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _ratingLabel(card, state.steps, 1),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button.outline(
                        onPressed: () => _submitRating(2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Hard',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _ratingLabel(card, state.steps, 2),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button.outline(
                        onPressed: () => _submitRating(3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Good',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _ratingLabel(card, state.steps, 3),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button.outline(
                        onPressed: () => _submitRating(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Easy',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              _ratingLabel(card, state.steps, 4),
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
    ref.read(studyProvider.notifier).submitRating(rating);
  }

  Future<void> _setFlag(int flag) async {
    final card = ref.read(studyProvider.notifier).currentCard;
    if (card == null) return;
    await ref.read(studyProvider.notifier).setCardFlag(card.cardId, flag);
  }

  Widget _buildFlagMenu(BuildContext context) {
    final currentFlag = ref.read(studyProvider.notifier).currentCard?.flag;

    final List<MenuItem> flagItems = [];
    for (final entry in _flagColors.entries) {
      flagItems.add(
        MenuButton(
          leading: Icon(
            LucideIcons.flag,
            size: 16,
            color: entry.value,
          ),
          trailing: currentFlag == entry.key
              ? const Icon(LucideIcons.check, size: 16)
              : null,
          onPressed: (_) {
            _setFlag(entry.key);
          },
          child: Text(_flagLabels[entry.key]!),
        ),
      );
    }
    if (currentFlag != null && currentFlag > 0) {
      flagItems.add(const MenuDivider());
      flagItems.add(
        MenuButton(
          leading: const Icon(LucideIcons.flagOff, size: 16),
          onPressed: (_) {
            _setFlag(0);
          },
          child: const Text('Clear flag'),
        ),
      );
    }

    return Builder(
      builder: (builderContext) {
        return IconButton.outline(
          key: _menuKey,
          icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
          onPressed: () {
            showDropdown(
              context: builderContext,
              builder: (context) {
                return DropdownMenu(
                  children: [
                    MenuButton(
                      leading: Icon(
                        LucideIcons.flag,
                        size: 16,
                        color: currentFlag != null && currentFlag > 0
                            ? _flagColors[currentFlag]
                            : null,
                      ),
                      subMenu: flagItems,
                      child: const Text('Set Flag'),
                    ),
                    const MenuDivider(),
                    MenuButton(
                      leading: const Icon(LucideIcons.calendarOff, size: 16),
                      onPressed: (_) {
                        ref.read(studyProvider.notifier).buryCard();
                      },
                      child: const Text('Bury card'),
                    ),
                    MenuButton(
                      leading: const Icon(LucideIcons.ban, size: 16),
                      onPressed: (_) {
                        ref.read(studyProvider.notifier).suspendCard();
                      },
                      child: const Text('Suspend card'),
                    ),
                    MenuButton(
                      leading: const Icon(LucideIcons.calendar, size: 16),
                      onPressed: (_) {
                        _showRescheduleDialog(builderContext);
                      },
                      child: const Text('Reschedule card'),
                    ),
                    if (ref.read(studyProvider.notifier).currentCard?.noteId !=
                        null) ...[
                      const MenuDivider(),
                      MenuButton(
                        leading: const Icon(LucideIcons.calendarOff, size: 16),
                        onPressed: (_) {
                          ref.read(studyProvider.notifier).buryNote();
                        },
                        child: const Text('Bury note'),
                      ),
                      MenuButton(
                        leading: const Icon(LucideIcons.ban, size: 16),
                        onPressed: (_) {
                          ref.read(studyProvider.notifier).suspendNote();
                        },
                        child: const Text('Suspend note'),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRescheduleDialog(BuildContext context) {
    final controller = TextEditingController();
    showResponsiveDialog(
      context,
      builder: (ctx, _) => AlertDialog(
        title: const Text('Reschedule card'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Days from now', style: TextStyle(fontSize: 13))
                  .semiBold(),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                placeholder: const Text('e.g. 3'),
                initialValue: '',
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          Button.ghost(
            onPressed: () => closeOverlay(ctx),
            child: const Text('Cancel'),
          ),
          Button.primary(
            onPressed: () {
              final days = int.tryParse(controller.text.trim());
              if (days == null) return;
              closeOverlay(ctx);
              ref.read(studyProvider.notifier).rescheduleCard(days);
            },
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );
  }

  /// Renders the interval sub-label for a rating button, matching Anki.
  ///
  /// For new/learning/relearning cards the short step intervals come from the
  /// deck's [steps]; for review (and graduated) buttons the FSRS interval in
  /// [card.predictedInterval] is used.
  String _ratingLabel(CardRecord card, StudySteps? steps, int rating) {
    final predicted = card.predictedInterval;
    final state = card.state;

    String formatIntervalDays(int? days, String fallback) {
      if (days == null) return fallback;
      if (days == 0) return 'Today';
      if (days == 1) return '1 day';
      return '$days days';
    }

    // FSRS review interval (days) for a rating key.
    String fsrs(String ratingKey, String fallback) =>
        formatIntervalDays(predicted?[ratingKey], fallback);

    // Returns the step duration at [index], or falls back to the FSRS interval
    // (graduate) when the index is beyond the end of the list.
    String stepOrGraduate(
        List<int> stepsList, int index, String ratingKey, String fallback) {
      if (steps == null || stepsList.isEmpty) {
        return fsrs(ratingKey, fallback);
      }
      if (index < stepsList.length) {
        return _formatSeconds(stepsList[index]);
      }
      return fsrs(ratingKey, fallback);
    }

    // Helper for Again/Hard/Good that advances one step from the current
    // step_index. Advancing past the last step graduates to review.
    String nextStep(List<int> stepsList, String ratingKey, String fallback) {
      final nextIndex = card.stepIndex + 1;
      return stepOrGraduate(stepsList, nextIndex, ratingKey, fallback);
    }

    final learning = steps?.learningSteps ?? const <int>[];
    final relearning = steps?.relearningSteps ?? const <int>[];

    switch (state) {
      case 'new':
      case 'learning':
        switch (rating) {
          case 1: // Again -> first learning step
            return stepOrGraduate(learning, 0, '1', 'Re-study');
          case 2: // Hard -> next learning step (or graduate)
            return nextStep(learning, '2', '~1-2 days');
          case 3: // Good -> next learning step (or graduate)
            return nextStep(learning, '3', 'Growing');
          case 4: // Easy -> graduate to review
            return fsrs('4', 'Long');
        }
        break;
      case 'relearning':
        switch (rating) {
          case 1: // Again -> first relearning step
            return stepOrGraduate(relearning, 0, '1', 'Re-study');
          case 2: // Hard -> next relearning step (or review)
            return nextStep(relearning, '2', '~1-2 days');
          case 3: // Good -> next relearning step (or review)
            return nextStep(relearning, '3', 'Growing');
          case 4: // Easy -> FSRS review
            return fsrs('4', 'Long');
        }
        break;
      case 'review':
      default:
        switch (rating) {
          case 1: // Again -> lapse into relearning first step
            return stepOrGraduate(relearning, 0, '1', 'Re-study');
          case 2:
            return fsrs('2', '~1-2 days');
          case 3:
            return fsrs('3', 'Growing');
          case 4:
            return fsrs('4', 'Long');
        }
        break;
    }
    return '';
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    if (hours < 24) {
      return remMinutes == 0 ? '${hours}h' : '${hours}h ${remMinutes}m';
    }
    final days = hours ~/ 24;
    final remHours = hours % 24;
    if (remHours == 0) return '${days}d';
    return '${days}d ${remHours}h';
  }
}

class _CardCountBar extends StatelessWidget {
  final int newCount;
  final int learningCount;
  final int dueCount;

  const _CardCountBar({
    required this.newCount,
    required this.learningCount,
    required this.dueCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasNew = newCount > 0;
    final hasLearning = learningCount > 0;
    final hasDue = dueCount > 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (hasNew)
            OutlineBadge(
              leading: const Icon(LucideIcons.sparkles, size: 12),
              child: Text('$newCount new'),
            ),
          if (hasLearning)
            Padding(
              padding: EdgeInsets.only(left: hasNew ? 8 : 0),
              child: OutlineBadge(
                leading: const Icon(LucideIcons.graduationCap, size: 12),
                child: Text('$learningCount learning'),
              ),
            ),
          if (hasDue)
            Padding(
              padding: EdgeInsets.only(left: hasNew || hasLearning ? 8 : 0),
              child: OutlineBadge(
                leading: const Icon(LucideIcons.clock, size: 12),
                child: Text('$dueCount due'),
              ),
            ),
        ],
      ),
    );
  }
}

enum DeckSortField { title, newCount, learning, due, cards }
