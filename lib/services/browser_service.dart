import '../config/api_config.dart';
import '../models/browser_card.dart';
import 'api_client.dart';

class BrowserService {
  final ApiClient _client;

  BrowserService(this._client);

  Future<BrowserCardsResponse> browseCards({
    List<int>? deckIds,
    String? query,
    String? sort,
    int? page,
    int? perPage,
    List<String>? states,
    List<int>? noteTypeIds,
  }) async {
    final params = <String, String>{};
    if (deckIds != null && deckIds.isNotEmpty) {
      params['deck_id'] = deckIds.join(',');
    }
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (sort != null) params['sort'] = sort;
    if (page != null) params['page'] = page.toString();
    if (perPage != null) params['per_page'] = perPage.toString();
    if (states != null && states.isNotEmpty) {
      params['state'] = states.join(',');
    }
    if (noteTypeIds != null && noteTypeIds.isNotEmpty) {
      params['note_type_id'] = noteTypeIds.join(',');
    }

    final queryString = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    final json = await _client.getMap('${ApiConfig.browseCards}$queryString');
    return BrowserCardsResponse.fromJson(json);
  }
}
