import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/candle_data.dart';

class StockApiService {
  static const _host1 = 'query1.finance.yahoo.com';
  static const _host2 = 'query2.finance.yahoo.com';
  static const _corsProxy = 'https://corsproxy.io/?';
  static const _headers = {'User-Agent': 'Mozilla/5.0'};

  Uri _proxyUri(Uri target) {
    if (!kIsWeb) return target;
    return Uri.parse('$_corsProxy${Uri.encodeComponent(target.toString())}');
  }

  // 한글 종목명 → 티커 매핑 (Yahoo Finance는 한글 미지원)
  static const _koreanMap = {
    '마이크론': 'MU',
    '애플': 'AAPL',
    '아이폰': 'AAPL',
    '마이크로소프트': 'MSFT',
    '테슬라': 'TSLA',
    '엔비디아': 'NVDA',
    '아마존': 'AMZN',
    '구글': 'GOOGL',
    '알파벳': 'GOOGL',
    '메타': 'META',
    '페이스북': 'META',
    '넷플릭스': 'NFLX',
    '인텔': 'INTC',
    '어도비': 'ADBE',
    '세일즈포스': 'CRM',
    '퀄컴': 'QCOM',
    '브로드컴': 'AVGO',
    '암드': 'AMD',
    '팔란티어': 'PLTR',
    '스노우플레이크': 'SNOW',
    '코인베이스': 'COIN',
    '우버': 'UBER',
    '에어비앤비': 'ABNB',
    '줌': 'ZM',
    '스포티파이': 'SPOT',
    '스냅': 'SNAP',
    '클라우드플레어': 'NET',
    '데이터독': 'DDOG',
    '보잉': 'BA',
    '포드': 'F',
    '제너럴모터스': 'GM',
    '리비안': 'RIVN',
    '니오': 'NIO',
    '골드만삭스': 'GS',
    '모건스탠리': 'MS',
    '뱅크오브아메리카': 'BAC',
    '제이피모건': 'JPM',
    '씨티그룹': 'C',
    '비자': 'V',
    '마스터카드': 'MA',
    '페이팔': 'PYPL',
    '일라이릴리': 'LLY',
    '화이자': 'PFE',
    '모더나': 'MRNA',
    '암젠': 'AMGN',
    '나이키': 'NKE',
    '스타벅스': 'SBUX',
    '코카콜라': 'KO',
    '월마트': 'WMT',
    '코스트코': 'COST',
    '버크셔': 'BRK-B',
    '텍사스인스트루먼트': 'TXN',
    '팔로알토': 'PANW',
    '크라우드스트라이크': 'CRWD',
    '오라클': 'ORCL',
    '시스코': 'CSCO',
    '샌디스크': 'SNDK',
    '웨스턴디지털': 'WDC',
    '시게이트': 'STX',
    '넷앱': 'NTAP',
    '휴렛팩커드': 'HPQ',
    '델': 'DELL',
    'IBM': 'IBM',
    '아이비엠': 'IBM',
    '텍사스인스': 'TXN',
    '버라이즌': 'VZ',
    '에이티앤티': 'T',
    '티모바일': 'TMUS',
    '컴캐스트': 'CMCSA',
    '디즈니': 'DIS',
    '워너브라더스': 'WBD',
    '파라마운트': 'PARA',
    '엑슨모빌': 'XOM',
    '쉐브론': 'CVX',
    '코노코필립스': 'COP',
    '존슨앤존슨': 'JNJ',
    '유나이티드헬스': 'UNH',
    '애브비': 'ABBV',
    '머크': 'MRK',
    '리제네론': 'REGN',
    '버텍스': 'VRTX',
    '캐터필러': 'CAT',
    '디어': 'DE',
    '록히드마틴': 'LMT',
    '레이시온': 'RTX',
    '넥스트에라': 'NEE',
    '듀크에너지': 'DUK',
    '아메리칸타워': 'AMT',
    '프롤로지스': 'PLD',
    '쇼피파이': 'SHOP',
    '스퀘어': 'XYZ',
    '블록': 'XYZ',
    '로블록스': 'RBLX',
    '유니티': 'U',
    '트위치': 'AMZN',
    '리프트': 'LYFT',
  };

  String _translateQuery(String query) {
    final q = query.trim();
    // 정확히 일치하는 한글 키 먼저 검색
    if (_koreanMap.containsKey(q)) return _koreanMap[q]!;
    // 부분 일치 검색 (예: "마이크론 테크놀로지")
    for (final entry in _koreanMap.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return q;
  }

  Future<List<Map<String, String>>> searchStocks(String query) async {
    if (query.trim().isEmpty) return [];
    final translated = _translateQuery(query);
    try {
      final target = Uri.https(_host2, '/v1/finance/search', {
        'q': translated,
        'quotesCount': '8',
        'newsCount': '0',
        'enableFuzzyQuery': 'false',
      });
      final res = await http
          .get(_proxyUri(target), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final quotes =
          (data['quotes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      const allowedTypes = {'EQUITY', 'ETF', 'MUTUALFUND', 'INDEX'};
      return quotes
          .where((q) => allowedTypes.contains(q['quoteType']))
          .map((q) => {
                'ticker': (q['symbol'] as String? ?? '').toUpperCase(),
                'name': (q['shortname'] ??
                    q['longname'] ??
                    q['symbol'] ??
                    '') as String,
              })
          .where((q) => q['ticker']!.isNotEmpty)
          .take(8)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchChart(
      String ticker, String range) async {
    try {
      final target = Uri.https(_host1, '/v8/finance/chart/$ticker', {
        'interval': '1d',
        'range': range,
      });
      final res = await http
          .get(_proxyUri(target), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = data['chart']?['result'] as List?;
      if (results == null || results.isEmpty) return null;
      return results[0] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<({double price, double changePercent})> fetchQuote(
      String ticker) async {
    final result = await _fetchChart(ticker, '5d');
    if (result == null) return (price: 0.0, changePercent: 0.0);
    final meta = result['meta'] as Map<String, dynamic>? ?? {};
    final candles = _parseCandles(result);

    // 현재가: 실시간 가격 우선, 없으면 마지막 일봉 종가
    final live = (meta['regularMarketPrice'] as num?)?.toDouble();
    final price = live ?? (candles.isNotEmpty ? candles.last.close : 0.0);

    // 전일 종가: 일봉 데이터에서 직전 거래일 종가를 사용
    // (meta['chartPreviousClose']는 5일 전 종가라 등락률이 틀어짐)
    double prevClose;
    if (candles.length >= 2) {
      final last = candles.last.close;
      // 실시간 가격이 마지막 일봉(오늘 종가)보다 갱신됐다면 마지막 종가가 전일 종가
      final liveIsNewer =
          live != null && last != 0 && (price - last).abs() / last > 0.0005;
      prevClose =
          liveIsNewer ? last : candles[candles.length - 2].close;
    } else {
      prevClose = (meta['previousClose'] as num?)?.toDouble() ??
          (meta['chartPreviousClose'] as num?)?.toDouble() ??
          price;
    }

    final change =
        prevClose > 0 ? (price - prevClose) / prevClose * 100 : 0.0;
    return (price: price, changePercent: change);
  }

  List<CandleData> _parseCandles(Map<String, dynamic> result) {
    final timestamps =
        (result['timestamp'] as List?)?.cast<int>() ?? [];
    final quoteList =
        ((result['indicators']?['quote']) as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
    if (quoteList.isEmpty || timestamps.isEmpty) return [];
    final q = quoteList[0];

    double? toDouble(dynamic v) => (v as num?)?.toDouble();

    final opens = (q['open'] as List?)?.map(toDouble).toList() ?? [];
    final highs = (q['high'] as List?)?.map(toDouble).toList() ?? [];
    final lows = (q['low'] as List?)?.map(toDouble).toList() ?? [];
    final closes = (q['close'] as List?)?.map(toDouble).toList() ?? [];
    final volumes = (q['volume'] as List?)?.map(toDouble).toList() ?? [];

    final candles = <CandleData>[];
    double prevClose = 0;

    for (int i = 0; i < timestamps.length; i++) {
      final o = i < opens.length ? opens[i] : null;
      final h = i < highs.length ? highs[i] : null;
      final l = i < lows.length ? lows[i] : null;
      final c = i < closes.length ? closes[i] : null;
      if (o == null || h == null || l == null || c == null) continue;

      final change = prevClose > 0 ? (c - prevClose) / prevClose * 100 : 0.0;
      prevClose = c;

      candles.add(CandleData(
        date: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
        open: o,
        high: h,
        low: l,
        close: c,
        volume: i < volumes.length ? (volumes[i] ?? 0.0) : 0.0,
        changePercent: change,
      ));
    }
    return candles;
  }

  Future<List<CandleData>> fetchMiniChart(String ticker) async {
    final result = await _fetchChart(ticker, '1mo');
    if (result == null) return [];
    final candles = _parseCandles(result);
    return candles.length > 15
        ? candles.sublist(candles.length - 15)
        : candles;
  }

  Future<List<CandleData>> fetchDetailChart(
      String ticker, String range) async {
    final result = await _fetchChart(ticker, range);
    if (result == null) return [];
    return _parseCandles(result);
  }
}
