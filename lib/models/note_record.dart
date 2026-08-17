/// Authoritative record of a note, held in [NoteStore].
///
/// Notes are deck-agnostic here: each note's cards carry their own `deck_id`
/// on [CardRecord]. This record links a note to its generated card ids.
class NoteRecord {
  final int noteId;
  final int noteTypeId;
  final String noteTypeName;
  final Map<String, dynamic> fields;
  final List<int> cardIds;

  /// True when every card in the note is suspended.
  final bool suspended;

  /// Non-null when every card in the note is buried (the shared timestamp).
  final int? buriedUntil;

  bool get isBuried => buriedUntil != null;

  const NoteRecord({
    required this.noteId,
    required this.noteTypeId,
    required this.noteTypeName,
    required this.fields,
    required this.cardIds,
    this.suspended = false,
    this.buriedUntil,
  });

  NoteRecord copyWith({
    int? noteTypeId,
    String? noteTypeName,
    Map<String, dynamic>? fields,
    List<int>? cardIds,
    bool? suspended,
    int? buriedUntil,
  }) {
    return NoteRecord(
      noteId: noteId,
      noteTypeId: noteTypeId ?? this.noteTypeId,
      noteTypeName: noteTypeName ?? this.noteTypeName,
      fields: fields ?? this.fields,
      cardIds: cardIds ?? this.cardIds,
      suspended: suspended ?? this.suspended,
      buriedUntil: buriedUntil ?? this.buriedUntil,
    );
  }
}
