class BrowserCard {
  final int cardId;
  final int noteId;
  final int deckId;
  final String deckTitle;
  final int templateIndex;
  final String front;
  final String back;
  final String noteTypeName;
  final Map<String, dynamic> fields;
  final String? state;
  final int? dueAt;
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final DateTime createdAt;
  final int? newCardPosition;

  BrowserCard({
    required this.cardId,
    required this.noteId,
    required this.deckId,
    required this.deckTitle,
    required this.templateIndex,
    required this.front,
    required this.back,
    required this.noteTypeName,
    required this.fields,
    this.state,
    this.dueAt,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    required this.createdAt,
    this.newCardPosition,
  });

  factory BrowserCard.fromJson(Map<String, dynamic> json) => BrowserCard(
        cardId: json['card_id'],
        noteId: json['note_id'],
        deckId: json['deck_id'],
        deckTitle: json['deck_title'],
        templateIndex: json['template_index'],
        front: json['front'],
        back: json['back'],
        noteTypeName: json['note_type_name'],
        fields: json['fields'],
        state: json['state'],
        dueAt: json['due_at'],
        stability: (json['stability'] as num).toDouble(),
        difficulty: (json['difficulty'] as num).toDouble(),
        reps: json['reps'],
        lapses: json['lapses'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['created_at'] is String
                    ? int.parse(json['created_at'])
                    : json['created_at']) *
                1000),
        newCardPosition: json['new_card_position'],
      );
}

class BrowserCardsResponse {
  final List<BrowserCard> cards;
  final int page;
  final int perPage;
  final int total;

  BrowserCardsResponse({
    required this.cards,
    required this.page,
    required this.perPage,
    required this.total,
  });

  factory BrowserCardsResponse.fromJson(Map<String, dynamic> json) =>
      BrowserCardsResponse(
        cards: (json['cards'] as List)
            .map((c) => BrowserCard.fromJson(c))
            .toList(),
        page: json['page'],
        perPage: json['per_page'],
        total: json['total'],
      );
}
