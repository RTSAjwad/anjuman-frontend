# Anki Classroom Frontend — Architecture & Feature Reference

## Overview

A Flutter Material 3 desktop application (Linux-first) for a collaborative spaced repetition learning platform. Connects to a backend API at `localhost:3000` with JWT auth. Three roles: **admin**, **teacher**, **student**.

## Tech Stack

- **Framework**: Flutter 3.x (Dart)
- **State Management**: Provider (`ChangeNotifierProvider` via `package:provider: ^6.1.0`)
- **HTTP**: `package:http: ^1.2.0`
- **User Search**: `package:dropdown_search: ^7.0.0`
- **UI**: Material Design 3 (`useMaterial3: true`), `ThemeMode.system` for light/dark
- **Build**: Nix flake with Flutter SDK, Android SDK, Linux deps
- **Server decorations**: Force SSD via `use_header_bar = FALSE` in `my_application.cc`

---

## Directory Structure

```
lib/
├── main.dart                    # App entry, provider setup, auth gate
├── config/
│   └── api_config.dart          # All API endpoint paths and base URL
├── models/
│   ├── common.dart              # Shared: ApiException, parseTimestamp()
│   ├── auth.dart                # LoginRequest, LoginResponse, UserInfo
│   ├── user.dart                # CreateUser, UpdateUser, User, UserDetail, MeResponse
│   ├── class.dart               # CreateClass, ClassResponse, MemberResponse, RosterResponse
│   ├── class_info.dart          # ClassInfo (id, name) — lightweight class reference
│   ├── deck.dart                # DeckResponse, UpdateDeck, CollaboratorResponse, NoteResponse, etc.
│   ├── study.dart               # StudySession, StudyCard, SubmitReview, ReviewResponse, sessions
│   ├── search_result.dart       # SearchResult — user search dropdown item
│   ├── assignment.dart          # AssignmentResponse, CreateAssignment (legacy/deprecated)
│   └── analytics.dart           # DashboardResponse, ClassAnalytics, StudentStats (stubs)
├── providers/
│   ├── auth_provider.dart       # Login/logout, user info, API client ownership
│   ├── class_provider.dart      # CRUD classes, roster/member management
│   ├── deck_provider.dart       # CRUD decks, notes, sharing, transfer, class assignment
│   ├── study_provider.dart      # Study session loop, card queue, rating flow
│   ├── user_provider.dart       # CRUD users (admin)
│   └── assignment_provider.dart # Assignment CRUD (legacy/deprecated)
├── screens/
│   ├── login_screen.dart        # Login form with quick-login test buttons
│   ├── app_shell.dart           # NavigationRail + IndexedStack, role-based nav, avatar menu
│   ├── classes_screen.dart      # Class list with create dialog
│   ├── class_detail_screen.dart # Class roster, add/remove members, sortable
│   ├── decks_screen.dart        # Deck list with card counts, study button
│   ├── deck_detail_screen.dart  # Deck info, collaborators, notes CRUD, transfer, add to class
│   ├── study_screen.dart        # Card flip, FSRS rating buttons, session loop
│   ├── users_screen.dart        # Full user CRUD table with sortable columns (admin)
│   ├── assignments_screen.dart  # Assignments CRUD (legacy/deprecated)
│   └── stubs.dart               # Placeholder screens (Dashboard)
├── services/
│   ├── api_client.dart          # HTTP client: GET/POST/PATCH/DELETE, JWT, JSON parsing, errors
│   ├── auth_service.dart        # Login, logout
│   ├── class_service.dart       # Class CRUD, roster, members
│   ├── deck_service.dart        # Deck CRUD, notes, sharing, transfer, class assignment
│   ├── study_service.dart       # Deck study, daily due, reviews, sessions
│   ├── user_service.dart        # User CRUD, search
│   ├── assignment_service.dart  # Assignment CRUD (legacy/deprecated)
│   └── analytics_service.dart   # Dashboard, class stats, student detail (stubs)
└── widgets/
    └── sortable_table.dart      # SortableHeader widget + TableSort<T, F> generic sort state
```

---

## Architecture

### Layer 1: API Client (`lib/services/api_client.dart`)

A shared singleton that all services use. Holds the JWT token and attaches it as a `Bearer` header. Provides `getMap`, `getList`, `post`, `patch`, `delete` methods. Handles JSON parsing with `jsonDecode` and throws `ApiException` on non-2xx responses or malformed bodies. Fallback: treats non-JSON response bodies as plain-text error messages.

### Layer 2: Services (`lib/services/*.dart`)

Each resource domain has a service class that uses `ApiClient` to make typed API calls. Services call API config paths and deserialize JSON into model objects.

### Layer 3: Providers (`lib/providers/*.dart`)

`ChangeNotifier` classes that hold UI-visible state. Each provider:
- Accepts an `ApiClient` in its constructor
- Creates its corresponding service
- Exposes mutable state (lists, loading flags, error strings)
- Calls `notifyListeners()` on state changes
- All providers are created in `main.dart` via `MultiProvider` — available to the entire widget tree

### Layer 4: Screens (`lib/screens/*.dart`)

Flutter widgets that compose the UI. Access providers via `context.watch<T>()` (reactive) or `context.read<T>()` (one-shot). Dialogs capture provider references before showing (dialog context loses provider scope).

---

## Navigation

### `lib/screens/app_shell.dart`

Uses `NavigationRail` + `VerticalDivider` + `Expanded` with `IndexedStack`. The `IndexedStack` keeps all tab screens alive to preserve state (scroll position, sort order, loaded data).

**Role-based destinations**:

| Role    | Tabs                                                    |
|---------|---------------------------------------------------------|
| Admin   | Dashboard, Classes, Decks, Users                        |
| Teacher | Dashboard, Classes, Decks                               |
| Student | Dashboard, Decks, Classes                               |

**Avatar menu** (bottom of rail, icon-only):
- Settings (placeholder — `TODO`)
- Switch user (placeholder — `TODO`)
- Sign out → `auth.logout()`

The rail has **no leading/branding** — icon and text were removed per design decision.

---

## Feature Matrix

| Feature                     | Admin | Teacher | Student | Endpoint                        |
|-----------------------------|-------|---------|---------|---------------------------------|
| View own info               | ✓     | ✓       | ✓       | `POST /auth/login` (response)   |
| Quick-login test buttons    | ✓     | ✓       | ✓       | `POST /auth/login`              |
| View classes                | ✓     | ✓       | ✓       | `GET /classes`                  |
| Create class                | ✓     | ✓       | —       | `POST /classes`                 |
| Rename class                | ✓     | ✓       | —       | `PATCH /classes/{id}/rename`    |
| Delete class                | ✓     | ✓       | —       | `DELETE /classes/{id}`          |
| View class roster           | ✓     | ✓       | ✓       | `GET /classes/{id}/roster`      |
| Add member to class         | ✓     | ✓       | —       | `POST /classes/{id}/members`    |
| Remove member from class    | ✓     | ✓       | —       | `DELETE /classes/{id}/members/{uid}` |
| View decks                  | ✓     | ✓       | ✓       | `GET /decks`                    |
| Create deck                 | ✓     | ✓       | —       | `POST /decks`                   |
| Rename deck                 | ✓     | ✓(collab) | —    | `PATCH /decks/{id}/rename`      |
| Edit deck description       | ✓     | ✓(collab) | —    | `PATCH /decks/{id}`             |
| Duplicate deck              | ✓     | ✓(collab) | —    | `POST /decks/{id}/duplicate`    |
| Delete deck                 | ✓(owner) | —      | —    | `DELETE /decks/{id}`            |
| Share deck (add collab)     | ✓(owner) | —      | —    | `POST /decks/{id}/share`        |
| Remove collaborator         | ✓(owner) | —      | —    | `DELETE /decks/{id}/share/{uid}` |
| Transfer deck ownership     | ✓(owner) | —      | —    | `PATCH /decks/{id}/owner`       |
| Assign deck to class        | ✓       | ✓       | —       | `POST /decks/{id}/classes`      |
| Remove deck from class      | ✓       | ✓       | —       | `DELETE /decks/{id}/classes/{cid}` |
| View/crud notes             | ✓       | ✓(collab) | —    | `GET/POST/PATCH/DELETE /decks/{id}/notes` |
| Study deck cards            | —       | —       | ✓       | `GET /decks/{id}/study` + `POST /reviews` |
| View card counts (new/learn/due) | ✓ | ✓     | ✓       | `GET /decks` (deck response)    |
| View all users              | ✓       | —       | —       | `GET /users`                    |
| Create user                 | ✓       | —       | —       | `POST /users`                   |
| Edit user                   | ✓       | —       | —       | `PATCH /users/{id}`             |
| Delete user                 | ✓       | —       | —       | `DELETE /users/{id}`            |
| Sort tables                 | ✓       | ✓       | ✓       | Client-side via `TableSort<T,F>` |

---

## Key Design Patterns

### Provider dialog pattern

Dialogs pushed via `showDialog` use the root navigator context — providers are NOT accessible. Always **capture provider references before the dialog** and pass them as constructor parameters: `_DeckFormDialog(provider: provider)`.

### State reset on re-entry

`IndexedStack` keeps screens alive. `initState` may not re-fire. Screens that need fresh data on tab switch should reload in `didChangeDependencies` or use `postFrameCallback` in `initState` (for first load) combined with `RouteAware` or a visibility callback.

### Study session loop architecture

The study flow is a **continuous async queue** driven by the `StudyProvider`:

```
LOOP:
  1. GET /decks/{id}/study → returns available cards
  2. If empty/completed → show completed screen, return
  3. Show each card, wait for user rating
  4. POST /reviews → rating 1 (Again) re-queues, 2-4 schedules future
  5. Re-fetch → go to step 1
```

The loop uses a **generation counter** for cancellation: each `startDeckStudy()` bumps a counter. The old loop checks `gen != _loopGeneration` at every await point and exits. Rating submission uses a `Completer<bool>` pattern: the loop awaits the completer's future, and `submitRating()` completes it when the user taps a button.

### Completion detection

The `_loadCards()` method checks three conditions:
1. `session.completed == true` — backend explicitly says done
2. `session.cards.isEmpty && session.totalCards == 0` — no cards at all
3. All cards in the current batch were already reviewed — prevents infinite loops when backend returns the same card set repeatedly

### Timestamp parsing

Backend returns Unix timestamps as **strings like `"1783876363"`** (seconds). All models use shared `parseTimestamp()` from `common.dart` which handles strings, ints, and auto-detects seconds vs milliseconds (threshold: 1e12).

### `heroTag` on FABs

Each screen's `FloatingActionButton` needs a unique `heroTag` to avoid collisions in `IndexedStack`. Tags used: `create_deck`, `create_class`, `create_user`.

---

## Files in Detail

### `lib/main.dart`

- `AnkiClassroomApp`: Sets up `MaterialApp` with light/dark themes (`colorSchemeSeed: Colors.deepPurple`)
- `AuthGate`: Conditionally shows `LoginScreen` or `MultiProvider` + `AppShell`
- Providers: `ClassProvider`, `DeckProvider`, `StudyProvider`, `UserProvider` — all receive the auth's `ApiClient`

### `lib/config/api_config.dart`

All API endpoint paths as static constants/methods. Base URL: `http://localhost:3000`, timeout: 30s. Groups: Auth, Users, Classes, Decks, Notes, Assignments (legacy), Study, Analytics, Dashboard.

### `lib/models/deck.dart`

- `CreateDeck`, `RenameDeck`, `UpdateDeck` — request bodies
- `DeckResponse` — deck list item. Fields: id, title, description, createdBy, ownerEmail, ownerFirstName, ownerLastName, originalDeckId, createdAt, newCount, learningCount, relearningCount, dueCount, totalCount. Computed: `ownerDisplayName` (firstName lastName or email), `hasCards` (totalCount > 0)
- `CollaboratorResponse` — collaborator info with displayName
- `DeckDetailResponse` — deck + collaborators + classes
- `CreateNote`, `UpdateNote`, `NoteResponse`, `CardSummary` — note CRUD models

### `lib/models/study.dart`

- `StudyCard` — fields: cardId, front, back, state (new/learning/review/relearning), dueAt, stability, difficulty, reps, lapses, deckTitle, predictedInterval (Map<String, int> of rating→days)
- `StudySession` — response wrapper: cards, totalCards, reviewedCount, completed flag, deckId, deckTitle
- `SubmitReview` — request: cardId, rating (1-4), responseTimeMs?, sessionId?
- `ReviewResponse` — intervalDays, new stability/difficulty, reps, lapses
- `SessionStarted`, `EndSession`, `SessionEnded` — session lifecycle

### `lib/widgets/sortable_table.dart`

- `SortableHeader` — column header widget with tap-to-sort, active indicator arrow
- `TableSort<T, F extends Enum>` — generic sort state: `toggle(field)`, `sort(items, keyFn)`. Used by `UsersScreen` (UserSortField) and `DecksScreen` (DeckSortField) and `ClassDetailScreen` (MemberSortField).

### `lib/services/api_client.dart`

- `setToken(String?)` — updates JWT
- `_headers` — includes `Authorization: Bearer` when token present
- `getMap()`, `getList()`, `post()`, `patch()`, `delete()` — typed HTTP methods
- `_handleResponse()` — for map responses (200-299 → decoded map, else → throw ApiException with error field)
- `_handleListResponse()` — for list responses
- `_decodeJson()` — tries `jsonDecode`, falls back to plain text error message

### `lib/providers/study_provider.dart`

Complex async state machine:
- **Inputs**: `startDeckStudy(deckId)`, `startDueCards()`, `flipCard()`, `submitRating(rating)`, `reset()`
- **Outputs**: `cards`, `currentCard`, `showBack`, `isLoading`, `isSubmitting`, `isComplete`, `error`, `deckTitle`, `totalCount`, `reviewedCount`
- **Internals**: `_fetchLoop()` (while loop), `_loadCards()` (API call), `_waitForRating()` (Completer pattern), `_cancelLoop()` (generation counter)
- **Cancellation**: `_loopGeneration` counter. Old loops check `gen != _loopGeneration` at every await point.
- **Completion**: Sets `_isComplete = true` and `_isLoading = false` in a single `notifyListeners()` on terminal conditions.

### `lib/screens/deck_detail_screen.dart`

Multi-section detail view:
- **AppBar**: Rename/Duplicate/Delete popup menu (teachers)
- **Description**: Inline editable with pencil icon → TextField + save/cancel buttons
- **Owner**: Avatar, display name, email. Transfer button (owner/admin)
- **Collaborators**: List with avatars, remove button. Share button → user search dropdown
- **Assigned Classes**: List with remove button. "Add" button → class dropdown
- **Notes table**: Front/Back/Cards columns, edit/delete actions

### `lib/screens/decks_screen.dart`

Deck list with:
- **Cards**: Title, description, Study button (students only), stat chips
- **Stat chips**: Owner name, new count (blue), learning count (orange), relearning count (purple), due count (green), total cards
- **Wrap layout**: Uses `Wrap` with `spacing: 12` for stat chips — handles overflow gracefully
- **Auto-refresh**: After returning from StudyScreen, calls `deckProvider.loadDecks()` to update counts

### `lib/screens/study_screen.dart`

Card review UI:
- **AppBar**: Deck title, progress bar (LinearProgressIndicator)
- **Card view**: Front/back text with flip animation via state toggle
- **Show Answer button**: Visible when front is shown
- **Rating buttons**: Again (red), Hard (orange), Good (green), Easy (blue). Show predicted intervals like "1 day", "3 days", etc.
- **Empty view**: "All caught up! No cards due right now" with Check again + Back to decks
- **Completed view**: 🏆 "Deck Complete! All available cards have been reviewed" with Study again + Back to decks
- **Error view**: Error message with Retry button

### `lib/screens/login_screen.dart`

- Email + password form with validation
- Show/hide password toggle
- Quick-login test buttons: Admin (`admin@school1.com` / `admin123`), Teacher (`teacher@school1.com` / `teach123`), Student (`student@school1.com` / `stud123`)
- Loading spinner on submit button
- Error SnackBar on failure

### `lib/screens/classes_screen.dart`

- Class list cards with name, description, chevron
- Archived badge
- Create Class dialog (name + description)
- Teacher/Admin FAB

### `lib/screens/class_detail_screen.dart`

- Sortable member table (name, email, role, joined)
- Remove member (teacher/admin only)
- Add member dialog via `dropdown_search` (user search)
- Member count display

### `lib/screens/users_screen.dart` (admin only)

- Full user table: Name, Email, Role, Created
- Sortable columns (Name, Email, Role)
- Create/Edit dialog with first name, last name, email, password, role dropdown
- Delete confirmation dialog
- Role color badges

---

## Deprecated / Legacy Code

These files still exist but are not actively used in the current app flow:

| File                               | Reason                                                              |
|------------------------------------|---------------------------------------------------------------------|
| `lib/screens/assignments_screen.dart` | Assignments feature removed from API — students now study directly |
| `lib/providers/assignment_provider.dart` | Same as above                                                       |
| `lib/services/assignment_service.dart` | Same as above                                                       |
| `lib/models/assignment.dart`       | Same as above                                                       |
| `lib/models/analytics.dart`        | Analytics not yet implemented in UI                                 |
| `lib/services/analytics_service.dart` | Same as above                                                       |
| `lib/screens/stubs.dart`           | DashboardStub still used; other stubs are unused                    |

---

## Build & Run

```bash
nix develop             # Enter Nix environment with Flutter SDK
flutter run -d linux    # Run on Linux desktop
flutter analyze         # Static analysis (0 issues expected)
```
