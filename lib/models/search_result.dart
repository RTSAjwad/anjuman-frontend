class SearchResult {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;

  SearchResult({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  String get displayName =>
      '$firstName $lastName'.trim().isEmpty ? email : '$firstName $lastName';

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        id: json['id'],
        email: json['email'],
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        role: json['role'],
      );
}
