import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/card_record.dart';
import '../../models/common.dart';
import '../../models/study.dart';
import '../../services/card_service.dart';
import '../../services/study_service.dart';
import 'api_client_provider.dart';
import 'card_store_provider.dart' as card_store;

/// Immutable study session state.
///
/// Holds only the primitive/session fields. Derived values that depend on BOTH
/// this state and the card store (`currentCard`, `newCount`, `learningCount`,
/// `dueCount`) are exposed as getters on [StudyNotifier] instead.
class StudyState {
  final List<int> dueCardIds;
  final int currentIndex;
  final bool showBack;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final bool isComplete;
  final String? deckTitle;
  final int? deckId;
  final StudySteps? steps;

  const StudyState({
    this.dueCardIds = const [],
    this.currentIndex = 0,
    this.showBack = false,
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.isComplete = false,
    this.deckTitle,
    this.deckId,
    this.steps,
  });

  int get totalCount => dueCardIds.length;
  int get reviewedCount => currentIndex;

  StudyState copyWith({
    List<int>? dueCardIds,
    int? currentIndex,
    bool? showBack,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool? isComplete,
    String? deckTitle,
    int? deckId,
    StudySteps? steps,
    bool clearError = false,
  }) {
    return StudyState(
      dueCardIds: dueCardIds ?? this.dueCardIds,
      currentIndex: currentIndex ?? this.currentIndex,
      showBack: showBack ?? this.showBack,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      isComplete: isComplete ?? this.isComplete,
      deckTitle: deckTitle ?? this.deckTitle,
      deckId: deckId ?? this.deckId,
      steps: steps ?? this.steps,
    );
  }
}

/// Riverpod drop-in replacement for the legacy `StudyProvider`.
class StudyNotifier extends Notifier<StudyState> {
  late final StudyService _studyService;
  late final CardService _cardService;

  /// Incremented each time a new fetch loop starts.
  int _loopGeneration = 0;

  Completer<bool>? _ratingCompleter;

  @override
  StudyState build() {
    final apiClient = ref.read(apiClientProvider);
    _studyService = StudyService(apiClient);
    _cardService = CardService(apiClient);

    ref.onDispose(_cancelLoop);
    return const StudyState();
  }

  card_store.CardStore get _store =>
      ref.read(card_store.cardStoreProvider.notifier);

  CardRecord? get currentCard {
    final s = state;
    return s.currentIndex < s.dueCardIds.length
        ? _store.card(s.dueCardIds[s.currentIndex])
        : null;
  }

  int get newCount => _store.deckNewCount(state.deckId ?? -1);
  int get learningCount => _store.deckLearningCount(state.deckId ?? -1);
  int get dueCount => _store.deckDueCount(state.deckId ?? -1);

  void _fetchLoop() async {
    final gen = ++_loopGeneration;
    try {
      while (true) {
        if (gen != _loopGeneration) return;

        // Fetch the current study queue
        state = state.copyWith(isLoading: true, clearError: true);

        StudySession session;
        try {
          session = await _studyService.getDeckStudy(state.deckId!);
        } on Exception catch (e) {
          state = state.copyWith(error: e.toString(), isLoading: false);
          return;
        }

        if (gen != _loopGeneration) return;

        state = state.copyWith(
          deckTitle: session.deckTitle ?? 'Study',
          steps: session.steps,
          isLoading: false,
        );

        // Upsert full CardRecords so the store is the single source of truth
        // and other screens (browser) reflect authoritative card state.
        _store.upsertCards(session.cards.map(_toRecord));

        // Build the due queue: cards with due_at <= now (new cards are always
        // due). Read back ordered card ids from the store.
        final now = DateTime.now();
        final dueCardIds = session.cards
            .where((c) {
              if (c.dueAt == null) return true;
              final due = parseTimestamp(c.dueAt);
              return !due.isAfter(now);
            })
            .map((c) => c.cardId)
            .toList();

        // No due cards available — the study session is complete. The backend
        // returns every card in the deck (including future-dated interday
        // learning cards), so this is the real terminal condition; a card may
        // become due again on a later fetch.
        if (dueCardIds.isEmpty) {
          state = state.copyWith(isComplete: true);
          return;
        }

        state = state.copyWith(dueCardIds: dueCardIds);

        // Review each card in this batch
        for (var i = 0; i < dueCardIds.length; i++) {
          if (gen != _loopGeneration) return;
          state = state.copyWith(currentIndex: i, showBack: false);

          final rated = await _waitForRating();
          _ratingCompleter = null;
          if (gen != _loopGeneration) return;
          if (!rated) return;
        }
      }
    } finally {
      if (gen == _loopGeneration) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> _waitForRating() async {
    _ratingCompleter = Completer<bool>();
    return _ratingCompleter!.future;
  }

  void flipCard() {
    state = state.copyWith(showBack: !state.showBack);
  }

  Future<void> setCardFlag(int cardId, int flag) async {
    try {
      await _studyService.setCardFlag(cardId, flag);
      _store.setCardFlag(cardId, flag);
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Performs a card/note scheduling action and advances past the current card
  /// within the study loop, since the affected card(s) are no longer due.
  ///
  /// Card-level responses (with `suspended`/`buried_until`/`due_at`/`state`)
  /// are applied to the shared [CardStore]; note-level responses (with
  /// `card_ids`) update each affected card.
  Future<void> _applyCardAction(
      Future<Map<String, dynamic>> Function() action) async {
    final card = currentCard;
    if (card == null) return;

    state = state.copyWith(isSubmitting: true);
    try {
      final response = await action();
      final cardIds = (response['card_ids'] as List? ?? []).cast<int>();
      if (cardIds.isNotEmpty) {
        // Note-level action
        for (final id in cardIds) {
          _store.applyCardMod(
            id,
            suspended: response['suspended'] as int?,
            buriedUntil: response['buried_until'] as int?,
            hasBuriedUntil: response.containsKey('buried_until'),
          );
        }
      } else {
        // Card-level action
        _store.applyCardMod(
          card.cardId,
          suspended: response['suspended'] as int?,
          buriedUntil: response['buried_until'] as int?,
          hasBuriedUntil: response.containsKey('buried_until'),
          dueAt: response['due_at'] as int?,
          state: response['state'] as String?,
        );
      }
      state = state.copyWith(isSubmitting: false, showBack: false);
      _ratingCompleter?.complete(true);
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString(), isSubmitting: false);
    }
  }

  Future<void> suspendCard() => _applyCardAction(
      () async => _cardService.suspendCard(currentCard!.cardId));

  Future<void> buryCard() =>
      _applyCardAction(() async => _cardService.buryCard(currentCard!.cardId));

  Future<void> suspendNote() => _applyCardAction(
      () async => _cardService.suspendNote(currentCard!.noteId));

  Future<void> buryNote() =>
      _applyCardAction(() async => _cardService.buryNote(currentCard!.noteId));

  Future<void> rescheduleCard(int days) =>
      _applyCardAction(() async => _cardService.rescheduleCard(
            cardId: currentCard!.cardId,
            days: days,
          ));

  Future<void> submitRating(int rating) async {
    if (currentCard == null) return;

    state = state.copyWith(isSubmitting: true);

    try {
      final response = await _studyService.submitReview(SubmitReview(
        cardId: currentCard!.cardId,
        rating: rating,
      ));
      _store.applyCardMod(
        currentCard!.cardId,
        state: response.state,
        dueAt: response.dueAt,
      );

      state = state.copyWith(isSubmitting: false);
      _ratingCompleter?.complete(true);
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString(), isSubmitting: false);
      _ratingCompleter?.complete(false);
    }
  }

  void startDeckStudy(int deckId) {
    _cancelLoop();
    _fullReset();
    state = state.copyWith(deckId: deckId);
    _fetchLoop();
  }

  void reset() {
    _cancelLoop();
    _fullReset();
  }

  void _cancelLoop() {
    _loopGeneration++;
    if (_ratingCompleter != null && !_ratingCompleter!.isCompleted) {
      _ratingCompleter!.complete(false);
    }
    _ratingCompleter = null;
  }

  void _fullReset() {
    state = const StudyState();
  }

  CardRecord _toRecord(StudyCard c) => CardRecord(
        cardId: c.cardId,
        noteId: c.noteId ?? 0,
        deckId: state.deckId ?? 0,
        deckTitle: c.deckTitle,
        front: c.front,
        back: c.back,
        noteTypeName: '',
        fields: const {},
        templateIndex: 0,
        state: c.state,
        dueAt: c.dueAt,
        flag: c.flag,
        suspended: _store.isSuspended(c.cardId),
        buriedUntil: _store.buriedUntil(c.cardId),
        newCardPosition: null,
        stability: c.stability,
        difficulty: c.difficulty,
        reps: c.reps,
        lapses: c.lapses,
        predictedInterval: c.predictedInterval,
        stepIndex: c.stepIndex,
      );
}

/// The shared study session provider.
final studyProvider = NotifierProvider<StudyNotifier, StudyState>(
  StudyNotifier.new,
);
