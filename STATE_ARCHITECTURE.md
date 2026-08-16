# Phase 2 — Single Source of Truth for Cards & Notes

> Status: **Design / proposal** — not yet implemented.
>
> This document describes how to refactor state management so that any card or
> note mutated from one screen is reflected, immediately and correctly, in
> every other screen.

---

## 1. Problem statement

Today state is spread across multiple `ChangeNotifier` providers, each owning
its **own projection** of the same underlying backend entities and re-fetching
independently:

| Provider | Owns | Source endpoints |
|---|---|---|
| `CardStateProvider` | per-card `state`, `flag`, `suspended`, `buriedUntil` | (seeded by others) |
| `StudyProvider` | `List<StudyCard>` + study session metadata | `/decks/{id}/study`, `/reviews`, `/cards/{id}/...` |
| `BrowserProvider` | paginated `List<BrowserCard>` | `/cards` |
| `DeckProvider` | `List<DeckResponse>`, `List<NoteType>`, (notes as transient return values) | deck/note/note-type endpoints |
| `ClassProvider` | classes + rosters | class endpoints |
| `UserProvider` | users | user endpoints |
| `AuthProvider` | session/user | auth |

**Result:** there is no authoritative record of a card or note. Each provider
holds a *copy*, and the copies drift apart.

Concrete symptom: rescheduling a card in the **Study** screen changes `due_at`
server-side, but the **Browser** screen's `Due` column still shows the old
value because:

1. `CardStateProvider` does not track `dueAt` (only `state`/`flag`/`suspended`/`buriedUntil`).
2. The browser table reads `dueAt` from `BrowserCard`, a snapshot owned by
   `BrowserProvider`, which is only refreshed by a `/cards` re-fetch.

---

## 2. Goal

Introduce a single, normalized **entity store** that is the authoritative
source of truth for **cards** and **notes** (and, if desired, decks). Every
mutation flows *through* the store; every screen *reads* the store. Mutating
anywhere updates everywhere.

**Non-goals (for now):**
- Do not re-architect auth, users, classes, or dashboard analytics — those are
  unrelated and already reasonably self-contained.
- Do not necessarily remove pagination/filtering — the store becomes the
  backing data source, but browse/study still present *queries* over it.

---

## 3. Target architecture

### 3.1 The store

A single `CardStore` (evolved from `CardStateProvider`) owns normalized maps:

```
CardStore extends ChangeNotifier
 ├── Map<int, Card>  _cards   // cardId → full card entity
 ├── Map<int, Note>  _notes   // noteId → full note entity
 └── (optional) Map<int, Deck> _decks
```

#### Card entity (full record)

Everything needed to render any screen's card view, denormalized so no
screen needs a second fetch:

```dart
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
  final String? state;          // new / learning / review / relearning
  final int? dueAt;
  final int? flag;
  final bool suspended;
  final int? buriedUntil;       // Unix seconds, null = not buried
  final int? newCardPosition;

  // FSRS learning stats
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;

  DateTime get dueDateTime => /* parseTimestamp(dueAt) */;
}
```

> `CardRecord` must be an **immutable value object** with `copyWith`. The store
> replaces instances on update such that `==`/`identical` notify listeners
> correctly.

#### Note entity (full record)

```dart
class NoteRecord {
  final int noteId;
  final int deckId;
  final int noteTypeId;
  final String noteTypeName;
  final Map<String, dynamic> fields;
  final List<int> cardIds;      // cards generated from this note
}
```

---

### 3.2 Store API

Reads (synchronous, no side effects):

```dart
CardRecord? card(int cardId);
NoteRecord? note(int noteId);
List<CardRecord> cardsByDeck(int deckId);
List<CardRecord> cardsByNote(int noteId);
List<CardRecord> dueCards({DateTime? now});   // mirrors study's due filter
```

Mutations (each writes to maps, then `notifyListeners()`):

```dart
void upsertCard(CardRecord card);            // insert or replace
void upsertCards(Iterable<CardRecord> cards);
void removeCard(int cardId);

void upsertNote(NoteRecord note);
void removeNote(int noteId);

// Convenience mutations (thin, used by action handlers after API calls):
void setCardState(int cardId, String state);
void setCardDueAt(int cardId, int? dueAt);
void setCardFlag(int cardId, int flag);
void setCardScheduling(int cardId, {bool suspended, int? buriedUntil});
```

---

### 3.3 Providers become thin service gateways

`StudyProvider`, `BrowserProvider`, and `DeckProvider` stop owning entity lists.
They keep a reference to the **shared `CardStore`** and the relevant service,
and after each API call **upsert** results into the store.

```dart
class BrowserProvider extends ChangeNotifier {
  final CardStore _store;
  final BrowserService _service;

  // Pagination/filter/sort metadata can remain here (it's a *view* concern,
  // not entity data), but the backing list reads through the store.

  Future<void> loadCards() async {
    final page = await _service.browseCards(...);
    _store.upsertCards(page.cards.map((c) => c.toRecord()));
    // keep _page / _total for pagination UI
    notifyListeners();
  }

  Future<void> rescheduleCard(int id, int days) async {
    final res = await _service.rescheduleCard(id, days: days);
    final existing = _store.card(id);
    _store.setCardDueAt(id, res['due_at'] as int?);
  }
}
```

`StudyProvider` similarly upserts `StudyCard` → `CardRecord` after study
fetches and review submissions.

---

### 3.4 Screens read the store

Screens use `context.watch<CardStore>()` / `Consumer<CardStore>` instead of
reading entity lists off `BrowserProvider`/`StudyProvider`.

```dart
// Browser "Due" cell — no snapshot, live from store
Consumer<CardStore>(
  builder: (context, store, _) {
    final card = store.card(cardId)!;
    return Text(card.dueAt != null ? formatDate(card.dueAt!) : '—');
  },
);
```

Because mutation calls `notifyListeners()` on `CardStore`, any open screen that
watches the store repaints automatically.

---

## 4. Migration plan

### Phase 2a — Normalize the store (the important win)

1. Rename/extend `CardStateProvider` → `CardStore`.
2. Introduce `CardRecord` and `NoteRecord` models.
3. Move **all mutable card scheduling fields** into the store: `state`, `dueAt`,
   `flag`, `suspended`, `buriedUntil`, `newCardPosition`, plus FSRS stats.
4. Keep `StudyProvider`/`BrowserProvider`/`DeckProvider` for now, but have them
   **upsert** into `CardStore` after every load and action.
5. Switch the browser **"State" / "Due" / "Flag"** columns and the study card
   view to read from `CardStore`.

**Delivers:** reschedule/suspend/bury/flag/state changes propagate everywhere —
the actual bug — with contained churn.

### Phase 2b — Collapse lists into the store

6. Remove `List<StudyCard>`/`List<BrowserCard>` from their providers; queries go
   through `CardStore`.
7. `DeckProvider` note methods upsert `NoteRecord`s instead of returning
   transient `NoteResponse`s.
8. Add store query methods for browse filtering/sorting/pagination and study due
   selection (or keep thin view models over the store).

### Phase 2c — (optional) Pull decks/note-types into the store

9. Move deck + note-type lists into `CardStore` (or a sibling `ReferenceStore`)
   so deck renames/note-type edits also propagate everywhere without re-fetch.

---

## 5. Provider wiring

Use `ChangeNotifierProxyProvider` so the dependent providers always hold the
same `CardStore` instance created once:

```dart
ChangeNotifierProvider<CardStore>(create: (_) => CardStore()),
ChangeNotifierProxyProvider<CardStore, StudyProvider>(
  create: (_) => StudyProvider(apiClient, CardStore()),
  update: (_, store, study) => study!..store = store,
),
ChangeNotifierProxyProvider<CardStore, BrowserProvider>(
  create: (_) => BrowserProvider(apiClient, CardStore()),
  update: (_, store, browser) => browser!..store = store,
),
ChangeNotifierProxyProvider<CardStore, DeckProvider>(
  create: (_) => DeckProvider(apiClient, CardStore()),
  update: (_, store, deck) => deck!..store = store,
),
```

`CardStore` becomes the source of truth; the others delegate writes to it and
only keep their own view-specific metadata (pagination, loading, sort state).

---

## 6. Risks & considerations

- **Entity model fidelity** — `CardRecord` must be a faithful superset of
  `StudyCard` + `BrowserCard` + `CardModResponse`. Every field a screen needs
  must live here or screens will reintroduce per-provider copies.
- **Immutability & identity** — use immutable records with `copyWith` and
  replace-on-update; avoid mutating record fields in place (silent stale UI).
- **Store granularity** — a single `notifyListeners()` for every mutation
  rebuilds all watchers. For large decks this can be wasteful. Acceptable for
  now; if it becomes a problem, add per-entity `ChangeNotifier` or `Select` /
  `context.select` to scope rebuilds.
- **Query layer** — extracting browse filter/sort/pagination and study
  due-selection into store queries is the subtlest part; keep those functions
  pure and well-tested.
- **Note-level actions** — `suspendNote`/`buryNote` return `NoteModResponse`
  (a count, not card ids). Without the backend returning affected card ids, the
  store cannot update each card. Recommended: keep note-level actions as
  "fire + reload" until the API returns affected ids (separate decision).

---

## 7. Decision needed before implementation

1. **Scope of the store**: cards + notes only (recommended), or also decks +
   note-types + classes?
2. **FSRS fields**: include `stability`/`difficulty`/`reps`/`lapses` as mutable
   store fields, or keep them read-only snapshots?
3. **Note-level actions**: ask backend to return affected card ids in
   `NoteModResponse`, or keep fire-and-reload?

---

## 8. Recommendation

Implement **Phase 2a** first. It is the natural extension of the
`CardStateProvider` work already in progress, directly fixes the
reschedule-stale bug, and establishes the normalized store pattern without a
risky big-bang rewrite. Phase 2b/2c can follow incrementally.
