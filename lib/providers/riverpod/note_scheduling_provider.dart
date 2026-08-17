import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_record.dart';
import 'card_store_provider.dart';
import 'note_store_provider.dart';

/// Derived, immutable snapshot of a note's scheduling state.
///
/// Not stored on [NoteRecord] — recomputed from the note's cards so it can't
/// drift from card state.
class NoteScheduling {
  final int noteId;
  final bool suspended;
  final int? buriedUntil;

  const NoteScheduling({
    required this.noteId,
    required this.suspended,
    required this.buriedUntil,
  });

  bool get isBuried => buriedUntil != null;
}

/// Derives note scheduling flags from cards, keeping notes the single source of
/// truth without storing a duplicate `suspended`/`buriedUntil` copy on
/// [NoteRecord].
///
/// A note is:
/// - suspended only when *all* its cards are suspended,
/// - buried only when *all* its cards are buried (using the first card's
///   timestamp as the representative value).
///
/// Watchers rebuild automatically when either store changes.
final noteSchedulingProvider = Provider<Map<int, NoteScheduling>>((ref) {
  final cards = ref.watch(cardStoreProvider);
  final notes = ref.watch(noteStoreProvider);

  final result = <int, NoteScheduling>{};
  for (final note in notes.values) {
    final ids = note.cardIds;
    final cardRecords =
        ids.map((id) => cards[id]).whereType<CardRecord>().toList();

    // Incomplete card set → no definitive scheduling state for this note.
    if (cardRecords.length != ids.length) continue;

    final allSuspended = cardRecords.every((c) => c.suspended);
    final allBuried = cardRecords.every((c) => c.isBuried);
    result[note.noteId] = NoteScheduling(
      noteId: note.noteId,
      suspended: allSuspended,
      buriedUntil: allBuried ? cardRecords.first.buriedUntil : null,
    );
  }
  return result;
});
