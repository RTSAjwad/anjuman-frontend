import 'common.dart';

class CreateAssignment {
  final int deckId;
  final String title;
  final int? dueAt;
  final bool? published;

  CreateAssignment({
    required this.deckId,
    required this.title,
    this.dueAt,
    this.published,
  });

  Map<String, dynamic> toJson() => {
        'deck_id': deckId,
        'title': title,
        if (dueAt != null) 'due_at': dueAt,
        if (published != null) 'published': published,
      };
}

class UpdateAssignment {
  final String? title;
  final int? dueAt;

  UpdateAssignment({this.title, this.dueAt});

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (dueAt != null) 'due_at': dueAt,
      };
}

class AssignmentResponse {
  final int id;
  final int classId;
  final int deckId;
  final String title;
  final int? dueAt;
  final bool published;
  final bool archived;
  final int createdBy;
  final DateTime createdAt;

  AssignmentResponse({
    required this.id,
    required this.classId,
    required this.deckId,
    required this.title,
    this.dueAt,
    required this.published,
    required this.archived,
    required this.createdBy,
    required this.createdAt,
  });

  factory AssignmentResponse.fromJson(Map<String, dynamic> json) =>
      AssignmentResponse(
        id: json['id'],
        classId: json['class_id'],
        deckId: json['deck_id'],
        title: json['title'],
        dueAt: json['due_at'],
        published: json['published'] ?? false,
        archived: json['archived'] ?? false,
        createdBy: json['created_by'],
        createdAt: parseTimestamp(json['created_at']),
      );
}

class AssignmentDetailResponse {
  final AssignmentResponse assignment;
  final int studentCount;
  final int completedCount;

  AssignmentDetailResponse({
    required this.assignment,
    required this.studentCount,
    required this.completedCount,
  });

  factory AssignmentDetailResponse.fromJson(Map<String, dynamic> json) =>
      AssignmentDetailResponse(
        assignment: AssignmentResponse.fromJson(json['assignment']),
        studentCount: json['student_count'],
        completedCount: json['completed_count'],
      );
}
