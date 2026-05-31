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

  @override
  void dispose() {
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
        titleSpacing: 16,
        // 왼쪽: 제목
        title: const Text(
          'US Stock Tracker',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        // 오른쪽: 갱신 시각 + 검색창 (한 줄)
        actions: [
          Consumer<StockProvider>(
            builder: (ctx, provider, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.isRefreshing)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white38),
                    )
                  else
                    const Icon(Icons.autorenew,
                        size: 15, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    provider.lastUpdatedAt != null
                        ? '갱신: ${DateFormat('HH:mm').format(provider.lastUpdatedAt!)}'
                        : '로딩 중...',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 14),
          const SizedBox(width: 420, child: StockSearchBar()),
          const SizedBox(width: 16),
        ],
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
                                final ratio = cols == 1 ? 5.5 : 3.9;
                                return GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: ratio,
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
