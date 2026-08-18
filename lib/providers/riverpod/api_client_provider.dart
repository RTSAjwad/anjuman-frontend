import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';

/// Riverpod access to the shared [ApiClient].
///
/// The running app still wires its token through the legacy `AuthProvider`
/// (`apiClient.setToken(...)`), which owns its own `ApiClient` instance. During
/// this migration step the browser Riverpod store is not yet wired into the app,
/// so this provider simply exposes a fresh [ApiClient]. Once auth is migrated,
/// this provider should seed the token from the Riverpod auth store (and the
/// legacy `AuthProvider`'s client should be dropped).
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
