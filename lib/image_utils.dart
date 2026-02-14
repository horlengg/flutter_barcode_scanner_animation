
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;



class ImageUtils {


  static Future<Uint8List?> cropImage({
    required CameraImage cameraImage,
    required Rect cropRect,
    int rotation = 0,
    bool flipHorizontal = false,
  }) async {
    try {
      final imageBytes = await captureFrameAsPng(
        cameraImage: cameraImage,
        rotation: rotation,
        flipHorizontal: flipHorizontal,
      );

      if (imageBytes == null) {
        log('Failed to convert camera image to PNG');
        return null;
      }

      // Decode the image
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        log('Failed to decode image');
        return imageBytes;
      }

      // Ensure crop rect is within image bounds
      final int cropX = cropRect.left.toInt().clamp(0, originalImage.width - 1);
      final int cropY = cropRect.top.toInt().clamp(0, originalImage.height - 1);
      final int cropWidth = cropRect.width.toInt().clamp(1, originalImage.width - cropX);
      final int cropHeight = cropRect.height.toInt().clamp(1, originalImage.height - cropY);

      // Validate crop dimensions
      if (cropWidth <= 0 || cropHeight <= 0) {
        log('Invalid crop dimensions');
        return imageBytes;
      }

      // Crop the image
      img.Image croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Encode back to bytes
      return Uint8List.fromList(img.encodePng(croppedImage));
    } catch (e) {
      log('Error cropping image: $e');
      return null;
    }
  }

  static Future<Uint8List?> captureFrameAsPng({
    required CameraImage cameraImage,
    int rotation = 0,
    bool flipHorizontal = false,
  }) async {
    try {
      
      img.Image image;

      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        image = _convertYUV420ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        image = _convertBGRA8888ToImage(cameraImage);
      } else {
        log('Unsupported image format: ${cameraImage.format.group}');
        return null;
      }

      if (rotation != 0 && Platform.isAndroid) {
        image = img.copyRotate(image, angle: rotation);
      }

      if (flipHorizontal) {
        image = img.flipHorizontal(image);
      }
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      log('Error converting camera image to PNG: $e');
      return null;
    }
  }

  // Convert YUV420 (Android) to Image
  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final int yRowStride = cameraImage.planes[0].bytesPerRow;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    final Uint8List yPlane = cameraImage.planes[0].bytes;
    final Uint8List uPlane = cameraImage.planes[1].bytes;
    final Uint8List vPlane = cameraImage.planes[2].bytes;

    final Uint8List rgbBytes = Uint8List(width * height * 3);

    int rgbIndex = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int uvRow = y ~/ 2;
        final int uvCol = x ~/ 2;
        final int uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride;

        if (yIndex >= yPlane.length || 
            uvIndex >= uPlane.length || 
            uvIndex >= vPlane.length) {
          rgbBytes[rgbIndex++] = 0;
          rgbBytes[rgbIndex++] = 0;
          rgbBytes[rgbIndex++] = 0;
          continue;
        }

        final int yValue = yPlane[yIndex];
        final int uValue = uPlane[uvIndex];
        final int vValue = vPlane[uvIndex];

        final int c = yValue - 16;
        final int d = uValue - 128;
        final int e = vValue - 128;

        int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        rgbBytes[rgbIndex++] = r;
        rgbBytes[rgbIndex++] = g;
        rgbBytes[rgbIndex++] = b;
      }
    }

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbBytes.buffer,
      numChannels: 3,
    );
  }

  // Convert BGRA8888 (iOS) to Image
  static img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    // BGRA8888 has only 1 plane
    final Uint8List bytes = cameraImage.planes[0].bytes;
    
    // Convert BGRA to RGB
    final Uint8List rgbBytes = Uint8List(width * height * 3);
    int rgbIndex = 0;
    
    for (int i = 0; i < bytes.length; i += 4) {
      // BGRA format: B, G, R, A
      final int b = bytes[i];
      final int g = bytes[i + 1];
      final int r = bytes[i + 2];
      // Skip alpha channel (bytes[i + 3])
      
      rgbBytes[rgbIndex++] = r;
      rgbBytes[rgbIndex++] = g;
      rgbBytes[rgbIndex++] = b;
    }

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbBytes.buffer,
      numChannels: 3,
    );
  }

  static InputImage? buildAndroidInputImage(CameraImage image, InputImageRotation rotation) {
    final int width = image.width;
    final int height = image.height;

    if (image.planes.length == 1) {
      final bytes = image.planes[0].bytes;
      
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
    
    // For old flutter version
    if (image.planes.length < 3) {
      print("Unexpected number of planes: ${image.planes.length}");
      return null;
    }

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;

    final WriteBuffer buffer = WriteBuffer();

    for (int row = 0; row < height; row++) {
      final int offset = row * yRowStride;
      final int end = offset + width;
      if (end <= yPlane.bytes.length) {
        buffer.putUint8List(yPlane.bytes.sublist(offset, end));
      }
    }
    
    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int offset = row * uvRowStride + col * uvPixelStride;
        if (offset < vPlane.bytes.length && offset < uPlane.bytes.length) {
          buffer.putUint8(vPlane.bytes[offset]);
          buffer.putUint8(uPlane.bytes[offset]);
        }
      }
    }

    final bytes = buffer.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      ),
    );
  }

  static InputImage? buildIOSInputImage(CameraImage image, InputImageRotation rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    
    if (format != InputImageFormat.bgra8888 || image.planes.length != 1) {
      log('iOS format issue: format=$format, planes=${image.planes.length}');
      return null;
    }
    
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

}


