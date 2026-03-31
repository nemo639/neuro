import 'dart:math';
import 'package:flutter/material.dart';

/// Responsive sizing utility for consistent UI across all devices.
///
/// Design baseline: 375 x 812 (iPhone X / Samsung S10-class).
/// All hardcoded sizes should be replaced with calls to this class.
///
/// Usage:
///   final r = Responsive(context);
///   Container(width: r.w(110), height: r.h(44), ...)
///   Text('Hello', style: TextStyle(fontSize: r.sp(16)))
class Responsive {
  final double _screenWidth;
  final double _screenHeight;
  final double _textScale;

  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  Responsive(BuildContext context)
      : _screenWidth = MediaQuery.of(context).size.width,
        _screenHeight = MediaQuery.of(context).size.height,
        _textScale = MediaQuery.of(context).textScaler.scale(1.0);

  /// Scale by width ratio (for widths, horizontal padding, border radius)
  double w(double size) => size * (_screenWidth / _designWidth);

  /// Scale by height ratio (for heights, vertical padding)
  double h(double size) => size * (_screenHeight / _designHeight);

  /// Scale for font sizes — uses width ratio but clamped to avoid extremes.
  /// Also neutralizes the system text scale factor so fonts stay consistent.
  double sp(double size) {
    final scaled = size * (_screenWidth / _designWidth);
    // Clamp between 0.8x and 1.2x of original to prevent tiny/huge text
    final clamped = scaled.clamp(size * 0.8, size * 1.25);
    // Neutralize system text scaling (Flutter already applies it)
    return clamped / _textScale;
  }

  /// Scale using the smaller of width/height ratios (for squares, icons, circles)
  double dp(double size) {
    final ratio = min(_screenWidth / _designWidth, _screenHeight / _designHeight);
    return size * ratio;
  }

  /// Screen width
  double get screenWidth => _screenWidth;

  /// Screen height
  double get screenHeight => _screenHeight;

  /// Horizontal padding that adapts to screen width
  double get horizontalPadding => w(24);

  /// Whether this is a small screen (< 360dp wide)
  bool get isSmall => _screenWidth < 360;

  /// Whether this is a large screen (> 410dp wide)
  bool get isLarge => _screenWidth > 410;
}
