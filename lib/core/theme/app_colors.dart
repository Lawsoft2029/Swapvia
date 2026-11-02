import 'package:flutter/material.dart';

import '../brand/swapvia_logo.dart';

/// Swapvia colours. The brand colours come from the logo so they stay in step.
abstract final class AppColors {
  static const ink = SwapviaLogo.ink;
  static const mint = SwapviaLogo.mint;
  static const white = Colors.white;

  static const lightBackground = Color(0xFFF5F7FA);
  static const lightBorder = Color(0xFFDDE3EB);
  static const lightMutedText = Color(0xFF55657A);

  static const darkBackground = Color(0xFF071427);
  static const darkSurface = ink;
  static const darkBorder = Color(0xFF243A58);
  static const darkMutedText = Color(0xFFA9B6C8);

  static const lightError = Color(0xFFC62828);
  static const darkError = Color(0xFFFF8A80);
}
