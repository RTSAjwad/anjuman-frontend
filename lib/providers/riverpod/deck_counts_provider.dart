import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/deck.dart';
import '../../services/deck_service.dart';
import 'api_client_provider.dart';

/// Lightweight, fresh per-deck card counts for the deck list.
///
/// Returns a `Map<int, DeckCounts>` keyed by deck id. Re-fetched whenever a
/// card mutation invalidates it (see `CardStore`).
///
/// NOTE: per the backend contract, teachers/admins receive only `total_count`
/// (per-state counts are student-only). The UI should treat per-state counts
/// as `0` when absent.
final deckCountsProvider = FutureProvider<Map<int, DeckCounts>>((ref) async {
  final service = DeckService(ref.read(apiClientProvider));
  final list = await service.fetchDeckCounts();
  return {for (final c in list) c.deckId: c};
});
