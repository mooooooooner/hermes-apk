import 'package:flutter/material.dart';

/// Text styles ported 1:1 from Type.kt (sizes/weights/line heights).
class HermesTypography {
  static const headlineMedium = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 36 / 28,
  );

  static const titleLarge = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 21,
    height: 28 / 21,
  );

  static const titleMedium = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
  );

  static const titleSmall = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 20 / 14,
  );

  static const bodyLarge = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
  );

  static const bodyMedium = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 21 / 14,
  );

  static const bodySmall = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
  );

  static const labelLarge = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 20 / 14,
  );

  static const labelMedium = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 16 / 12,
  );

  static const codeTextStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 19 / 13,
  );
}
