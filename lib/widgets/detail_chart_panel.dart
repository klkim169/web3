import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/candle_data.dart';
import '../providers/stock_provider.dart';

class DetailChartPanel extends StatefulWidget {
  const DetailChartPanel({super.key});

  @override
  State<DetailChartPanel> createState() => _DetailChartPanelState();
}

class _DetailChartPanelState extends State<DetailChartPanel> {
  CandleData? _tooltipCandle;
  Offset? _tooltipPos;

  static const _ranges = [
    ('3개월', '3mo'),
    ('6개월', '6mo'),
    ('1년', '1y'),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (_, provider, _) {
        final stock = provider.selectedStock;
        if (stock == null) return const SizedBox.shrink();

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Column(
            children: [
              _buildHeader(provider, stock.ticker),
              Expanded(child: _buildChartArea(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(StockProvider provider, String ticker) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Row(
        children: [
          Text(
            '  $ticker 상세 차트',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          ..._ranges.map((r) {
            final isSelected = provider.selectedRange == r.$2;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _tooltipCandle = null;
                    _tooltipPos = null;
                  });
                  provider.setRange(r.$2);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF388BFD) : Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r.$1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => provider.selectStock(null),
            child: const Icon(Icons.close, color: Colors.white38, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea(StockProvider provider) {
    if (provider.detailChart.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
      );
    }
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onTapDown: (d) => _handleTap(d.localPosition, provider.detailChart, size),
          child: Stack(
            children: [
              CustomPaint(
                painter: _CandleChartPainter(
                  candles: provider.detailChart,
                  selectedCandle: _tooltipCandle,
                ),
                size: size,
              ),
              if (_tooltipCandle != null && _tooltipPos != null)
                _buildTooltip(_tooltipCandle!, _tooltipPos!, size),
            ],
          ),
        );
      },
    );
  }

  void _handleTap(Offset pos, List<CandleData> candles, Size size) {
    const leftPad = _CandleChartPainter.leftPad;
    const rightPad = _CandleChartPainter.rightPad;
    final chartW = size.width - leftPad - rightPad;
    if (chartW <= 0) return;
    final cw = chartW / candles.length;
    final idx = ((pos.dx - leftPad) / cw).floor();
    if (idx < 0 || idx >= candles.length) {
      setState(() {
        _tooltipCandle = null;
        _tooltipPos = null;
      });
      return;
    }
    setState(() {
      if (_tooltipCandle == candles[idx]) {
        _tooltipCandle = null;
        _tooltipPos = null;
      } else {
        _tooltipCandle = candles[idx];
        _tooltipPos = pos;
      }
    });
  }

  Widget _buildTooltip(CandleData candle, Offset pos, Size containerSize) {
    const tooltipW = 160.0;
    const tooltipH = 130.0;
    final isUp = candle.changePercent >= 0;
    final changeColor = isUp ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
    final fmt = NumberFormat('#,##0.00');

    double left = pos.dx + 10;
    double top = pos.dy - tooltipH - 10;
    if (left + tooltipW > containerSize.width) left = pos.dx - tooltipW - 10;
    if (top < 0) top = pos.dy + 10;
    left = left.clamp(4, containerSize.width - tooltipW - 4);
    top = top.clamp(4, containerSize.height - tooltipH - 4);

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: tooltipW,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('yyyy-MM-dd').format(candle.date),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            _row('종가', '\$${fmt.format(candle.close)}', Colors.white),
            _row(
              '등락',
              '${isUp ? '+' : ''}${candle.changePercent.toStringAsFixed(2)}%',
              changeColor,
            ),
            _row('시가', '\$${fmt.format(candle.open)}', Colors.white70),
            _row('고가', '\$${fmt.format(candle.high)}', const Color(0xFF26A69A)),
            _row('저가', '\$${fmt.format(candle.low)}', const Color(0xFFEF5350)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CandleChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final CandleData? selectedCandle;

  static const leftPad = 8.0;
  static const rightPad = 52.0;
  static const topPad = 8.0;
  static const bottomPad = 24.0;

  const _CandleChartPainter({required this.candles, this.selectedCandle});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (chartW <= 0 || chartH <= 0) return;

    final minVal = candles.map((c) => c.low).reduce(math.min);
    final maxVal = candles.map((c) => c.high).reduce(math.max);
    final range = (maxVal - minVal) * 1.05;
    if (range == 0) return;
    final adjMin = minVal - range * 0.025;

    double toX(int i) => leftPad + (i + 0.5) * chartW / candles.length;
    double toY(double v) => topPad + (1 - (v - adjMin) / range) * chartH;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    const gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final v = adjMin + range * i / gridSteps;
      final y = toY(v);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);

      // Price labels
      final tp = TextPainter(
        text: TextSpan(
          text: '\$${v.toStringAsFixed(0)}',
          style: const TextStyle(color: Colors.white30, fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - rightPad + 4, y - tp.height / 2));
    }

    // Candles
    final cw = chartW / candles.length;
    final bw = (cw * 0.6).clamp(1.5, 14.0);

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isUp = c.close >= c.open;
      final isSelected = c == selectedCandle;

      Color color = isUp ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
      if (isSelected) color = Colors.amber;

      final x = toX(i);

      // Highlight selected
      if (isSelected) {
        canvas.drawLine(
          Offset(x, topPad),
          Offset(x, topPad + chartH),
          Paint()
            ..color = Colors.white12
            ..strokeWidth = 1.0,
        );
      }

      // Wick
      canvas.drawLine(
        Offset(x, toY(c.high)),
        Offset(x, toY(c.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1.0,
      );

      // Body
      final top = toY(math.max(c.open, c.close));
      final bottom = toY(math.min(c.open, c.close));
      canvas.drawRect(
        Rect.fromLTWH(x - bw / 2, top, bw, math.max(1.5, bottom - top)),
        Paint()..color = color,
      );
    }

    // Date labels (every ~20 candles)
    final step = math.max(1, (candles.length / 6).round());
    for (int i = 0; i < candles.length; i += step) {
      final tp = TextPainter(
        text: TextSpan(
          text: DateFormat('MM/dd').format(candles[i].date),
          style: const TextStyle(color: Colors.white30, fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(toX(i) - tp.width / 2, size.height - bottomPad + 4),
      );
    }
  }

  @override
  bool shouldRepaint(_CandleChartPainter old) =>
      old.candles != candles || old.selectedCandle != selectedCandle;
}
