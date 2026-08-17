import 'package:flutter/foundation.dart';
import '../models/card_record.dart';
import '../models/note_record.dart';
import '../widgets/safe_notify.dart';
import 'card_store.dart';

/// Single source of truth for notes.
///
/// Parallel to [CardStore] for cards. Notes are deck-agnostic here; a note's
/// cards carry their own deck, so "notes in a deck" is derived by joining card
/// deck ids (done at the provider level).
class NoteStore extends ChangeNotifier with SafeNotify {
  final Map<int, NoteRecord> _notes = {};

  NoteRecord? note(int noteId) => _notes[noteId];

  List<NoteRecord> get allNotes => _notes.values.toList();

  bool isNoteSuspended(int noteId) => _notes[noteId]?.suspended ?? false;

  bool isNoteBuried(int noteId) => _notes[noteId]?.isBuried ?? false;

  void upsertNote(NoteRecord note) {
    _notes[note.noteId] = note;
    notifyListeners();
  }

  void upsertNotes(Iterable<NoteRecord> notes) {
    for (final n in notes) {
      _notes[n.noteId] = n;
    }
    notifyListeners();
  }

  void removeNote(int noteId) {
    _notes.remove(noteId);
    notifyListeners();
  }

  /// Recomputes a note's suspended/buried flags from its cards.
  ///
  /// A note is suspended only when *all* its cards are suspended, and buried
  /// only when *all* its cards are buried (using the first card's timestamp as
  /// the representative value). Cards are looked up in [cards].
  void recomputeNoteState(int noteId, CardStore cards) {
    final note = _notes[noteId];
    if (note == null) return;
    final ids = note.cardIds;
    if (ids.isEmpty) {
      _notes[noteId] = NoteRecord(
        noteId: note.noteId,
        noteTypeId: note.noteTypeId,
        noteTypeName: note.noteTypeName,
        fields: note.fields,
        cardIds: note.cardIds,
        suspended: false,
        buriedUntil: null,
      );
      notifyListeners();
      return;
    }

    final cardRecords =
        ids.map((id) => cards.card(id)).whereType<CardRecord>().toList();
    // Only consider cards we actually hold; if we don't know every card's
    // state yet, don't mark the note as conclusively suspended/buried.
    if (cardRecords.length != ids.length) {
      return;
    }

    final allSuspended = cardRecords.every((c) => c.suspended);
    final allBuried = cardRecords.every((c) => c.isBuried);
    final buriedUntil = allBuried ? cardRecords.first.buriedUntil : null;
    // Build a fresh record so `buriedUntil` can be cleared to null.
    _notes[noteId] = NoteRecord(
      noteId: note.noteId,
      noteTypeId: note.noteTypeId,
      noteTypeName: note.noteTypeName,
      fields: note.fields,
      cardIds: note.cardIds,
      suspended: allSuspended,
      buriedUntil: buriedUntil,
    );
    notifyListeners();
  }

  void clear() {
    _notes.clear();
    notifyListeners();
  }
}
