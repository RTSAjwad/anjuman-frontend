import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/class.dart';
import '../../services/class_service.dart';
import 'api_client_provider.dart';

/// Immutable view state for the class provider.
///
/// Mirrors the mutable fields held by the legacy `ClassProvider`, as an
/// immutable value so every change produces a new [ClassState].
class ClassState {
  final List<ClassResponse> classes;
  final Map<int, RosterResponse> rosters;
  final bool isLoading;
  final String? error;

  const ClassState({
    this.classes = const [],
    this.rosters = const {},
    this.isLoading = false,
    this.error,
  });

  ClassState copyWith({
    List<ClassResponse>? classes,
    Map<int, RosterResponse>? rosters,
    bool? isLoading,
    String? error,
  }) {
    return ClassState(
      classes: classes ?? this.classes,
      rosters: rosters ?? this.rosters,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Riverpod replacement for the legacy `ClassProvider`.
///
/// Reads the shared [apiClientProvider] for API access, keeping the same
/// method signatures as the legacy provider.
class ClassNotifier extends Notifier<ClassState> {
  ClassService get _classService => ClassService(ref.read(apiClientProvider));

  List<ClassResponse> get classes => state.classes;
  bool get isLoading => state.isLoading;
  String? get error => state.error;

  RosterResponse? rosterForClass(int classId) => state.rosters[classId];

  @override
  ClassState build() => const ClassState();

  Future<void> loadClasses() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final classes = await _classService.listClasses();
      state = state.copyWith(classes: classes, isLoading: false);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<ClassResponse?> createClass(String name, String? description) async {
    try {
      final response = await _classService.createClass(
        CreateClass(name: name, description: description),
      );
      await loadClasses();
      return response;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> deleteClass(int id) async {
    try {
      await _classService.deleteClass(id);
      final rosters = Map<int, RosterResponse>.from(state.rosters)..remove(id);
      state = state.copyWith(rosters: rosters);
      await loadClasses();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<ClassResponse?> renameClass(int id, String name) async {
    try {
      final response = await _classService.renameClass(id, name);
      await loadClasses();
      return response;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<RosterResponse?> loadRoster(int classId) async {
    try {
      final roster = await _classService.getRoster(classId);
      state = state.copyWith(
        rosters: {...state.rosters, classId: roster},
      );
      return roster;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> addMember(int classId, int userId) async {
    try {
      await _classService.addMember(classId, userId);
      await loadRoster(classId);
      await loadClasses();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> removeMember(int classId, int userId) async {
    try {
      await _classService.removeMember(classId, userId);
      await loadRoster(classId);
      await loadClasses();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// The shared class provider.
final classProvider =
    NotifierProvider<ClassNotifier, ClassState>(ClassNotifier.new);
