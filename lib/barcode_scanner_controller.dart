
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

typedef AsyncFunction = Future<void> Function();

class BarcodeScannerController {

  AsyncFunction? _pause;
  AsyncFunction? _resume;
  FlashMode _flashMode = FlashMode.auto;
  Future<void> Function(FlashMode mode)? _setFlashMode;
  Future<List<Barcode>> Function(File)? _detectBarcodeFromFile;

  FlashMode get flashMode => _flashMode;

  /// Don't call it
  void attachPause(AsyncFunction callback) {
    if(_pause != null) return;
    _pause = callback;
  }

  /// Don't call it
  void attachResume(AsyncFunction callback) {
    if(_resume != null) return;
    _resume = callback;
  }

  /// Don't call it
  void attachSetFlashMode(Future<void> Function(FlashMode mode) callback) {
    if(_setFlashMode != null) return;
    _setFlashMode = callback;
  }

  /// Don't call it
  void attachDetectBarcodeFromFile(Future<List<Barcode>> Function(File) callback) {
    if(_detectBarcodeFromFile != null) return;
    _detectBarcodeFromFile = callback;
  }

  /// Pause camera and detector, It's auto call while barcode was detected
  Future<void> pause () async => await _pause?.call();

  /// Resume camera and detector
  Future<void> resume() async => await _resume?.call();

  Future<void> setFlashMode(FlashMode mode) async {
    _flashMode = mode;
    await _setFlashMode?.call(mode);
  } 

  
  Future<List<Barcode>> detectBarcodeFromFile(File file) async => 
    _detectBarcodeFromFile == null 
    ? []
    : await _detectBarcodeFromFile!.call(file);

  void dispose() {
    _detectBarcodeFromFile = null;
    _pause = null;
    _resume = null;
    _flashMode = FlashMode.auto;
    _setFlashMode = null;
  }

}
