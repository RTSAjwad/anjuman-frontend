import '../config/api_config.dart';
import '../models/browser_card.dart';
import 'api_client.dart';

class BrowserService {
  final ApiClient _client;

  BrowserService(this._client);

  Future<BrowserCardsResponse> browseCards({
    int? deckId,
    String? query,
    String? sort,
    int? page,
    int? perPage,
  }) async {
    final params = <String, String>{};
    if (deckId != null) params['deck_id'] = deckId.toString();
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (sort != null) params['sort'] = sort;
    if (page != null) params['page'] = page.toString();
    if (perPage != null) params['per_page'] = perPage.toString();

    final queryString = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    final json = await _client.getMap('${ApiConfig.browseCards}$queryString');
    return BrowserCardsResponse.fromJson(json);
  }
}
