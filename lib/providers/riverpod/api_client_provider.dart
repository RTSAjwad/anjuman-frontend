import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';

/// Riverpod access to the shared [ApiClient].
///
/// Auth seeds the token onto this single instance via
/// `ref.read(apiClientProvider).setToken(...)`.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
