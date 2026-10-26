import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Line chart of velocity over time, drawn with a CustomPainter (no chart
/// package). Each point is the running velocity after one finished task.
/// A dashed line marks 1.0 ("Spot on").
class VelocityChart extends StatelessWidget {
  const VelocityChart({super.key, required this.values, this.height = 180});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _VelocityChartPainter(
          values: values,
          lineColor: colors.primary,
          gridColor: colors.outlineVariant,
          referenceColor: colors.onSurfaceVariant,
          labelStyle:
              theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ) ??
              TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          dotFill: colors.surface,
        ),
      ),
    );
  }
}

class _VelocityChartPainter extends CustomPainter {
  _VelocityChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.referenceColor,
    required this.labelStyle,
    required this.dotFill,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final Color referenceColor;
  final TextStyle labelStyle;
  final Color dotFill;

  /// Room on the left for the y-axis labels.
  static const double _leftPad = 40;
  static const double _topPad = 8;
  static const double _bottomPad = 8;
  static const double _rightPad = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _ChartScale(values, size);
    _paintGrid(canvas, scale);
    _paintSpotOnLine(canvas, scale);
    _paintVelocityLine(canvas, scale);
  }

  /// Grid lines + y labels on clean values (every 0.25, or 0.5 when the
  /// range is big), like 0.75×, 1×, 1.25×.
  void _paintGrid(Canvas canvas, _ChartScale scale) {
    final chart = scale.chart;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final step = scale.yMax - scale.yMin > 1.5 ? 0.5 : 0.25;
    for (
      var v = (scale.yMin / step).ceil() * step;
      v <= scale.yMax + 1e-9;
      v += step
    ) {
      final y = scale.yFor(v);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(canvas, _label(v), Offset(0, y), alignRight: _leftPad - 6);
    }
  }

  /// Dashed "Spot on" line at 1.0, labelled at the right end.
  void _paintSpotOnLine(Canvas canvas, _ChartScale scale) {
    final chart = scale.chart;
    final refY = scale.yFor(1.0);
    final refPaint = Paint()
      ..color = referenceColor
      ..strokeWidth = 1.5;
    for (var x = chart.left; x < chart.right; x += 8) {
      canvas.drawLine(
        Offset(x, refY),
        Offset(math.min(x + 4, chart.right), refY),
        refPaint,
      );
    }
    _drawText(
      canvas,
      'Spot on',
      Offset(chart.right, refY - 9),
      alignRight: 0,
      color: referenceColor,
    );
  }

  /// The velocity line and a dot for each finished task.
  void _paintVelocityLine(Canvas canvas, _ChartScale scale) {
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(scale.xFor(i), scale.yFor(values[i])),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    // Soft gradient fill under the line.
    final fill = Path.from(path)
      ..lineTo(points.last.dx, scale.chart.bottom)
      ..lineTo(points.first.dx, scale.chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0),
          ],
        ).createShader(scale.chart),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = dotFill);
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// "1×", "1.25×", "0.5×".
  static String _label(double v) {
    var text = v.toStringAsFixed(2);
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$text×';
  }

  /// Draws [text] vertically centered on [at]. With [alignRight], the text's
  /// right edge sits at at.dx + alignRight (or at at.dx when 0).
  void _drawText(
    Canvas canvas,
    String text,
    Offset at, {
    required double alignRight,
    Color? color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: color == null ? labelStyle : labelStyle.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final right = alignRight == 0 ? at.dx : at.dx + alignRight;
    painter.paint(
      canvas,
      Offset(right - painter.width, at.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_VelocityChartPainter old) =>
      old.values != values ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor;
}

/// Maps chart values to pixels. The y range always includes 1.0, snapped to
/// quarters, with a little room above and below.
class _ChartScale {
  _ChartScale(List<double> values, Size size)
    : count = values.length,
      yMin =
          ((math.min(values.reduce(math.min), 1.0) - 0.1) * 4).floorToDouble() /
          4,
      yMax =
          ((math.max(values.reduce(math.max), 1.0) + 0.1) * 4).ceilToDouble() /
          4,
      chart = Rect.fromLTRB(
        _VelocityChartPainter._leftPad,
        _VelocityChartPainter._topPad,
        size.width - _VelocityChartPainter._rightPad,
        size.height - _VelocityChartPainter._bottomPad,
      );

  final int count;
  final double yMin;
  final double yMax;

  /// The plotting area (inside the label padding).
  final Rect chart;

  double yFor(double v) =>
      chart.bottom - (v - yMin) / (yMax - yMin) * chart.height;

  double xFor(int i) =>
      count == 1 ? chart.center.dx : chart.left + i / (count - 1) * chart.width;
}
