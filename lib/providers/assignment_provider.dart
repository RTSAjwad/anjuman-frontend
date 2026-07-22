import 'package:flutter/foundation.dart';
import '../models/assignment.dart';
import '../services/api_client.dart';
import '../services/assignment_service.dart';

class AssignmentProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final AssignmentService _service;

  ApiClient get apiClient => _apiClient;

  AssignmentProvider(this._apiClient) {
    _service = AssignmentService(_apiClient);
  }

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<List<AssignmentResponse>> listAssignments(int classId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await _service.listAssignments(classId);
      _isLoading = false;
      notifyListeners();
      return list;
    } on Exception catch (_) {
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<AssignmentDetailResponse?> getAssignment(int id) async {
    try {
      return await _service.getAssignment(id);
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> createAssignment(
      int classId, CreateAssignment assignment) async {
    try {
      await _service.createAssignment(classId, assignment);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAssignment(int id, UpdateAssignment update) async {
    try {
      await _service.updateAssignment(id, update);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAssignment(int id) async {
    try {
      await _service.deleteAssignment(id);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishAssignment(int id) async {
    try {
      await _service.publishAssignment(id);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> archiveAssignment(int id) async {
    try {
      await _service.archiveAssignment(id);
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
