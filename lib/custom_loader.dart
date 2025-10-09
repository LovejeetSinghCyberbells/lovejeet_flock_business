// custom_loader.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // if using Lottie

class CustomLoader extends StatelessWidget {
  final double size;

  const CustomLoader({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/Bird_Full_Eye_Blinking.gif', // or use Image.asset / CircularProgressIndicator
        width: size,
        height: size,
      ),
    );
  }
}
