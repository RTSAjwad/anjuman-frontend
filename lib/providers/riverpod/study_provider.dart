import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study.dart';
import '../../services/card_service.dart';
import '../../services/study_service.dart';
import 'api_client_provider.dart';
import 'card_store_provider.dart' as card_store;
import 'deck_counts_provider.dart';

/// Immutable single-card study state.
///
/// This flow holds exactly one current card (or none) plus authoritative
/// counts. There is no queue, session id, or "complete" flag: `currentCard ==
/// null` means nothing is due *right now*.
class StudyState {
  final StudyCard? currentCard;
  final StudyCounts counts;
  final bool isLoading;
  final bool isSubmitting;
  final bool showBack;
  final String? error;
  final String? deckTitle;
  final int? deckId;

  const StudyState({
    this.currentCard,
    this.counts = const StudyCounts(),
    this.isLoading = false,
    this.isSubmitting = false,
    this.showBack = false,
    this.error,
    this.deckTitle,
    this.deckId,
  });

  StudyState copyWith({
    StudyCard? currentCard,
    StudyCounts? counts,
    bool? isLoading,
    bool? isSubmitting,
    bool? showBack,
    String? error,
    String? deckTitle,
    int? deckId,
    bool clearError = false,
    bool clearCurrentCard = false,
  }) {
    return StudyState(
      currentCard: clearCurrentCard ? null : (currentCard ?? this.currentCard),
      counts: counts ?? this.counts,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      showBack: showBack ?? this.showBack,
      error: clearError ? null : (error ?? this.error),
      deckTitle: deckTitle ?? this.deckTitle,
      deckId: deckId ?? this.deckId,
    );
  }
}

/// Riverpod single-card study notifier.
class StudyNotifier extends Notifier<StudyState> {
  late final StudyService _studyService;
  late final CardService _cardService;

  @override
  StudyState build() {
    final apiClient = ref.read(apiClientProvider);
    _studyService = StudyService(apiClient);
    _cardService = CardService(apiClient);
    return const StudyState();
  }

  card_store.CardStore get _store =>
      ref.read(card_store.cardStoreProvider.notifier);

  StudyCard? get currentCard => state.currentCard;

  Future<void> startDeckStudy(int deckId) async {
    state = state.copyWith(
      deckId: deckId,
      isLoading: true,
      clearError: true,
    );

    try {
      final response = await _studyService.startStudy(deckId);
      state = state.copyWith(
        currentCard: response.nextCard,
        clearCurrentCard: response.nextCard == null,
        counts: response.counts,
        deckTitle: response.deckTitle,
        deckId: response.deckId ?? deckId,
        isLoading: false,
        showBack: false,
      );
      ref.invalidate(deckCountsProvider);
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> submitRating(int rating) async {
    final card = state.currentCard;
    final deckId = state.deckId;
    if (card == null || deckId == null) return;

    state = state.copyWith(isSubmitting: true);

    try {
      final response = await _studyService.submitReview(
        deckId,
        SubmitReview(cardId: card.cardId, rating: rating),
      );

      // Update the shared card store with the post-review scheduling state.
      // `reviewed_card` lacks `suspended`/`buried_until`, so only `state` and
      // `due_at` are updated here.
      final reviewed = response.reviewedCard;
      if (reviewed != null) {
        _store.applyCardMod(
          reviewed.cardId,
          state: reviewed.state,
          dueAt: reviewed.dueAt,
        );
      }

      state = state.copyWith(
        currentCard: response.nextCard,
        clearCurrentCard: response.nextCard == null,
        counts: response.counts,
        deckTitle: response.deckTitle,
        deckId: response.deckId ?? deckId,
        isSubmitting: false,
        showBack: false,
        clearError: true,
      );
      ref.invalidate(deckCountsProvider);
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString(), isSubmitting: false);
    }
  }

  void flipCard() {
    state = state.copyWith(showBack: !state.showBack);
  }

  Future<void> setCardFlag(int cardId, int flag) async {
    try {
      await _studyService.setCardFlag(cardId, flag);
      _store.setCardFlag(cardId, flag);
      state = state.copyWith(
        currentCard: state.currentCard == null
            ? null
            : _withFlag(state.currentCard!, flag),
      );
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  StudyCard _withFlag(StudyCard card, int flag) => StudyCard(
        cardId: card.cardId,
        noteId: card.noteId,
        front: card.front,
        back: card.back,
        state: card.state,
        dueAt: card.dueAt,
        stability: card.stability,
        difficulty: card.difficulty,
        reps: card.reps,
        lapses: card.lapses,
        flag: flag,
        suspended: card.suspended,
        buriedUntil: card.buriedUntil,
        stepIndex: card.stepIndex,
        predictedInterval: card.predictedInterval,
      );

  /// Applies a card/note scheduling action, then refetches the next card.
  ///
  /// The affected card(s) are no longer due, so we re-fetch via the GET start
  /// endpoint to obtain the next card and fresh counts. Card-level responses
  /// (with `suspended`/`buried_until`/`due_at`/`state`) are applied to the
  /// shared [CardStore]; note-level responses (with `card_ids`) update each
  /// affected card.
  Future<void> _applyCardAction(
      Future<Map<String, dynamic>> Function() action) async {
    final card = state.currentCard;
    final deckId = state.deckId;
    if (card == null || deckId == null) return;

    state = state.copyWith(isSubmitting: true);
    try {
      final response = await action();
      final cardIds = (response['card_ids'] as List? ?? []).cast<int>();
      if (cardIds.isNotEmpty) {
        for (final id in cardIds) {
          _store.applyCardMod(
            id,
            suspended: response['suspended'] as int?,
            buriedUntil: response['buried_until'] as int?,
            hasBuriedUntil: response.containsKey('buried_until'),
          );
        }
      } else {
        _store.applyCardMod(
          card.cardId,
          suspended: response['suspended'] as int?,
          buriedUntil: response['buried_until'] as int?,
          hasBuriedUntil: response.containsKey('buried_until'),
          dueAt: response['due_at'] as int?,
          state: response['state'] as String?,
        );
      }
      state = state.copyWith(isSubmitting: false);
      await startDeckStudy(deckId);
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString(), isSubmitting: false);
    }
  }

  Future<void> suspendCard() => _applyCardAction(
      () async => _cardService.suspendCard(currentCard!.cardId));

  Future<void> buryCard() =>
      _applyCardAction(() async => _cardService.buryCard(currentCard!.cardId));

  Future<void> suspendNote() async {
    final noteId = currentCard?.noteId;
    if (noteId == null) return;
    await _applyCardAction(() async => _cardService.suspendNote(noteId));
  }

  Future<void> buryNote() async {
    final noteId = currentCard?.noteId;
    if (noteId == null) return;
    await _applyCardAction(() async => _cardService.buryNote(noteId));
  }

  Future<void> rescheduleCard(int days) =>
      _applyCardAction(() async => _cardService.rescheduleCard(
            cardId: currentCard!.cardId,
            days: days,
          ));

  void reset() {
    state = const StudyState();
  }
}

/// The shared single-card study provider.
final studyProvider = NotifierProvider<StudyNotifier, StudyState>(
  StudyNotifier.new,
);
