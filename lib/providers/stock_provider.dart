import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/candle_data.dart';
import '../models/stock_item.dart';
import '../services/database_service.dart';
import '../services/stock_api_service.dart';
import '../services/cloud_sync_service.dart';

class StockProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _api = StockApiService();
  final _cloud = CloudSyncService();

  List<StockItem> _stocks = [];
  StockItem? _selectedStock;
  List<CandleData> _detailChart = [];
  String _selectedRange = '3mo';
  DateTime? _lastUpdatedAt;
  DateTime? _nextRefreshAt;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  static const Duration refreshInterval = Duration(minutes: 2);

  List<StockItem> get stocks => _stocks;
  StockItem? get selectedStock => _selectedStock;
  List<CandleData> get detailChart => _detailChart;
  String get selectedRange => _selectedRange;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  DateTime? get nextRefreshAt => _nextRefreshAt;
  bool get isRefreshing => _isRefreshing;

  Future<void> init() async {
    // 1) 로컬 캐시 먼저 표시 (오프라인/지연 대비)
    _stocks = await _db.loadWatchlist();
    notifyListeners();

    // 2) 클라우드에서 공용 리스트 조회 → 성공 시 소스로 채택
    final cloud = await _cloud.fetch();
    if (cloud != null) {
      _stocks = cloud;
      await _db.saveAll(_stocks); // 로컬 캐시 동기화
      notifyListeners();
    } else if (_stocks.isNotEmpty) {
      // 클라우드 실패 + 로컬에 데이터가 있으면 클라우드 초기 업로드 시도
      _cloud.save(_stocks);
    }

    // 3) 현재가/차트 로드 + 타이머 시작
    if (_stocks.isNotEmpty) await _fetchAllData();
    _startAutoRefresh();
  }

  /// 클라우드 변경을 가져와 현재 리스트와 다르면 반영 (기기 간 동기화).
  Future<void> _syncFromCloud() async {
    final cloud = await _cloud.fetch();
    if (cloud == null) return;
    final cloudKey = cloud.map((s) => s.ticker).join(',');
    final localKey = _stocks.map((s) => s.ticker).join(',');
    if (cloudKey == localKey) return; // 변경 없음
    _stocks = cloud;
    await _db.saveAll(_stocks);
    notifyListeners();
    if (_stocks.isNotEmpty) await _fetchAllData();
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
    _nextRefreshAt = DateTime.now().add(refreshInterval);
    notifyListeners();
    _refreshTimer = Timer.periodic(refreshInterval, (_) async {
      await _syncFromCloud(); // 다른 기기의 변경 반영
      await refreshPrices(); // 현재가 갱신
      _nextRefreshAt = DateTime.now().add(refreshInterval);
      notifyListeners();
    });
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
    _cloud.save(_stocks); // 클라우드 동기화
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
    _cloud.save(_stocks); // 클라우드 동기화
  }

  Future<void> removeStock(String ticker) async {
    _stocks.removeWhere((s) => s.ticker == ticker);
    if (_selectedStock?.ticker == ticker) {
      _selectedStock = null;
      _detailChart = [];
    }
    await _db.removeStock(ticker);
    _cloud.save(_stocks); // 클라우드 동기화
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
