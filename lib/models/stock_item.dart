import 'candle_data.dart';

class StockItem {
  final String ticker;
  final String companyName;
  int sortOrder;
  double currentPrice;
  double changePercent;
  List<CandleData> miniChart;
  bool isLoading;

  StockItem({
    required this.ticker,
    required this.companyName,
    required this.sortOrder,
    this.currentPrice = 0.0,
    this.changePercent = 0.0,
    this.miniChart = const [],
    this.isLoading = false,
  });

  Map<String, dynamic> toMap() => {
        'ticker': ticker,
        'company_name': companyName,
        'sort_order': sortOrder,
      };

  factory StockItem.fromMap(Map<String, dynamic> map) => StockItem(
        ticker: map['ticker'] as String,
        companyName: map['company_name'] as String,
        sortOrder: map['sort_order'] as int,
      );
}
