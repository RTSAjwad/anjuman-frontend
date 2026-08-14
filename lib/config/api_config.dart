class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const Duration timeout = Duration(seconds: 30);

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';

  // Users
  static const String users = '/users';
  static const String userSearch = '/users/search';
  static String user(int id) => '/users/$id';
  static const String me = '/me';

  // Classes
  static const String classes = '/classes';
  static String classById(int id) => '/classes/$id';
  static String classRename(int id) => '/classes/$id/rename';
  static String classArchive(int id) => '/classes/$id/archive';
  static String classRoster(int id) => '/classes/$id/roster';
  static String classMembers(int id) => '/classes/$id/members';
  static String classMember(int classId, int userId) =>
      '/classes/$classId/members/$userId';

  // Decks
  static const String decks = '/decks';
  static String deckById(int id) => '/decks/$id';
  static String deckRename(int id) => '/decks/$id/rename';
  static String deckUpdate(int id) => '/decks/$id';
  static String deckDuplicate(int id) => '/decks/$id/duplicate';
  static String deckShare(int id) => '/decks/$id/share';
  static String deckUnshare(int deckId, int userId) =>
      '/decks/$deckId/share/$userId';
  static String deckOwner(int id) => '/decks/$id/owner';
  static String deckClasses(int id) => '/decks/$id/classes';
  static String deckClass(int deckId, int classId) =>
      '/decks/$deckId/classes/$classId';
  static String deckStudy(int id) => '/decks/$id/study';

  // Notes
  static String notes(int deckId) => '/decks/$deckId/notes';
  static String note(int deckId, int noteId) => '/decks/$deckId/notes/$noteId';

  // Note Types
  static const String noteTypes = '/note-types';
  static String noteTypeById(int id) => '/note-types/$id';

  // Assignments
  static String assignments(int classId) => '/classes/$classId/assignments';
  static String assignmentById(int id) => '/assignments/$id';
  static String assignmentPublish(int id) => '/assignments/$id/publish';
  static String assignmentArchive(int id) => '/assignments/$id/archive';
  static String assignmentStudy(int id) => '/assignments/$id/study';
  static String assignmentComplete(int id) => '/assignments/$id/complete';

  // Study
  static const String reviews = '/reviews';

  // Analytics
  static const String analyticsMe = '/analytics/me';
  static const String analyticsMeDaily = '/analytics/me/daily';
  static String analyticsClass(int id) => '/analytics/classes/$id';
  static String analyticsStudent(int classId, int studentId) =>
      '/analytics/classes/$classId/students/$studentId';

  // Dashboard
  static const String dashboard = '/dashboard';

  // Browser
  static const String browseCards = '/cards';
  static String cardFlag(int cardId) => '/cards/$cardId/flag';
}
