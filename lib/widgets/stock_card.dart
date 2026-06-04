import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/stock_item.dart';
import '../providers/stock_provider.dart';
import 'mini_candle_chart.dart';

class StockCard extends StatelessWidget {
  final StockItem stock;
  final int index;
  final bool isDragOver;
  final bool isDragging;
  final void Function(Offset globalPos) onDragStart;
  final void Function(Offset globalPos) onDragUpdate;
  final VoidCallback onDragEnd;

  const StockCard({
    super.key,
    required this.stock,
    required this.index,
    required this.isDragOver,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StockProvider>();
    final isSelected = context.select<StockProvider, bool>(
        (p) => p.selectedStock?.ticker == stock.ticker);
    final isUp = stock.changePercent >= 0;
    final changeColor = isUp ? const Color(0xFF26A69A) : const Color(0xFFEF5350);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isDragging
            ? const Color(0xFF0D1117)
            : isSelected
                ? const Color(0xFF1C2333)
                : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDragOver
              ? const Color(0xFFFFB347)
              : isSelected
                  ? const Color(0xFF388BFD)
                  : Colors.white12,
          width: isDragOver || isSelected ? 2.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Opacity(
        opacity: isDragging ? 0.3 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 종목명 + 현재가 + 등락률 (드래그 / 탭 영역)
            SizedBox(
              width: 150,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => provider.selectStock(stock),
                // 길게 눌러 잡은 뒤 드래그 → 순서 이동.
                // (즉시 패닝은 모바일에서 GridView 스크롤에 가로채여
                //  드래그가 시작되지 않으므로 롱프레스로 처리한다.)
                onLongPressStart: (d) => onDragStart(d.globalPosition),
                onLongPressMoveUpdate: (d) => onDragUpdate(d.globalPosition),
                onLongPressEnd: (_) => onDragEnd(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.drag_indicator,
                              color: Colors.white24, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            stock.ticker,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock.companyName,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 8),
                      if (!stock.isLoading) ...[
                        Text(
                          '\$${NumberFormat('#,##0.00').format(stock.currentPrice)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: changeColor.withAlpha(38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${isUp ? '▲' : '▼'} ${stock.changePercent.abs().toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: changeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 오른쪽: 일봉 미니 차트
            Expanded(
              child: SizedBox.expand(
                child: stock.isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white38),
                        ),
                      )
                    : MiniCandleChart(candles: stock.miniChart),
              ),
            ),
            // 삭제 버튼
            GestureDetector(
              onTap: () => provider.removeStock(stock.ticker),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.delete_outline,
                    color: Colors.white30, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
