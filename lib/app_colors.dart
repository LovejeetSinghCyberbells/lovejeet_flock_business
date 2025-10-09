import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color.fromRGBO(255, 130, 16, 1);

  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black;
}
