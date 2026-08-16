/// Authoritative record of a note, held in the store.
class NoteRecord {
  final int noteId;
  final int deckId;
  final int noteTypeId;
  final String noteTypeName;
  final Map<String, dynamic> fields;
  final List<int> cardIds;

  const NoteRecord({
    required this.noteId,
    required this.deckId,
    required this.noteTypeId,
    required this.noteTypeName,
    required this.fields,
    required this.cardIds,
  });

  NoteRecord copyWith({
    int? deckId,
    int? noteTypeId,
    String? noteTypeName,
    Map<String, dynamic>? fields,
    List<int>? cardIds,
  }) {
    return NoteRecord(
      noteId: noteId,
      deckId: deckId ?? this.deckId,
      noteTypeId: noteTypeId ?? this.noteTypeId,
      noteTypeName: noteTypeName ?? this.noteTypeName,
      fields: fields ?? this.fields,
      cardIds: cardIds ?? this.cardIds,
    );
  }
}
