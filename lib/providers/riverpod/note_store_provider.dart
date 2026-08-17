import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/note_record.dart';

/// Riverpod single source of truth for notes.
///
/// State is an immutable `Map<int, NoteRecord>` (noteId → full record).
///
/// Note *scheduling* flags (suspended/buried) are intentionally **not** stored
/// here — they are derived from card state in `note_scheduling_provider.dart`.
/// Keeping them derived avoids duplicating state and the need to keep two
/// stores in sync.
class NoteStore extends Notifier<Map<int, NoteRecord>> {
  @override
  Map<int, NoteRecord> build() => {};

  NoteRecord? note(int noteId) => state[noteId];

  List<NoteRecord> get allNotes => state.values.toList();

  void upsertNote(NoteRecord note) {
    state = {...state, note.noteId: note};
  }

  void upsertNotes(Iterable<NoteRecord> notes) {
    state = {...state, for (final n in notes) n.noteId: n};
  }

  void removeNote(int noteId) {
    state = {...state}..remove(noteId);
  }

  void clear() => state = {};
}

/// The shared note store provider.
final noteStoreProvider =
    NotifierProvider<NoteStore, Map<int, NoteRecord>>(NoteStore.new);
