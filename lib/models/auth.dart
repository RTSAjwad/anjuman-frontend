// Auth models

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class UserInfo {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final int schoolId;

  UserInfo({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.schoolId,
  });

  String get displayName => '$firstName $lastName'.trim();

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'],
        email: json['email'],
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        role: json['role'],
        schoolId: json['school_id'],
      );
}

class LoginResponse {
  final String token;
  final UserInfo user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'],
        user: UserInfo.fromJson(json['user']),
      );
}
