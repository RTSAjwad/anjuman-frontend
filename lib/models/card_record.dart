/// Authoritative record of a card, held in [CardStore].
///
/// This is the superset of the study, browse, and action response projections.
/// It is immutable; [CardStore] replaces instances via [copyWith] on update.
class CardRecord {
  final int cardId;
  final int noteId;
  final int deckId;

  // Denormalized display content
  final String deckTitle;
  final String front;
  final String back;
  final String noteTypeName;
  final Map<String, dynamic> fields;
  final int templateIndex;

  // Mutable scheduling state
  final String? state; // new / learning / review / relearning
  final int? dueAt; // Unix seconds
  final int? flag; // 0-7, 0 = none
  final bool suspended;
  final int? buriedUntil; // Unix seconds, null = not buried
  final int? newCardPosition;

  // FSRS learning stats (read-only from the UI; refreshed by the store)
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;

  const CardRecord({
    required this.cardId,
    required this.noteId,
    required this.deckId,
    required this.deckTitle,
    required this.front,
    required this.back,
    required this.noteTypeName,
    required this.fields,
    required this.templateIndex,
    this.state,
    this.dueAt,
    this.flag,
    this.suspended = false,
    this.buriedUntil,
    this.newCardPosition,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
  });

  CardRecord copyWith({
    String? noteTypeName,
    String? front,
    String? back,
    String? deckTitle,
    int? noteId,
    int? deckId,
    Map<String, dynamic>? fields,
    int? templateIndex,
    String? state,
    int? dueAt,
    int? flag,
    bool? suspended,
    int? buriedUntil,
    int? newCardPosition,
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
  }) {
    return CardRecord(
      cardId: cardId,
      noteId: noteId ?? this.noteId,
      deckId: deckId ?? this.deckId,
      deckTitle: deckTitle ?? this.deckTitle,
      front: front ?? this.front,
      back: back ?? this.back,
      noteTypeName: noteTypeName ?? this.noteTypeName,
      fields: fields ?? this.fields,
      templateIndex: templateIndex ?? this.templateIndex,
      state: state ?? this.state,
      dueAt: dueAt ?? this.dueAt,
      flag: flag ?? this.flag,
      suspended: suspended ?? this.suspended,
      buriedUntil: buriedUntil ?? this.buriedUntil,
      newCardPosition: newCardPosition ?? this.newCardPosition,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
    );
  }
}
