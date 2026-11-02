// Renders the master PNGs used for every platform icon.
// Run: flutter test tool/generate_brand_assets_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swapvia/core/brand/swapvia_logo.dart';

Future<void> _render(String name, SwapviaLogoPainter painter) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(size, size));
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File('assets/brand/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate brand assets', () async {
    await _render(
      'logo_rounded',
      SwapviaLogoPainter(showTile: true, upperColor: Colors.white),
    );
    // iOS rejects icons with transparency, and rounds the corners itself.
    await _render(
      'icon_square',
      SwapviaLogoPainter(
        showTile: true,
        upperColor: Colors.white,
        squareTile: true,
      ),
    );
    await _render(
      'adaptive_foreground',
      SwapviaLogoPainter(
        showTile: false,
        upperColor: Colors.white,
        markScale: 0.56,
      ),
    );
    await _render(
      'mark_on_light',
      SwapviaLogoPainter(showTile: false, upperColor: SwapviaLogo.ink),
    );
  });
}
