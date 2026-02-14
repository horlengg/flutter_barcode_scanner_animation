import 'package:flutter/material.dart';

class BarcodeScannerAnimation {
  final bool enable;
  final Duration duration;
  final Curve curve;

  const BarcodeScannerAnimation({
    this.enable = true, 
    this.curve = Curves.easeInOutCubic,
    this.duration = const Duration(milliseconds: 250),
  });
}