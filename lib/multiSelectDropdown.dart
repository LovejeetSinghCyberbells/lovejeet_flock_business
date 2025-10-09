import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class CustomMultiSelectDropdown<T> extends StatelessWidget {
  final List<MultiSelectItem<T>> items;
  final String title;
  final String buttonText;
  final Function(List<T>) onConfirm;
  final List<T> initialValue;
  final Color selectedColor;
  final BoxDecoration decoration;
  final TextStyle? titleTextStyle;
  final TextStyle? buttonTextStyle;

  const CustomMultiSelectDropdown({
    super.key,
    required this.items,
    required this.title,
    required this.buttonText,
    required this.onConfirm,
    required this.initialValue,
    required this.selectedColor,
    required this.decoration,
    this.titleTextStyle,
    this.buttonTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    return MultiSelectBottomSheetField<T>(
      items: items,
      title: Text(title, style: titleTextStyle),
      selectedColor: selectedColor,
      buttonText: Text(buttonText, style: buttonTextStyle),
      onConfirm: onConfirm,
      initialValue: initialValue,
      decoration: decoration,
    );
  }
}
