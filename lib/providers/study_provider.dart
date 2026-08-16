import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/common.dart';
import '../models/study.dart';
import '../services/api_client.dart';
import '../services/study_service.dart';
import '../widgets/safe_notify.dart';
import 'card_state_provider.dart';

class StudyProvider extends ChangeNotifier with SafeNotify {
  final ApiClient _apiClient;
  late CardStateProvider _cardState;
  late final StudyService _studyService;

  StudyProvider(this._apiClient, this._cardState) {
    _studyService = StudyService(_apiClient);
  }

  set cardState(CardStateProvider value) => _cardState = value;

  List<StudyCard> _cards = [];
  int _currentIndex = 0;
  bool _showBack = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  bool _isComplete = false;

  // Metadata
  String? _deckTitle;
  int? _deckId;
  StudySteps? _steps;

  List<StudyCard> get cards => _cards;
  int get currentIndex => _currentIndex;
  bool get showBack => _showBack;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  bool get isComplete => _isComplete;

  StudyCard? get currentCard =>
      _currentIndex < _cards.length ? _cards[_currentIndex] : null;

  String? get deckTitle => _deckTitle;
  int? get deckId => _deckId;
  StudySteps? get steps => _steps;
  int get totalCount => _cards.length;
  int get reviewedCount => _currentIndex;

  /// Counts are delegated to CardStateProvider.
  int get newCount => _cardState.deckNewCount(_deckId ?? -1);
  int get learningCount => _cardState.deckLearningCount(_deckId ?? -1);
  int get dueCount => _cardState.deckDueCount(_deckId ?? -1);

  /// Incremented each time a new fetch loop starts.
  int _loopGeneration = 0;

  void _fetchLoop() async {
    final gen = ++_loopGeneration;
    try {
      while (true) {
        if (gen != _loopGeneration) return;

        // Fetch the current study queue
        _isLoading = true;
        _error = null;
        notifyListeners();

        StudySession session;
        try {
          session = await _studyService.getDeckStudy(_deckId!);
        } on Exception catch (e) {
          _error = e.toString();
          _isLoading = false;
          safeNotify();
          return;
        }

        if (gen != _loopGeneration) return;

        _deckTitle = session.deckTitle ?? 'Study';
        _steps = session.steps;
        _isLoading = false;

        // Filter out cards that aren't actually due yet.
        // New cards (new state) are always due. For review/learning/
        // relearning cards, only include those with due_at <= now.
        final now = DateTime.now();
        final dueCards = session.cards.where((c) {
          if (c.dueAt == null) return true;
          final due = parseTimestamp(c.dueAt);
          return !due.isAfter(now);
        }).toList();
        _cards = dueCards;

        // Seed card state in the shared provider so counts stay up-to-date
        _cardState.seedFromStudyCards(
          _deckId!,
          session.cards.map((c) => (cardId: c.cardId, state: c.state)),
        );

        // No due cards available — the study session is complete. The backend
        // returns every card in the deck (including future-dated interday
        // learning cards), so this is the real terminal condition; a card may
        // become due again on a later fetch.
        if (_cards.isEmpty) {
          _isComplete = true;
          safeNotify();
          return;
        }

        safeNotify();

        // Review each card in this batch
        for (var i = 0; i < _cards.length; i++) {
          if (gen != _loopGeneration) return;
          _currentIndex = i;
          _showBack = false;
          safeNotify();

          final rated = await _waitForRating();
          _ratingCompleter = null;
          if (gen != _loopGeneration) return;
          if (!rated) return;
        }
      }
    } finally {
      if (gen == _loopGeneration) {
        _isLoading = false;
      }
    }
  }

  Completer<bool>? _ratingCompleter;

  Future<bool> _waitForRating() async {
    _ratingCompleter = Completer<bool>();
    return _ratingCompleter!.future;
  }

  void flipCard() {
    _showBack = !_showBack;
    notifyListeners();
  }

  Future<void> setCardFlag(int cardId, int flag) async {
    try {
      await _studyService.setCardFlag(cardId, flag);
      _cardState.setCardFlag(cardId, flag);
      final idx = _cards.indexWhere((c) => c.cardId == cardId);
      if (idx >= 0) {
        _cards[idx] = _cards[idx].copyWith(flag: flag);
      }
      notifyListeners();
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> submitRating(int rating) async {
    if (currentCard == null) return;

    _isSubmitting = true;
    notifyListeners();

    try {
      final response = await _studyService.submitReview(SubmitReview(
        cardId: currentCard!.cardId,
        rating: rating,
      ));
      _cardState.setCardState(currentCard!.cardId, _deckId!, response.state);

      // Update the card in _cards so counts reflect the new state
      final idx = _cards.indexWhere((c) => c.cardId == currentCard!.cardId);
      if (idx >= 0) {
        _cards[idx] = _cards[idx].copyWith(state: response.state);
      }

      _isSubmitting = false;
      safeNotify();
      _ratingCompleter?.complete(true);
    } on Exception catch (e) {
      _error = e.toString();
      _isSubmitting = false;
      safeNotify();
      _ratingCompleter?.complete(false);
    }
  }

  void startDeckStudy(int deckId) {
    _cancelLoop();
    _fullReset();
    _deckId = deckId;
    _fetchLoop();
  }

  void reset() {
    _cancelLoop();
    _fullReset();
    notifyListeners();
  }

  void _cancelLoop() {
    _loopGeneration++;
    if (_ratingCompleter != null && !_ratingCompleter!.isCompleted) {
      _ratingCompleter!.complete(false);
    }
    _ratingCompleter = null;
  }

  void _fullReset() {
    _cards = [];
    _currentIndex = 0;
    _showBack = false;
    _isLoading = false;
    _isSubmitting = false;
    _error = null;
    _isComplete = false;
    _deckTitle = null;
    _deckId = null;
    _steps = null;
  }

  @override
  void dispose() {
    _cancelLoop();
    super.dispose();
  }
}
