import 'package:flutter/foundation.dart';
import '../models/browser_card.dart';
import '../services/api_client.dart';
import '../services/browser_service.dart';

class BrowserProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final BrowserService _browserService;

  BrowserProvider(this._apiClient) {
    _browserService = BrowserService(_apiClient);
  }

  List<BrowserCard> _cards = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  final int _perPage = 50;

  int? _deckId;
  String _query = '';
  String _sort = 'created_at';

  List<BrowserCard> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get page => _page;
  int get total => _total;
  int get perPage => _perPage;
  int? get deckId => _deckId;
  String get query => _query;
  String get sort => _sort;

  bool get hasNextPage => _page * _perPage < _total;
  bool get hasPrevPage => _page > 1;

  Future<void> loadCards({bool append = false}) async {
    if (!append) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final response = await _browserService.browseCards(
        deckId: _deckId,
        query: _query,
        sort: _sort,
        page: _page,
        perPage: _perPage,
      );
      if (append) {
        _cards = [..._cards, ...response.cards];
      } else {
        _cards = response.cards;
      }
      _total = response.total;
    } on Exception catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void setDeckId(int? deckId) {
    _deckId = deckId;
    _page = 1;
    loadCards();
  }

  void setQuery(String query) {
    _query = query;
    _page = 1;
    loadCards();
  }

  void setSort(String sort) {
    _sort = sort;
    _page = 1;
    loadCards();
  }

  Future<void> nextPage() async {
    if (hasNextPage) {
      _page++;
      await loadCards(append: true);
    }
  }

  Future<void> prevPage() async {
    if (hasPrevPage) {
      _page--;
      await loadCards();
    }
  }
}
