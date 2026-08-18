/// Full card projection returned by the study endpoints.
///
/// Appears as `next_card`. Unlike `reviewed_card`, it carries the HTML
/// `front`/`back` content needed to render the card.
class StudyCard {
  final int cardId;
  final int? noteId;
  final String front;
  final String back;
  final String state; // new | learning | review | relearning
  final int? dueAt; // Unix seconds
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final int? flag;
  final int suspended; // 0 | 1
  final int? buriedUntil; // Unix seconds, null = not buried
  final int stepIndex;
  final Map<String, int>? predictedInterval; // rating key -> interval seconds

  StudyCard({
    required this.cardId,
    this.noteId,
    required this.front,
    required this.back,
    required this.state,
    this.dueAt,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    this.flag,
    this.suspended = 0,
    this.buriedUntil,
    this.stepIndex = 0,
    this.predictedInterval,
  });

  factory StudyCard.fromJson(Map<String, dynamic> json) => StudyCard(
        cardId: json['card_id'],
        noteId: json['note_id'] as int?,
        front: json['front'] as String? ?? '',
        back: json['back'] as String? ?? '',
        state: json['state'] as String? ?? '',
        dueAt: json['due_at'] as int?,
        stability: (json['stability'] as num? ?? 0).toDouble(),
        difficulty: (json['difficulty'] as num? ?? 0).toDouble(),
        reps: json['reps'] as int? ?? 0,
        lapses: json['lapses'] as int? ?? 0,
        flag: json['flag'] as int?,
        suspended: json['suspended'] as int? ?? 0,
        buriedUntil: json['buried_until'] as int?,
        stepIndex: json['step_index'] as int? ?? 0,
        predictedInterval: json['predicted_interval'] != null
            ? (json['predicted_interval'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, (v as num).toInt()))
            : null,
      );
}

/// Post-review card state returned as `reviewed_card` on advance. Carries no
/// `front`/`back` — the current card's content is retained in [StudyState].
class ReviewedCard {
  final int cardId;
  final String state;
  final int? dueAt;
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final int stepIndex;
  final int appliedIntervalSecs;

  ReviewedCard({
    required this.cardId,
    required this.state,
    this.dueAt,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    this.stepIndex = 0,
    this.appliedIntervalSecs = 0,
  });

  factory ReviewedCard.fromJson(Map<String, dynamic> json) => ReviewedCard(
        cardId: json['card_id'],
        state: json['state'] as String? ?? '',
        dueAt: json['due_at'] as int?,
        stability: (json['stability'] as num? ?? 0).toDouble(),
        difficulty: (json['difficulty'] as num? ?? 0).toDouble(),
        reps: json['reps'] as int? ?? 0,
        lapses: json['lapses'] as int? ?? 0,
        stepIndex: json['step_index'] as int? ?? 0,
        appliedIntervalSecs: json['applied_interval_secs'] as int? ?? 0,
      );
}

/// Authoritative, limit-aware per-state card counts for a deck.
class StudyCounts {
  final int newCount;
  final int learningCount;
  final int reviewCount;
  final int relearningCount;

  const StudyCounts({
    this.newCount = 0,
    this.learningCount = 0,
    this.reviewCount = 0,
    this.relearningCount = 0,
  });

  int get learningTotal => learningCount + relearningCount;

  factory StudyCounts.fromJson(Map<String, dynamic> json) => StudyCounts(
        newCount: json['new_count'] as int? ?? 0,
        learningCount: json['learning_count'] as int? ?? 0,
        reviewCount: json['review_count'] as int? ?? 0,
        relearningCount: json['relearning_count'] as int? ?? 0,
      );
}

/// Response from both `GET /decks/{id}/study` and `POST /decks/{id}/study`.
///
/// `done` is transient: `nextCard == null` simply means nothing is due right
/// now, not that the deck is permanently finished.
class StudyResponse {
  final StudyCard? nextCard;
  final ReviewedCard? reviewedCard;
  final StudyCounts counts;
  final int? deckId;
  final String? deckTitle;

  const StudyResponse({
    this.nextCard,
    this.reviewedCard,
    required this.counts,
    this.deckId,
    this.deckTitle,
  });

  bool get done => nextCard == null;

  factory StudyResponse.fromJson(Map<String, dynamic> json) => StudyResponse(
        nextCard: json['next_card'] != null
            ? StudyCard.fromJson(json['next_card'] as Map<String, dynamic>)
            : null,
        reviewedCard: json['reviewed_card'] != null
            ? ReviewedCard.fromJson(
                json['reviewed_card'] as Map<String, dynamic>)
            : null,
        counts: StudyCounts.fromJson(
            json['counts'] as Map<String, dynamic>? ?? const {}),
        deckId: json['deck_id'] as int?,
        deckTitle: json['deck_title'] as String?,
      );
}

/// Body for advancing the study flow by submitting a rating.
class SubmitReview {
  final int cardId;
  final int rating; // 1-4
  final int? responseTimeMs;

  SubmitReview({
    required this.cardId,
    required this.rating,
    this.responseTimeMs,
  });

  Map<String, dynamic> toJson() => {
        'card_id': cardId,
        'rating': rating,
        if (responseTimeMs != null) 'response_time_ms': responseTimeMs,
      };
}
