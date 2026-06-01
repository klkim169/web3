import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_item.dart';

/// 기기 간 종목 리스트 동기화 (kvdb.io 공용 버킷).
///
/// - 모든 기기가 동일한 버킷을 바라보므로 휴대폰/PC 리스트가 일치한다.
/// - 네트워크 실패 시 null/false 를 반환 → 호출 측에서 로컬 캐시로 폴백.
/// - kvdb.io 는 CORS(`Access-Control-Allow-Origin: *`, PUT 허용)를 지원해
///   웹 브라우저에서도 직접 호출 가능(프록시 불필요).
class CloudSyncService {
  // 공용 버킷 (klkim169@gmail.com). 쓰기에는 이메일 1회 인증 필요.
  static const _url = 'https://kvdb.io/Jct5Yb7tY5iiaPS74LHLMD/watchlist';

  /// 클라우드에서 종목 리스트 조회.
  /// - 200: 파싱한 리스트 반환 (빈 배열이면 "명시적 빈 목록"으로 권위 있음)
  /// - 404: null (아직 클라우드에 쓰인 적 없음 → 로컬 유지 + 로컬을 업로드)
  /// - 그 외/예외: null (실패 → 로컬 유지)
  Future<List<StockItem>?> fetch() async {
    try {
      // kvdb는 GET을 장기 캐시(HIT)하므로 타임스탬프 쿼리로 캐시를 우회해
      // 항상 최신 값을 받는다. (캐시된 값이면 다른 기기 변경이 안 보임)
      final url = '$_url?t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(
        Uri.parse(url),
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));
      // 404 = 키가 아직 없음(인증 전/최초). 로컬을 덮어쓰지 않도록 null 반환.
      if (res.statusCode != 200) return null;
      if (res.body.trim().isEmpty) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return null;
      return decoded
          .map((m) => StockItem.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 클라우드에 종목 리스트 저장. 성공 여부 반환.
  Future<bool> save(List<StockItem> stocks) async {
    try {
      final body = jsonEncode(stocks.map((s) => s.toMap()).toList());
      final res = await http
          .put(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
