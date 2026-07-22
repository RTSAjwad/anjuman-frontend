import 'common.dart';

class CreateUser {
  final int schoolId;
  final String email;
  final String password;
  final String role;
  final String firstName;
  final String lastName;

  CreateUser({
    required this.schoolId,
    required this.email,
    required this.password,
    required this.role,
    required this.firstName,
    required this.lastName,
  });

  Map<String, dynamic> toJson() => {
        'school_id': schoolId,
        'email': email,
        'password': password,
        'role': role,
        'first_name': firstName,
        'last_name': lastName,
      };
}

class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final int schoolId;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.schoolId,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        email: json['email'],
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        role: json['role'],
        schoolId: json['school_id'],
      );
}

class UpdateUser {
  final String? email;
  final String? password;
  final String? role;
  final String? firstName;
  final String? lastName;

  UpdateUser({
    this.email,
    this.password,
    this.role,
    this.firstName,
    this.lastName,
  });

  Map<String, dynamic> toJson() => {
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        if (role != null) 'role': role,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
      };
}

class UserDetail {
  final int id;
  final int schoolId;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final DateTime createdAt;

  UserDetail({
    required this.id,
    required this.schoolId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.createdAt,
  });

  String get displayName => '$firstName $lastName'.trim();

  factory UserDetail.fromJson(Map<String, dynamic> json) => UserDetail(
        id: json['id'],
        schoolId: json['school_id'],
        email: json['email'],
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        role: json['role'],
        createdAt: parseTimestamp(json['created_at']),
      );
}

class MeResponse {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final int schoolId;

  MeResponse({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.schoolId,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
        id: json['id'],
        email: json['email'],
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        role: json['role'],
        schoolId: json['school_id'],
      );
}
