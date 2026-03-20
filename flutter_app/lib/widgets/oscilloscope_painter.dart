import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Draws the oscilloscope for the tuner.
///
/// Layout (vertical centre = amplitude zero):
///   • Waveform drawn from the sample buffer.
///   • A thin white centre line at y = 0.
///   • A green translucent band representing ±5 cents (the "in-tune" zone).
///     The height of this band is fixed at [centsBandFraction] * widget height.
///   • When [cents] is within ±5, the waveform fill is green.
///   • When outside ±5, the fill between the waveform and the green-band
///     edge is red; the part inside the band remains green.
class OscilloscopePainter extends CustomPainter {
  const OscilloscopePainter({
    required this.waveform,
    required this.cents,
    required this.isDetected,
  });

  final Float32List waveform;
  final double cents;
  final bool isDetected;

  /// The fraction of the widget height that represents ±5 cents.
  static const double centsBandFraction = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2.0; // y coordinate of the centre line

    final bandHalfHeight = h * centsBandFraction; // pixels for ±5 cents

    // ------------------------------------------------------------------
    // 1. Background
    // ------------------------------------------------------------------
    final bgPaint = Paint()..color = const Color(0xFF0D1117);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ------------------------------------------------------------------
    // 2. Green ±5-cents band
    // ------------------------------------------------------------------
    final greenBandPaint = Paint()
      ..color = const Color(0x3300CC66)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(0, cy - bandHalfHeight, w, cy + bandHalfHeight),
      greenBandPaint,
    );

    // ------------------------------------------------------------------
    // 3. Centre line
    // ------------------------------------------------------------------
    final centrePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, cy), Offset(w, cy), centrePaint);

    if (waveform.isEmpty || !_hasVisibleWaveform()) return;

    // ------------------------------------------------------------------
    // 4. Build waveform path
    // ------------------------------------------------------------------
    final n = waveform.length;
    final xStep = w / (n - 1);

    // Scale: amplitude ±1 → ±(h * 0.45)
    const amplitudeScale = 0.45;

    // Build the waveform as a list of (x, y) points
    final points = List<Offset>.generate(n, (i) {
      final x = i * xStep;
      final y = cy - waveform[i] * h * amplitudeScale;
      return Offset(x, y.clamp(0.0, h));
    });

    // ------------------------------------------------------------------
    // 5. Determine fill colours based on cents deviation
    // ------------------------------------------------------------------
    final bool inTune = isDetected && cents.abs() <= 5.0;

    // We draw two filled regions:
    //   a) between waveform and centre line
    // When in tune: everything green.
    // When out of tune: area outside the band is red, inside is green.
    _drawFilledWaveform(
      canvas: canvas,
      size: size,
      points: points,
      cy: cy,
      bandHalfHeight: bandHalfHeight,
      inTune: inTune,
    );

    // ------------------------------------------------------------------
    // 6. Waveform line on top
    // ------------------------------------------------------------------
    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < n; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    final linePaint = Paint()
      ..color = !isDetected
          ? const Color(0xFF8B949E)
          : inTune
              ? const Color(0xFF00CC66)
              : const Color(0xFFFF3B30)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    // ------------------------------------------------------------------
    // 7. Cent-band border lines
    // ------------------------------------------------------------------
    final bandBorderPaint = Paint()
      ..color = const Color(0xFF00CC66).withOpacity(0.7)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, cy - bandHalfHeight),
        Offset(w, cy - bandHalfHeight), bandBorderPaint);
    canvas.drawLine(Offset(0, cy + bandHalfHeight),
        Offset(w, cy + bandHalfHeight), bandBorderPaint);
  }

  void _drawFilledWaveform({
    required Canvas canvas,
    required Size size,
    required List<Offset> points,
    required double cy,
    required double bandHalfHeight,
    required bool inTune,
  }) {
    final h = size.height;
    final w = size.width;

    if (!isDetected) {
      final path = _buildFillPath(points, cy, w);
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x338B949E)
            ..style = PaintingStyle.fill);
    } else if (inTune) {
      // Fill everything between waveform and centre – green
      final path = _buildFillPath(points, cy, w);
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x5500CC66)
            ..style = PaintingStyle.fill);
    } else {
      // Split fill: inside band = green, outside band = red
      // Inside band: clip to [cy - bandHalfHeight .. cy + bandHalfHeight]
      canvas.save();
      canvas.clipRect(
          Rect.fromLTRB(0, cy - bandHalfHeight, w, cy + bandHalfHeight));
      final insidePath = _buildFillPath(points, cy, w);
      canvas.drawPath(
          insidePath,
          Paint()
            ..color = const Color(0x5500CC66)
            ..style = PaintingStyle.fill);
      canvas.restore();

      // Outside band: upper region
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, w, cy - bandHalfHeight));
      final outsidePath = _buildFillPath(points, cy, w);
      canvas.drawPath(
          outsidePath,
          Paint()
            ..color = const Color(0x77FF3B30)
            ..style = PaintingStyle.fill);
      canvas.restore();

      // Outside band: lower region
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, cy + bandHalfHeight, w, h));
      final outsidePath2 = _buildFillPath(points, cy, w);
      canvas.drawPath(
          outsidePath2,
          Paint()
            ..color = const Color(0x77FF3B30)
            ..style = PaintingStyle.fill);
      canvas.restore();
    }
  }

  /// Builds a closed path between the waveform and the centre line.
  Path _buildFillPath(List<Offset> points, double cy, double w) {
    final path = Path();
    path.moveTo(0, cy);
    for (final p in points) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(w, cy);
    path.close();
    return path;
  }

  bool _hasVisibleWaveform() {
    for (final sample in waveform) {
      if (sample.abs() > 0.0001) {
        return true;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(OscilloscopePainter old) {
    return true;
  }
}
