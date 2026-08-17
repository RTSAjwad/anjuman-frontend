import 'package:flutter/foundation.dart';
import '../models/note_record.dart';
import '../widgets/safe_notify.dart';

/// Single source of truth for notes.
///
/// Parallel to [CardStore] for cards. Notes are deck-agnostic here; a note's
/// cards carry their own deck, so "notes in a deck" is derived by joining card
/// deck ids (done at the provider level).
class NoteStore extends ChangeNotifier with SafeNotify {
  final Map<int, NoteRecord> _notes = {};

  NoteRecord? note(int noteId) => _notes[noteId];

  List<NoteRecord> get allNotes => _notes.values.toList();

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

  void clear() {
    _notes.clear();
    notifyListeners();
  }
}
