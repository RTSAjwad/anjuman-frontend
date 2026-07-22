import 'common.dart';

class CreateClass {
  final String name;
  final String? description;

  CreateClass({required this.name, this.description});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
      };
}

class RenameClass {
  final String name;

  RenameClass({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}

class AddMember {
  final int userId;

  AddMember({required this.userId});

  Map<String, dynamic> toJson() => {'user_id': userId};
}

class ClassResponse {
  final int id;
  final int schoolId;
  final String name;
  final String? description;
  final bool archived;
  final int createdBy;
  final DateTime createdAt;

  ClassResponse({
    required this.id,
    required this.schoolId,
    required this.name,
    this.description,
    required this.archived,
    required this.createdBy,
    required this.createdAt,
  });

  factory ClassResponse.fromJson(Map<String, dynamic> json) => ClassResponse(
        id: json['id'],
        schoolId: json['school_id'],
        name: json['name'],
        description: json['description'],
        archived: json['archived'] ?? false,
        createdBy: json['created_by'],
        createdAt: parseTimestamp(json['created_at']),
      );
}

class MemberResponse {
  final int userId;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final int joinedAt;

  MemberResponse({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.joinedAt,
  });

  String get displayName => '$firstName $lastName'.trim();

  factory MemberResponse.fromJson(Map<String, dynamic> json) => MemberResponse(
        userId: json['user_id'],
        email: json['email'],
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        role: json['role'],
        joinedAt: json['joined_at'],
      );
}

class RosterResponse {
  final ClassResponse classInfo;
  final List<MemberResponse> members;

  RosterResponse({required this.classInfo, required this.members});

  factory RosterResponse.fromJson(Map<String, dynamic> json) => RosterResponse(
        classInfo: ClassResponse.fromJson(json['class']),
        members: (json['members'] as List)
            .map((m) => MemberResponse.fromJson(m))
            .toList(),
      );
}
