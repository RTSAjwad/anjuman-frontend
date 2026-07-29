import 'package:flutter/foundation.dart';
import '../models/class.dart';
import '../services/api_client.dart';
import '../services/class_service.dart';
import '../widgets/safe_notify.dart';

class ClassProvider extends ChangeNotifier with SafeNotify {
  final ApiClient _apiClient;
  late final ClassService _classService;

  ApiClient get apiClient => _apiClient;

  ClassProvider(this._apiClient) {
    _classService = ClassService(_apiClient);
  }

  List<ClassResponse> _classes = [];
  final Map<int, RosterResponse> _rosters = {};
  bool _isLoading = false;
  String? _error;

  List<ClassResponse> get classes => _classes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  RosterResponse? rosterForClass(int classId) => _rosters[classId];

  Future<void> loadClasses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _classes = await _classService.listClasses();
    } on Exception catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    safeNotify();
  }

  Future<ClassResponse?> createClass(String name, String? description) async {
    try {
      final response = await _classService.createClass(
        CreateClass(name: name, description: description),
      );
      await loadClasses();
      return response;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteClass(int id) async {
    try {
      await _classService.deleteClass(id);
      _rosters.remove(id);
      await loadClasses();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<ClassResponse?> renameClass(int id, String name) async {
    try {
      final response = await _classService.renameClass(id, name);
      await loadClasses();
      return response;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<RosterResponse?> loadRoster(int classId) async {
    try {
      final roster = await _classService.getRoster(classId);
      _rosters[classId] = roster;
      notifyListeners();
      return roster;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
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
      _error = e.toString();
      notifyListeners();
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
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
