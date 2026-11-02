import 'package:flutter/material.dart';

/// Swapvia logo: an "S" formed by two arrows moving in opposite directions,
/// one for money going out and one for money coming in. Drawn in code so it
/// is sharp at any size.
class SwapviaLogo extends StatelessWidget {
  final double size;
  final bool showTile;

  /// Colours for the upper arrow when there is no tile behind the mark.
  final Color? markColor;

  /// Scale of the mark inside its box. Android adaptive icons need a smaller
  /// mark because launchers crop the outer edge.
  final double markScale;

  const SwapviaLogo({
    super.key,
    this.size = 96,
    this.showTile = true,
    this.markColor,
    this.markScale = 0.8,
  });

  static const ink = Color(0xFF0B1F3A);
  static const mint = Color(0xFF2FE6A7);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SwapviaLogoPainter(
          showTile: showTile,
          upperColor: markColor ?? (showTile ? Colors.white : ink),
          markScale: markScale,
        ),
      ),
    );
  }
}

class SwapviaLogoPainter extends CustomPainter {
  final bool showTile;
  final Color upperColor;
  final double markScale;
  final bool squareTile;

  SwapviaLogoPainter({
    required this.showTile,
    required this.upperColor,
    this.markScale = 0.8,
    this.squareTile = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 140); // designed on a 140 grid
    if (showTile) {
      const tile = Rect.fromLTWH(0, 0, 140, 140);
      final paint = Paint()..color = SwapviaLogo.ink;
      if (squareTile) {
        canvas.drawRect(tile, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(tile, const Radius.circular(32)),
          paint,
        );
      }
    }
    canvas.translate(70, 70);
    canvas.scale(markScale);
    canvas.translate(-70, -70);
    _arrow(canvas, upperColor, upper: true);
    _arrow(canvas, SwapviaLogo.mint, upper: false);
  }

  /// The lower arrow is the upper arrow turned 180 degrees about the centre.
  void _arrow(Canvas canvas, Color color, {required bool upper}) {
    canvas.save();
    if (!upper) {
      canvas.translate(70, 70);
      canvas.rotate(3.14159265358979);
      canvas.translate(-70, -70);
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    canvas.drawPath(
      Path()
        ..moveTo(70, 70)
        ..arcToPoint(
          const Offset(70, 28),
          radius: const Radius.circular(21),
          largeArc: false,
        )
        ..lineTo(88, 28),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(86, 10)
        ..lineTo(112, 28)
        ..lineTo(86, 46)
        ..close(),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SwapviaLogoPainter old) =>
      old.showTile != showTile ||
      old.upperColor != upperColor ||
      old.markScale != markScale ||
      old.squareTile != squareTile;
}
