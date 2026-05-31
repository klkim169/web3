import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_item.dart';

class DatabaseService {
  static const _key = 'watchlist_v1';

  Future<List<StockItem>> loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((m) => StockItem.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> addStock(StockItem stock) async {
    final stocks = await loadWatchlist();
    if (stocks.any((s) => s.ticker == stock.ticker)) return;
    stocks.add(stock);
    await _persist(stocks);
  }

  Future<void> removeStock(String ticker) async {
    final stocks = await loadWatchlist();
    stocks.removeWhere((s) => s.ticker == ticker);
    await _persist(stocks);
  }

  Future<void> saveAll(List<StockItem> stocks) => _persist(stocks);

  Future<void> _persist(List<StockItem> stocks) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(stocks.map((s) => s.toMap()).toList());
    await prefs.setString(_key, json);
  }
}
