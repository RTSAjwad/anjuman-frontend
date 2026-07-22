class MessageResponse {
  final String message;

  MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      MessageResponse(message: json['message']);
}

class ErrorResponse {
  final String error;

  ErrorResponse({required this.error});

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      ErrorResponse(error: json['error']);
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

DateTime parseTimestamp(dynamic raw) {
  if (raw is int) {
    final ms = raw > 1e12 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  if (raw is String) {
    final parsed = int.tryParse(raw);
    if (parsed != null) {
      final ms = parsed > 1e12 ? parsed : parsed * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.parse(raw);
  }
  return DateTime.now();
}
