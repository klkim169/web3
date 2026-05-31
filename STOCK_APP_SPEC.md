# 미국 주식 트래커 앱 개발 명세서

## 프로젝트 개요

미국 주식 종목 리스트를 관리하고, 각 종목의 실시간 가격과 일봉 차트를 시각적으로 확인할 수 있는 Flutter 웹/데스크탑 앱.  
종목 카드는 **화면 너비에 따라 열 수가 자동 조정**되며(넓은 화면 3열 / 좁은 화면 1열), **2분 주기로 현재가를 자동 갱신**한다.  
추가/삭제/정렬된 종목 리스트는 **로컬에 영구 저장**되어 앱을 재실행해도 그대로 복원된다.

- **배포 URL**: https://klkim169.github.io/web3/ (GitHub Pages)
- **데이터 소스**: Yahoo Finance 비공식 API (웹에서는 CORS 프록시 경유)

---

## ✅ 실제 구현 현황 (2026-05 기준)

아래는 초기 설계안 대비 **실제 구현된 내용**이다. 설계와 달라진 부분은 ⚠️ 로 표기.

| 기능 | 상태 | 비고 |
|------|------|------|
| 반응형 그리드 (3/2/1열) | ✅ | `LayoutBuilder` 기반 |
| 2분 자동 갱신 + 갱신 시각 표시 | ✅ | `Timer.periodic` |
| 종목 검색 (티커/회사명) | ✅ | Yahoo Finance search API |
| **한글 종목명 검색** | ✅ 추가 | 마이크론→MU 등 매핑 (⚠️ 설계에 없던 기능) |
| **ETF/인덱스 검색** | ✅ 추가 | QQQ 등 (EQUITY 외 ETF/MUTUALFUND/INDEX 허용) |
| **검색 결과 클릭/Enter 즉시 추가** | ✅ 추가 | "추가" 버튼 제거 |
| 미니 일봉 차트 (최근 15거래일) | ✅ | `CustomPainter` 자체 구현 (⚠️ fl_chart 미사용) |
| 삭제 버튼 | ✅ | |
| **드래그 앤 드롭 정렬** | ✅ 추가 | 종목명 드래그로 순서 변경 + 영구 저장 |
| 하단 상세 차트 (3/6/12개월 탭) | ✅ | `CustomPainter` 캔들스틱 |
| 캔들 클릭 팝업 (날짜/종가/등락/시·고·저가) | ✅ | |
| 종목 리스트 영구 저장 | ✅ | ⚠️ **SQLite → `shared_preferences`(JSON)** 로 변경 (웹 호환) |
| **상단 1줄 레이아웃** | ✅ 변경 | 제목(좌) + 갱신시각 + 검색창(우) 한 줄 |
| **카드 내 차트를 종목명 오른쪽 배치** | ✅ 변경 | 세로 → 가로(Row) 레이아웃 |
| **서비스 워커 캐싱 비활성화** | ✅ 추가 | 배포 후 항상 최신 빌드 로드 |

---

## 기능 요구사항

### 1. 종목 리스트 화면 (메인 화면)

#### 1-1. 상단 검색 및 추가 영역
- 상단 바는 **한 줄**로 구성: 왼쪽 = 앱 제목 / 가운데 = 마지막 갱신 시각 / 오른쪽 = 검색 입력창
- 텍스트 입력 필드: 종목 티커, 영문 회사명, **한글 회사명** 검색 (예: `AAPL`, `Apple`, `마이크론`)
- 검색 결과 드롭다운: `Overlay`로 검색창 바로 아래에 표시 (AppBar 영역에 잘리지 않음)
- **추가 방식**: 검색 결과를 **마우스 클릭** 또는 **Enter**(첫 번째 결과) 시 즉시 리스트에 추가 (별도 "추가" 버튼 없음)
- 이미 추가된 종목은 중복 추가 방지 처리
- 검색 대상: 주식(EQUITY) + ETF + 뮤추얼펀드 + 인덱스

##### 한글 검색 매핑
- Yahoo Finance API는 한글 쿼리를 인식하지 못하므로, 자주 쓰는 한글 종목명을 티커로 변환하는 매핑 테이블을 둔다.
- 예: `마이크론→MU`, `엔비디아→NVDA`, `애플→AAPL`, `샌디스크→SNDK`, `디즈니→DIS` 등 약 80여 개.
- 정확 일치 우선, 없으면 부분 포함 검색. 매핑에 없으면 입력값 그대로 API 호출.

#### 1-2. 종목 카드 그리드 (반응형)
- `LayoutBuilder`로 화면 너비(`constraints.maxWidth`)를 런타임에 측정
- 너비 기준으로 열 수(crossAxisCount)를 동적 결정:

| 화면 너비 | 열 수 | 대상 기기 |
|-----------|-------|-----------|
| ≥ 900px   | 3열   | 데스크탑, 태블릿 가로 |
| 600 ~ 899px | 2열 | 태블릿 세로, 큰 폰 가로 |
| < 600px   | 1열   | 스마트폰 |

- 열 수 변경 시 `GridView`가 자동으로 카드 폭을 재분배 (별도 재시작 불필요)
- 종목 수가 열 수의 배수가 아닐 경우 나머지 칸은 빈 공간으로 처리

**카드 내부 레이아웃 (가로형):** 왼쪽에 종목 정보, 오른쪽에 미니 차트를 배치한다.

```
┌──────────────────────────────────────────────┐
│ ⠿ AAPL                  [미니 일봉 차트]  [🗑] │
│   Apple Inc.            (종목명 오른쪽)        │
│   $312.06                                      │
│   ▲ 2.32%                                      │
└──────────────────────────────────────────────┘
```

각 종목 카드에 표시할 정보:

| 항목 | 위치 | 내용 |
|------|------|------|
| 드래그 핸들 (⠿) + 티커 | 좌상단 | 클릭 → 하단 상세 차트 열기 / 드래그 → 순서 변경 |
| 회사명 | 좌측 | 티커 아래 |
| 현재가 | 좌측 | 실시간 또는 최근 종가 (USD) |
| 등락률 | 좌측 | 전일 대비 % 변화, 상승 시 녹색 / 하락 시 빨간색 |
| 미니 일봉 차트 | **우측 (종목명 오른쪽)** | 최근 3주(15 거래일) 캔들스틱 |
| 삭제 버튼 | 우상단 | 해당 종목을 리스트에서 제거 |

##### 드래그 앤 드롭 정렬
- 종목명/정보 영역(왼쪽)을 마우스로 드래그하면 다른 카드 위치로 이동 가능.
- 드래그 중: 원본 카드는 반투명, 마우스를 따라 플로팅 카드 표시, 드롭 대상 카드에 주황 테두리 하이라이트.
- 드롭 시 해당 위치로 이동하고 나머지 종목 순서는 보존, 변경된 순서는 즉시 로컬에 저장.
- `Draggable`/`DragTarget`은 Flutter Web에서 제스처 충돌이 있어 **`GestureDetector(onPanStart/Update/End)` + `Overlay`** 로 직접 구현.

#### 1-2-1. 2분 주기 자동 가격 갱신
- 앱 실행 시 `Timer.periodic(Duration(minutes: 2), ...)` 으로 타이머 시작
- 매 2분마다 리스트에 등록된 **모든 종목의 현재가 및 등락률만** API 재호출 (일봉 데이터는 갱신 제외)
- 가격 변경 시 카드 숫자에 애니메이션 효과 (선택 사항)
- 앱이 백그라운드 또는 포커스를 잃으면 타이머 일시 정지, 복귀 시 즉시 1회 갱신 후 재시작
- 갱신 중 로딩 인디케이터: 각 카드 우상단에 소형 스피너 표시 (옵션)
- 마지막 갱신 시각을 상단 바에 표시 (예: `최근 갱신: 14:32`)

#### 1-3. 하단 상세 차트 영역
- 종목명 클릭 시 화면 하단에 확장 패널로 표시
- 선택한 종목의 일봉 차트를 상세 표시 (기간: 최소 3개월 ~ 최대 1년)
- 기간 선택 탭: 3개월 / 6개월 / 1년
- 캔들스틱 차트: 시가, 고가, 저가, 종가 표시

#### 1-4. 일봉 클릭 팝업 (상세 차트)
마우스로 캔들스틱 클릭 시 툴팁 표시:
- 날짜
- 현재가 (종가)
- 등락률 (전일 대비 %)
- 시가 / 고가 / 저가 (선택적 표시)

---

## 기술 스택

### Flutter 패키지

**실제 사용 패키지 (pubspec.yaml):**

| 패키지 | 용도 |
|--------|------|
| `provider` | 상태 관리 (`StockProvider`) |
| `http` | REST API 통신 |
| `shared_preferences` | 종목 리스트 영구 저장 (JSON 직렬화) — ⚠️ `sqflite` 대신 채택 (웹 호환) |
| `intl` | 날짜 / 숫자 포맷팅 |
| `dart:async` (Timer) | 2분 주기 자동 갱신 타이머 (내장) |
| `CustomPainter` (Flutter 내장) | 미니/상세 캔들스틱 차트 직접 렌더링 — ⚠️ `fl_chart` 미사용 |

> ⚠️ 설계 단계에서는 `sqflite`(SQLite)와 `fl_chart`를 고려했으나, **웹 타겟 호환성**과 차트 커스터마이징(클릭 팝업·하이라이트) 자유도를 위해 각각 `shared_preferences` + `CustomPainter` 직접 구현으로 변경했다.

### 데이터 소스 — Yahoo Finance 비공식 API (채택)

| 엔드포인트 | 용도 |
|------------|------|
| `query2.finance.yahoo.com/v1/finance/search` | 종목 검색 |
| `query1.finance.yahoo.com/v8/finance/chart/{ticker}` | 현재가 + 일봉(시·고·저·종가) |

- 무료, 별도 API 키 불필요.
- **웹(CORS) 처리**: 웹 빌드에서는 `https://corsproxy.io/?{encoded-url}` 프록시를 경유해 호출 (`kIsWeb` 분기). 네이티브에서는 직접 호출.

---

## 화면 레이아웃

### 넓은 화면 (≥ 900px) — 3열 그리드 (상단 1줄, 차트 우측 배치)

```
┌────────────────────────────────────────────────────────────────────────┐
│  US Stock Tracker         🔄 갱신: 14:32  [🔍 종목 검색 — Enter로 추가]  │  ← 상단 1줄
├────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────┐ ┌────────────────────┐ ┌────────────────────┐  │
│  │⠿AAPL    [미니차트]🗑│ │⠿MSFT    [미니차트]🗑│ │⠿TSLA    [미니차트]🗑│  │
│  │ Apple Inc.          │ │ Microsoft Corp.     │ │ Tesla, Inc.         │  │
│  │ $312.06  ▲2.32%     │ │ $450.24  ▲7.43%     │ │ $435.79  ▲4.29%     │  │
│  └────────────────────┘ └────────────────────┘ └────────────────────┘  │
│  ┌────────────────────┐ ┌────────────────────┐                         │
│  │⠿NVDA    [미니차트]🗑│ │⠿AMZN    [미니차트]🗑│                         │
│  │ NVIDIA Corp.        │ │ Amazon.com, Inc.    │                         │
│  │ $211.14  ▼3.81%     │ │ $270.64  ▲0.81%     │                         │
│  └────────────────────┘ └────────────────────┘                         │
├────────────────────────────────────────────────────────────────────────┤
│  📊 AAPL 상세 차트                              [3개월] [6개월] [1년]    │  ← 종목명 클릭 시
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  캔들스틱 차트 (캔들 클릭 시 팝업: 날짜·종가·등락·시/고/저가)   │    │
│  └────────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────┘
```

- 카드 내부는 **가로형**: 왼쪽 = 드래그핸들/티커/회사명/현재가/등락률, 오른쪽 = 미니 일봉 차트.
- 카드 높이는 `childAspectRatio`로 조절 (현재 다열 3.9 / 1열 5.5 — 초기 대비 컴팩트하게 축소됨).

### 좁은 화면 (< 600px) — 1열 리스트

```
┌──────────────────────────────┐
│ US Stock Tracker  [🔍 검색  ] │  ← 상단 1줄
├──────────────────────────────┤
│ ┌──────────────────────────┐ │
│ │⠿AAPL  Apple [미니차트] 🗑│ │
│ │ $312.06  ▲2.32%          │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │⠿MSFT  MS    [미니차트] 🗑│ │
│ │ $450.24  ▲7.43%          │ │
│ └──────────────────────────┘ │
├──────────────────────────────┤
│ 📊 AAPL 상세 차트 [3M][6M][1Y]│
│ ┌──────────────────────────┐ │
│ │ 캔들스틱 (탭 → 팝업)      │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

## 데이터 모델

### StockItem
```dart
class StockItem {
  final String ticker;        // 티커 심볼 (예: AAPL)
  final String companyName;   // 회사명
  int sortOrder;              // 정렬 순서 (드래그로 변경되므로 final 아님)
  double currentPrice;        // 2분마다 갱신, 저장 안 함
  double changePercent;       // 2분마다 갱신, 저장 안 함
  List<CandleData> miniChart; // 최근 15거래일, 저장 안 함
  bool isLoading;             // 카드별 로딩 상태

  // 저장/복원용 (shared_preferences JSON 직렬화)
  Map<String, dynamic> toMap() => {
    'ticker': ticker,
    'company_name': companyName,
    'sort_order': sortOrder,
  };

  factory StockItem.fromMap(Map<String, dynamic> map) => StockItem(
    ticker: map['ticker'],
    companyName: map['company_name'],
    sortOrder: map['sort_order'],
  );
}
```

### CandleData
```dart
class CandleData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double changePercent; // 전일 대비 등락률
}
```

---

## 로컬 저장 (shared_preferences)

> ⚠️ 설계 단계의 SQLite(`sqflite`)는 **웹 타겟 미지원** 문제로 `shared_preferences` + JSON 직렬화로 변경됨.

- 저장 키: `watchlist_v1`
- 저장 값: `StockItem.toMap()` 목록을 `jsonEncode` 한 문자열
  ```json
  [{"ticker":"AAPL","company_name":"Apple Inc.","sort_order":1}, ...]
  ```
- **티커·회사명·정렬순서만 저장**. 현재가/등락률/차트 데이터는 저장하지 않고 앱 실행 시 API로 새로 로드.
- 변경 시점: 종목 추가(append) / 삭제(remove) / 드래그 정렬(전체 재저장).

```dart
// DatabaseService 주요 메서드
Future<List<StockItem>> loadWatchlist();   // 복원
Future<void> addStock(StockItem stock);     // 추가
Future<void> removeStock(String ticker);    // 삭제
Future<void> saveAll(List<StockItem> s);    // 정렬 결과 전체 저장
```

---

## 파일 구조

```
lib/
├── main.dart                      # Provider 주입, MaterialApp
├── models/
│   ├── stock_item.dart
│   └── candle_data.dart
├── providers/
│   └── stock_provider.dart        # 상태관리 + 2분 타이머 + 드래그 정렬
├── services/
│   ├── stock_api_service.dart     # Yahoo Finance 호출/파싱 + 한글매핑 + CORS 프록시
│   └── database_service.dart      # shared_preferences CRUD
├── screens/
│   └── home_screen.dart           # 상단바(제목+검색) + 그리드 + 드래그 + 상세패널
└── widgets/
    ├── stock_search_bar.dart      # 검색창 + Overlay 드롭다운 (클릭/Enter 추가)
    ├── stock_card.dart            # 종목 카드 (가로형: 정보 좌 / 차트 우)
    ├── mini_candle_chart.dart     # 미니 캔들차트 (CustomPainter)
    └── detail_chart_panel.dart    # 하단 상세 차트 + 클릭 팝업 (CustomPainter)
```
> ⚠️ 설계안의 `candle_tooltip.dart`는 별도 파일 없이 `detail_chart_panel.dart` 내부에 구현됨.

## 구현 단계

### Phase 1 — 기본 골격 ✅
- [x] Flutter 프로젝트 설정 및 패키지 추가
- [x] 데이터 모델 정의 (StockItem, CandleData)
- [x] 반응형 GridView 종목 카드 레이아웃 (3/2/1열)
- [x] 종목 카드 + 미니 캔들차트(CustomPainter) 구현

### Phase 2 — API 연동 ✅
- [x] Yahoo Finance 서비스 구현 (현재가/일봉/검색)
- [x] 종목 검색 API 연동 + 웹 CORS 프록시
- [x] Provider 상태 관리 연결
- [x] `Timer.periodic` 2분 자동 갱신
- [x] 상단 바 마지막 갱신 시각 표시

### Phase 3 — 상세 차트 ✅
- [x] 하단 상세 차트 패널 (CustomPainter 캔들스틱)
- [x] 기간 선택 탭 (3/6/12개월)
- [x] 캔들 클릭 이벤트 처리
- [x] 클릭 팝업 (날짜·종가·등락·시/고/저가)

### Phase 4 — 저장 및 마무리 ✅
- [x] `shared_preferences` 기반 저장 (⚠️ sqflite 대체)
- [x] 종목 추가/삭제 시 저장
- [x] 앱 시작 시 복원 → API로 현재가 일괄 조회
- [x] 에러 처리 및 카드별 로딩 상태

### Phase 5 — 추가 개선 ✅ (설계 이후 반영)
- [x] 한글 종목명 검색 매핑
- [x] ETF/인덱스 검색 허용
- [x] 검색 결과 클릭/Enter 즉시 추가 (Overlay 드롭다운)
- [x] 드래그 앤 드롭 정렬 + 영구 저장
- [x] 상단 1줄 레이아웃 (제목 좌 / 검색 우)
- [x] 카드 내 차트를 종목명 오른쪽 배치
- [x] 등락률 계산 버그 수정 (전일 종가 기준)
- [x] 서비스 워커 캐싱 비활성화
- [x] GitHub Pages 배포

## 주요 구현 포인트

### 반응형 그리드 레이아웃
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final width = constraints.maxWidth;
    final columns = width >= 900 ? 3 : (width >= 600 ? 2 : 1);
    final aspectRatio = columns == 1 ? 5.5 : 3.9; // 현재 컴팩트 비율

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: stocks.length,
      itemBuilder: (context, index) => StockCard(stock: stocks[index]),
    );
  },
)
```

- `constraints.maxWidth`는 부모 위젯의 실제 렌더링 폭 → 기기 회전, 창 크기 조절 시 자동 반응
- `aspectRatio`는 열 수에 따라 달리 적용 (1열일 때는 가로로 긴 카드)
- 중단점 900 / 600 은 `const`로 별도 정의 권장 (`AppBreakpoints.tablet`, `AppBreakpoints.mobile`)

### 2분 주기 자동 갱신
```dart
// StockProvider 또는 HomeScreen initState 에서 초기화
Timer? _refreshTimer;

void startAutoRefresh() {
  _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
    _fetchAllPrices(); // 현재가 및 등락률만 갱신
  });
}

Future<void> _fetchAllPrices() async {
  for (final stock in stocks) {
    final updated = await stockApiService.fetchQuote(stock.ticker);
    // currentPrice, changePercent 만 업데이트
  }
  lastUpdatedAt = DateTime.now();
  notifyListeners();
}

@override
void dispose() {
  _refreshTimer?.cancel();
  super.dispose();
}
```

### 미니 캔들차트 (최근 15거래일)
- **`CustomPainter` 직접 구현** (⚠️ fl_chart 미사용). 고가–저가 심지 + 시·종가 몸통을 캔버스에 직접 그림.
- 상승(종가≥시가) 청록, 하락 빨강. 카드 오른쪽 영역(`Expanded`)에 맞춰 렌더링.

### 상세 차트 + 캔들 클릭 팝업
- `detail_chart_panel.dart`에서 `CustomPainter`로 캔들스틱 + 가격축 + 날짜 라벨 렌더링.
- `GestureDetector(onTapDown)`로 클릭 위치 → 캔들 인덱스 계산 → 해당 캔들 하이라이트 + 툴팁 표시.
- 툴팁: 날짜 / 종가 / 등락률 / 시가 / 고가 / 저가. 화면 경계를 넘지 않도록 위치 보정.

### 로컬 저장 (DatabaseService — shared_preferences)
```dart
class DatabaseService {
  static const _key = 'watchlist_v1';

  Future<List<StockItem>> loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => StockItem.fromMap(m)).toList();
  }

  Future<void> saveAll(List<StockItem> stocks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key,
        jsonEncode(stocks.map((s) => s.toMap()).toList()));
  }
  // addStock / removeStock 은 load → 수정 → saveAll
}
```

### 등락률 계산 (전일 종가 기준) — ⚠️ 버그 수정됨
```dart
// 잘못된 방식: meta['chartPreviousClose']는 5일 range 요청 시 "5일 전" 종가라
//             등락률이 크게 부풀려짐 (예: QQQ 0.37% → 3.33%로 오표시).
// 올바른 방식: 일봉 배열에서 "직전 거래일 종가"를 기준으로 계산.
final candles = _parseCandles(result);
final live = meta['regularMarketPrice']?.toDouble();
final price = live ?? candles.last.close;
double prevClose;
if (candles.length >= 2) {
  final last = candles.last.close;
  final liveIsNewer =
      live != null && last != 0 && (price - last).abs() / last > 0.0005;
  prevClose = liveIsNewer ? last : candles[candles.length - 2].close;
} else {
  prevClose = meta['previousClose']?.toDouble() ?? price;
}
final change = prevClose > 0 ? (price - prevClose) / prevClose * 100 : 0.0;
```

### 드래그 앤 드롭 정렬 (Flutter Web 대응)
- `Draggable`/`DragTarget`은 웹에서 제스처 충돌로 동작 불안정 → **`onPanStart/Update/End` + `Overlay`** 로 직접 구현.
- 각 카드에 `GlobalKey`를 부여해 드래그 중 포인터가 어느 카드 위에 있는지 hit-test로 판정.
- 드롭 시 `reorderStock(from, to)` → 리스트 재배열 + `sortOrder` 재부여 + `saveAll` 저장.

### 검색창 Overlay 드롭다운
- 검색창을 AppBar(상단 1줄)에 배치하면서, 결과 목록은 `CompositedTransformTarget/Follower` + `OverlayEntry`로 띄워 AppBar 클리핑을 회피.
- 결과 항목은 `GestureDetector(HitTestBehavior.opaque)`로 웹에서도 클릭이 확실히 잡히게 처리.

### 등락률 색상 처리
```dart
Color changeColor(double percent) =>
    percent >= 0 ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
```

---

## 배포 (GitHub Pages)

- **URL**: https://klkim169.github.io/web3/  (저장소 `klkim169/web3`, `gh-pages` 브랜치)
- 빌드: `flutter build web --release --base-href "/web3/"`
- 배포: `build/web` 내용을 `gh-pages` 브랜치에 푸시.

### 서비스 워커 캐싱 비활성화 — ⚠️ 중요
Flutter 웹 기본 서비스 워커가 이전 빌드를 캐싱해 **배포해도 갱신이 안 보이는** 문제가 있어, `web/index.html`에서 비활성화:
```html
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations()
      .then(rs => rs.forEach(r => r.unregister()));   // 기존 등록 해제
    if (window.caches?.keys) caches.keys()
      .then(ks => ks.forEach(k => caches.delete(k))); // 캐시 삭제
    navigator.serviceWorker.register =                 // 신규 등록 차단
      () => Promise.reject('service worker disabled');
  }
</script>
```
→ 이후 배포부터는 새로고침 한 번으로 항상 최신 빌드 로드.

---

## 비고

- 무료 API는 요청 수 제한이 있으므로 종목 수가 많으면 갱신 간격/캐싱 고려.
- **2분 갱신 시 종목 수 × API 호출** 발생.
- 거래일 기준 데이터 (주말/공휴일 제외).
- 반응형 중단점: **≥900px 3열 / 600~899px 2열 / <600px 1열**.
- 카드 높이는 `childAspectRatio`로 조절 (다열 3.9 / 1열 5.5).
- 웹 CORS: Yahoo Finance 호출 시 `corsproxy.io` 경유 (`kIsWeb` 분기).

---

## 변경 이력 (Changelog)

| # | 변경 내용 |
|---|-----------|
| 1 | 초기 명세 작성 (3열 그리드, 2분 갱신, 검색/추가, 상세차트, 클릭 팝업) |
| 2 | 1행 3열 그리드 + 2분 자동 갱신 명세화 |
| 3 | 종목 리스트 영구 저장 (당초 SQLite) |
| 4 | 반응형 레이아웃 (해상도별 3/2/1열) |
| 5 | 명세 기반 Flutter 앱 구현 (Yahoo Finance + Provider + CustomPainter) |
| 6 | **저장소를 SQLite → shared_preferences 로 변경** (웹 호환) + GitHub Pages 웹 배포 |
| 7 | ETF/인덱스 검색 허용 (QQQ 등) |
| 8 | 드래그 앤 드롭 정렬 추가 (onPan + Overlay) |
| 9 | 한글 종목명 검색 매핑 (마이크론→MU 등) |
| 10 | 검색 결과 클릭/Enter 즉시 추가 (Overlay 드롭다운) |
| 11 | 카드 차트 높이 축소, 차트를 종목명 오른쪽으로 배치 |
| 12 | 상단을 1줄로 (제목 좌 / 검색 우) |
| 13 | **등락률 계산 버그 수정** (전일 종가 기준 — QQQ 0.37% 정상화) |
| 14 | **서비스 워커 캐싱 비활성화** (배포 후 최신 빌드 즉시 반영) |
