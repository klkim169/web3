import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/candle_data.dart';
import '../models/stock_item.dart';
import '../services/database_service.dart';
import '../services/stock_api_service.dart';

class StockProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _api = StockApiService();

  List<StockItem> _stocks = [];
  StockItem? _selectedStock;
  List<CandleData> _detailChart = [];
  String _selectedRange = '3mo';
  DateTime? _lastUpdatedAt;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  List<StockItem> get stocks => _stocks;
  StockItem? get selectedStock => _selectedStock;
  List<CandleData> get detailChart => _detailChart;
  String get selectedRange => _selectedRange;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  bool get isRefreshing => _isRefreshing;

  Future<void> init() async {
    _stocks = await _db.loadWatchlist();
    notifyListeners();
    if (_stocks.isNotEmpty) await _fetchAllData();
    _startAutoRefresh();
  }

  Future<void> _fetchAllData() async {
    _isRefreshing = true;
    notifyListeners();
    await Future.wait(_stocks.map(_loadStock));
    _lastUpdatedAt = DateTime.now();
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> _loadStock(StockItem stock) async {
    stock.isLoading = true;
    notifyListeners();
    final quote = await _api.fetchQuote(stock.ticker);
    final mini = await _api.fetchMiniChart(stock.ticker);
    stock.currentPrice = quote.price;
    stock.changePercent = quote.changePercent;
    stock.miniChart = mini;
    stock.isLoading = false;
    notifyListeners();
  }

  Future<void> refreshPrices() async {
    if (_stocks.isEmpty) return;
    _isRefreshing = true;
    notifyListeners();
    await Future.wait(_stocks.map((s) async {
      final q = await _api.fetchQuote(s.ticker);
      s.currentPrice = q.price;
      s.changePercent = q.changePercent;
    }));
    _lastUpdatedAt = DateTime.now();
    _isRefreshing = false;
    notifyListeners();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => refreshPrices());
  }

  Future<void> addStock(String ticker, String companyName) async {
    if (_stocks.any((s) => s.ticker == ticker)) return;
    final stock = StockItem(
      ticker: ticker,
      companyName: companyName,
      sortOrder: _stocks.length + 1,
      isLoading: true,
    );
    _stocks.add(stock);
    notifyListeners();
    await _db.addStock(stock);
    await _loadStock(stock);
  }

  void reorderStock(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    final stock = _stocks.removeAt(fromIndex);
    _stocks.insert(toIndex, stock);
    for (int i = 0; i < _stocks.length; i++) {
      _stocks[i].sortOrder = i + 1;
    }
    notifyListeners();
    _db.saveAll(_stocks);
  }

  Future<void> removeStock(String ticker) async {
    _stocks.removeWhere((s) => s.ticker == ticker);
    if (_selectedStock?.ticker == ticker) {
      _selectedStock = null;
      _detailChart = [];
    }
    await _db.removeStock(ticker);
    notifyListeners();
  }

  Future<void> selectStock(StockItem? stock) async {
    if (_selectedStock?.ticker == stock?.ticker) {
      _selectedStock = null;
      _detailChart = [];
      notifyListeners();
      return;
    }
    _selectedStock = stock;
    _detailChart = [];
    notifyListeners();
    if (stock != null) await _loadDetailChart(stock.ticker, _selectedRange);
  }

  Future<void> setRange(String range) async {
    _selectedRange = range;
    _detailChart = [];
    notifyListeners();
    if (_selectedStock != null) await _loadDetailChart(_selectedStock!.ticker, range);
  }

  Future<void> _loadDetailChart(String ticker, String range) async {
    final data = await _api.fetchDetailChart(ticker, range);
    _detailChart = data;
    notifyListeners();
  }

  Future<List<Map<String, String>>> searchStocks(String query) =>
      _api.searchStocks(query);

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
