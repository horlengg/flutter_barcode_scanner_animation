
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class CoordinatesTranslator {

  double translateX(
    double x,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * canvasSize.width / imageSize.height;
      case InputImageRotation.rotation270deg:
        return canvasSize.width -
            x *
                canvasSize.width /
                (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        switch (cameraLensDirection) {
          case CameraLensDirection.back:
            return x * canvasSize.width / imageSize.width;
          default:
            return canvasSize.width - x * canvasSize.width / imageSize.width;
        }
    }
  }

  double translateY(
    double y,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y *
            canvasSize.height / imageSize.width;
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return y * canvasSize.height / imageSize.height;
    }
  }
  /// Calculate frame position and size 
  static Rect calculateFrameRect(
    Rect rect,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
    Size layoutSize,
  ) {
    final translator = CoordinatesTranslator();
    final left = translator.translateX(
      rect.left,
      layoutSize,
      imageSize,
      rotation,
      cameraLensDirection,
    );
    final top = translator.translateY(
      rect.top,
      layoutSize,
      imageSize,
      rotation,
      cameraLensDirection,
    );
    final right = translator.translateX(
      rect.right,
      layoutSize,
      imageSize,
      rotation,
      cameraLensDirection,
    );
    final bottom = translator.translateY(
      rect.bottom,
      layoutSize,
      imageSize,
      rotation,
      cameraLensDirection,
    );

    return Rect.fromLTRB(left, top, right, bottom);
  }
  
}




// import 'dart:io';
// import 'dart:ui';

// import 'package:camera/camera.dart';
// import 'package:google_mlkit_commons/google_mlkit_commons.dart';

// double translateX(
//   double x,
//   Size canvasSize,
//   Size imageSize,
//   InputImageRotation rotation,
//   CameraLensDirection cameraLensDirection,
// ) {
//   switch (rotation) {
//     case InputImageRotation.rotation90deg:
//       return x *
//           canvasSize.width /
//           (Platform.isIOS ? imageSize.width : imageSize.height);
//     case InputImageRotation.rotation270deg:
//       return canvasSize.width -
//           x *
//               canvasSize.width /
//               (Platform.isIOS ? imageSize.width : imageSize.height);
//     case InputImageRotation.rotation0deg:
//     case InputImageRotation.rotation180deg:
//       switch (cameraLensDirection) {
//         case CameraLensDirection.back:
//           return x * canvasSize.width / imageSize.width;
//         default:
//           return canvasSize.width - x * canvasSize.width / imageSize.width;
//       }
//   }
// }

// double translateY(
//   double y,
//   Size canvasSize,
//   Size imageSize,
//   InputImageRotation rotation,
//   CameraLensDirection cameraLensDirection,
// ) {
//   switch (rotation) {
//     case InputImageRotation.rotation90deg:
//     case InputImageRotation.rotation270deg:
//       return y *
//           canvasSize.height /
//           (Platform.isIOS ? imageSize.height : imageSize.width);
//     case InputImageRotation.rotation0deg:
//     case InputImageRotation.rotation180deg:
//       return y * canvasSize.height / imageSize.height;
//   }
// }

