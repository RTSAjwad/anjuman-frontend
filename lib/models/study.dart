class StudyCard {
  final int cardId;
  final String front;
  final String back;
  final String state;
  final int? dueAt;
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final String deckTitle;
  final Map<String, int>? predictedInterval;
  final int? flag;

  StudyCard({
    required this.cardId,
    required this.front,
    required this.back,
    required this.state,
    this.dueAt,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    required this.deckTitle,
    this.predictedInterval,
    this.flag,
  });

  factory StudyCard.fromJson(Map<String, dynamic> json) => StudyCard(
        cardId: json['card_id'],
        front: json['front'],
        back: json['back'],
        state: json['state'],
        dueAt: json['due_at'],
        stability: (json['stability'] as num).toDouble(),
        difficulty: (json['difficulty'] as num).toDouble(),
        reps: json['reps'],
        lapses: json['lapses'],
        deckTitle: json['deck_title'],
        predictedInterval: json['predicted_interval'] != null
            ? (json['predicted_interval'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, (v as num).toInt()))
            : null,
        flag: json['flag'],
      );

  StudyCard copyWith({String? state, int? flag}) {
    return StudyCard(
      cardId: cardId,
      front: front,
      back: back,
      state: state ?? this.state,
      dueAt: dueAt,
      stability: stability,
      difficulty: difficulty,
      reps: reps,
      lapses: lapses,
      deckTitle: deckTitle,
      predictedInterval: predictedInterval,
      flag: flag ?? this.flag,
    );
  }
}

class StudySession {
  final int? deckId;
  final String? deckTitle;
  final List<StudyCard> cards;
  final int totalCards;
  final int reviewedCount;

  StudySession({
    this.deckId,
    this.deckTitle,
    required this.cards,
    required this.totalCards,
    required this.reviewedCount,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        deckId: json['deck_id'],
        deckTitle: json['deck_title'],
        cards:
            (json['cards'] as List).map((c) => StudyCard.fromJson(c)).toList(),
        totalCards: json['total_cards'],
        reviewedCount: json['reviewed_count'],
      );
}

// Reviews

class SubmitReview {
  final int cardId;
  final int rating;
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

class ReviewResponse {
  final int cardId;
  final String state;
  final int? dueAt;
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final int intervalDays;

  ReviewResponse({
    required this.cardId,
    required this.state,
    this.dueAt,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    required this.intervalDays,
  });

  factory ReviewResponse.fromJson(Map<String, dynamic> json) => ReviewResponse(
        cardId: json['card_id'],
        state: json['state'],
        dueAt: json['due_at'],
        stability: (json['stability'] as num).toDouble(),
        difficulty: (json['difficulty'] as num).toDouble(),
        reps: json['reps'],
        lapses: json['lapses'],
        intervalDays: json['interval_days'],
      );
}
