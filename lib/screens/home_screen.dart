import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/stock_item.dart';
import '../providers/stock_provider.dart';
import '../widgets/detail_chart_panel.dart';
import '../widgets/stock_card.dart';
import '../widgets/stock_search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _dragFrom;
  int? _dragTo;
  final _feedPos = ValueNotifier<Offset>(Offset.zero);
  OverlayEntry? _overlayEntry;

  // ticker → GlobalKey (stable even after reorder)
  final _cardKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String ticker) =>
      _cardKeys.putIfAbsent(ticker, GlobalKey.new);

  // 다음 자동 갱신까지 남은 초 — "(45s)" 형태로 반환
  String _remainingLabel(StockProvider provider) {
    final next = provider.nextRefreshAt;
    if (next == null) return '';
    final secs = next.difference(DateTime.now()).inSeconds;
    if (secs <= 0) return ' (곧 갱신)';
    return ' ($secs초)';
  }

  // 남은 갱신 시간을 1초마다 다시 그리기 위한 타이머
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _feedPos.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _onPanStart(int index, DragStartDetails d, StockItem stock) {
    setState(() {
      _dragFrom = index;
    });
    _feedPos.value = d.globalPosition;
    _overlayEntry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<Offset>(
        valueListenable: _feedPos,
        builder: (_, pos, _) => Positioned(
          left: pos.dx - 90,
          top: pos.dy - 25,
          child: IgnorePointer(child: _DragFeedback(stock: stock)),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _feedPos.value = d.globalPosition;

    final stocks = context.read<StockProvider>().stocks;
    int? newTo;
    for (int i = 0; i < stocks.length; i++) {
      if (i == _dragFrom) continue;
      final box = _cardKeys[stocks[i].ticker]
          ?.currentContext
          ?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(d.globalPosition)) {
        newTo = i;
        break;
      }
    }
    if (newTo != _dragTo) setState(() => _dragTo = newTo);
  }

  void _onPanEnd(DragEndDetails d) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    final from = _dragFrom;
    final to = _dragTo;
    setState(() {
      _dragFrom = null;
      _dragTo = null;
    });
    if (from != null && to != null && from != to) {
      context.read<StockProvider>().reorderStock(from, to);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        titleSpacing: 12,
        automaticallyImplyLeading: false,
        // 한 줄: (제목) + 갱신 표시 + 검색창 — 화면 폭에 따라 반응형
        title: LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final showTitle = w >= 560; // 좁은 화면에선 제목 숨김
            final showUpdatedText = w >= 420; // 더 좁으면 갱신 텍스트 숨김
            return Row(
              children: [
                if (showTitle) ...[
                  const Text(
                    'US Stock Tracker',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                ],
                Consumer<StockProvider>(
                  builder: (ctx, provider, child) {
                    // 새로고침 버튼: 클릭 시 현재가 즉시 갱신
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: provider.isRefreshing
                          ? null
                          : () => provider.refreshPrices(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (provider.isRefreshing)
                              const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white54),
                              )
                            else
                              const Icon(Icons.refresh,
                                  size: 18, color: Colors.white70),
                            if (showUpdatedText) ...[
                              const SizedBox(width: 6),
                              Text(
                                provider.lastUpdatedAt != null
                                    ? '갱신: ${DateFormat('HH:mm:ss').format(provider.lastUpdatedAt!)}${_remainingLabel(provider)}'
                                    : '로딩 중...',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // 검색창: 남는 공간을 모두 차지 (최대 420)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: const StockSearchBar(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<StockProvider>(
              builder: (ctx, provider, child) {
                final stocks = provider.stocks;
                final hasDetail = provider.selectedStock != null;

                return Column(
                  children: [
                    Expanded(
                      child: stocks.isEmpty
                          ? const _EmptyState()
                          : LayoutBuilder(
                              builder: (ctx, constraints) {
                                final w = constraints.maxWidth;
                                final cols =
                                    w >= 900 ? 3 : (w >= 600 ? 2 : 1);
                                // 비율 대신 고정 높이(mainAxisExtent)를 사용해
                                // 화면 폭과 무관하게 카드 콘텐츠(티커·회사명·
                                // 현재가·등락률)가 항상 카드 안에 들어가게 한다.
                                return GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 122,
                                  ),
                                  itemCount: stocks.length,
                                  itemBuilder: (ctx, i) => StockCard(
                                    key: _keyFor(stocks[i].ticker),
                                    stock: stocks[i],
                                    index: i,
                                    isDragOver: _dragTo == i &&
                                        _dragFrom != i,
                                    isDragging: _dragFrom == i,
                                    onPanStart: (d) =>
                                        _onPanStart(i, d, stocks[i]),
                                    onPanUpdate: _onPanUpdate,
                                    onPanEnd: _onPanEnd,
                                  ),
                                );
                              },
                            ),
                    ),
                    if (hasDetail)
                      const SizedBox(
                          height: 320, child: DetailChartPanel()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final StockItem stock;
  const _DragFeedback({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFFFFB347), width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_indicator,
                    color: Color(0xFFFFB347), size: 14),
                const SizedBox(width: 4),
                Text(
                  stock.ticker,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              stock.companyName,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 48, color: Colors.white12),
          SizedBox(height: 12),
          Text('상단 검색창에서 종목을 추가하세요',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
          SizedBox(height: 4),
          Text('예: AAPL, MSFT, TSLA',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}
