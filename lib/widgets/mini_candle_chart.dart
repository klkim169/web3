import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/candle_data.dart';

class MiniCandleChart extends StatelessWidget {
  final List<CandleData> candles;

  const MiniCandleChart({super.key, required this.candles});

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return const Center(
        child: Text('데이터 없음', style: TextStyle(color: Colors.white24, fontSize: 10)),
      );
    }
    return CustomPaint(
      painter: _MiniCandlePainter(candles),
      size: Size.infinite,
    );
  }
}

class _MiniCandlePainter extends CustomPainter {
  final List<CandleData> candles;

  _MiniCandlePainter(this.candles);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.width <= 0 || size.height <= 0) return;

    final minVal = candles.map((c) => c.low).reduce(math.min);
    final maxVal = candles.map((c) => c.high).reduce(math.max);
    final range = maxVal - minVal;
    if (range == 0) return;

    final cw = size.width / candles.length;
    final bw = (cw * 0.6).clamp(1.0, 8.0);

    double toY(double v) => size.height - (v - minVal) / range * size.height;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isUp = c.close >= c.open;
      final color = isUp ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
      final x = i * cw + cw / 2;

      canvas.drawLine(
        Offset(x, toY(c.high)),
        Offset(x, toY(c.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1.0,
      );

      final top = toY(math.max(c.open, c.close));
      final bottom = toY(math.min(c.open, c.close));
      canvas.drawRect(
        Rect.fromLTWH(x - bw / 2, top, bw, math.max(1.0, bottom - top)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniCandlePainter old) => old.candles != candles;
}
