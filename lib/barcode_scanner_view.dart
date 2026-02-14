// barcode_scanner_view.dart
// Author    : Ly Houleng
// Portfolio : https://horleng.vercel.app


import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner_animation/barcode_scanner_animation.dart';
import 'package:flutter_barcode_scanner_animation/barcode_scanner_controller.dart';
import 'package:flutter_barcode_scanner_animation/coordinates_translator.dart';
import 'package:flutter_barcode_scanner_animation/image_utils.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class BarcodeScannerView extends StatefulWidget {

  const BarcodeScannerView({
    super.key,
    required this.controller,
    required this.onDetected,
    required this.onCompleted,
    this.barcodeScanFrameSize = const Size(200, 200),
    this.animation = const BarcodeScannerAnimation(),
    this.minBarcodeSizeThreshold = .01, // 1%
    this.enableAutoZoom = true,
    this.children = const [],
    this.barcodeFrameViewBuilder,
    this.barcodeFramePadding = 10.0
  });


  /// trigger when barcode begin detected
  /// Notic : Camera is pause by default while barcode begin detected
  final Function(List<Barcode> barcode) onDetected;


  /// trigger when animation capture barcode complete
  /// this callback not trigger if disable animation
  final Function() onCompleted;
  /// 
  final BarcodeScannerController controller;

  /// Scan area size for center barcode when scan multi barcode
  final Size barcodeScanFrameSize; 


  /// Animation config, enable by default if you don't want animation set enable : false
  final BarcodeScannerAnimation animation; 

  /// Threshold for zoom barcode
  final double minBarcodeSizeThreshold; 

  /// For auto zoom when barcode size is too small base on minBarcodeSizeThreshold
  /// for increase accuracy
  final bool enableAutoZoom;

  /// Custom overlay
  final List<Widget> children;

  // 
  final double barcodeFramePadding;

  final Widget Function(BuildContext context,Rect rect,Barcode? barcode)? barcodeFrameViewBuilder;

  @override
  State<BarcodeScannerView> createState() => BarcodeScannerViewState();
}

class BarcodeScannerViewState extends State<BarcodeScannerView> with SingleTickerProviderStateMixin {

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  final _cameraIndex = 0;
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // Reactive state
  final _frameRect = ValueNotifier<Rect?>(null);
  final _barcodeFrameBytes = ValueNotifier<Uint8List?>(null);
  final _focusPointVisible = ValueNotifier<bool>(false);
  final _setFocusPoint = ValueNotifier<Offset>(Offset.zero);
  
  bool _isProcessing = false;
  Barcode? _barcode;
  bool _isBarcodeCaptured = false;
  InputImageRotation? _inputImageRotation;
  Size? _cameraLayoutSize;
  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  Timer? _hideFocusPointTimer;
  bool _isPaused = false;
  

  late AnimationController _focusAnimationController;
  late Animation<double> _scaleAnimation;
  
  late final BarcodeScanner _barcodeScanner;

  @override
  void initState() {
    super.initState();
    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    _initialize();
  }

  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    _startLiveFeed(_cameras[_cameraIndex]);
    _focusAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.3, end: 1.0).animate(
      CurvedAnimation(parent: _focusAnimationController, curve: Curves.easeOut)
    );
  }

  @override
  void dispose() {

    _cameraController?.dispose();
    _barcodeScanner.close();
    _hideFocusPointTimer?.cancel();
    _barcodeFrameBytes.dispose();
    _frameRect.dispose();
    _focusPointVisible.dispose();
    _setFocusPoint.dispose();
    widget.controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    log("Rebuild()...");

    if (_cameras.isEmpty ||
        _cameraController == null ||
        _cameraController?.value.isInitialized == false
    ) {
      return Center(
        child: CircularProgressIndicator()
      );
    }

    final size = MediaQuery.of(context).size;
    final scale = 1 / (_cameraController!.value.aspectRatio * size.aspectRatio);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview with smooth scaling
        Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTapUp: _onCameraViewTap,
            child: Center(
              child: CameraPreview(
                _cameraController!,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildBarcodeOverlay(constraints);
                  },
                ),
              ),
            ),
          ),
        ),

        ValueListenableBuilder(
          valueListenable: _setFocusPoint, 
          builder: (context, value, child) {
            return Positioned(
              left: _setFocusPoint.value.dx - 50,
              top: _setFocusPoint.value.dy - 50,
              width: 100,
              height: 100,
              child: ValueListenableBuilder(
                valueListenable: _focusPointVisible,
                builder: (context, value, child) {
                  return IgnorePointer(
                    ignoring: !_focusPointVisible.value,
                    child: GestureDetector(
                      onTap: _keepFocusPointAlive,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 200),
                        opacity: _focusPointVisible.value ? 1 : 0,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(width: .5,color: Colors.amber),
                              // borderRadius: BorderRadius.circular(2.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ]
    );
  }

  Widget _buildBarcodeOverlay(BoxConstraints constraints) {
    _cameraLayoutSize ??= Size(constraints.maxWidth,constraints.maxHeight);
    return Stack(
      children: [

        ValueListenableBuilder(
          valueListenable: _barcodeFrameBytes, 
          builder: (context, value, child) {
            if(_barcodeFrameBytes.value == null){
              return SizedBox.shrink();
            } 
            return Image.memory(
              _barcodeFrameBytes.value!,
              fit: BoxFit.cover,
            );
          },
        ),

        ...widget.children,

        if(widget.animation.enable)
          ValueListenableBuilder(
            valueListenable: _frameRect, 
            builder: (context, value, child) {
              return _buildBarcodeCaptureView();
            },
          )
        
      ],
    );
  }

  /// build animation capture barcode
  Widget _buildBarcodeCaptureView(){
    final rect = _frameRect.value ?? _defaultBarcodeRect();
    bool isQrCode = _barcode?.format == BarcodeFormat.qrCode;
    return AnimatedPositioned(
      duration: widget.animation.duration,
      curve: widget.animation.curve,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: (_barcode == null || isQrCode) 
        ? rect.height
        : rect.width * .5,
      child: 
        widget.barcodeFrameViewBuilder == null
        ? AnimatedContainer(
            duration: widget.animation.duration,
            padding: EdgeInsets.all(15.0),
            curve: widget.animation.curve,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  "assets/barcode_frame_scanner.png",
                  package: 'flutter_barcode_scanner_animation'
                ),
                fit: BoxFit.fill
              )
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 200),
              opacity: _isBarcodeCaptured ? 1.0 : 0.0,
              child: (_barcode == null || _barcode!.format == BarcodeFormat.qrCode)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      'assets/qrcode.png',
                      package: 'flutter_barcode_scanner_animation',
                      fit: BoxFit.fitWidth,
                    ),
                  )
                : Image.asset(
                    'assets/barcode.png',
                    package: 'flutter_barcode_scanner_animation',
                    fit: BoxFit.fitWidth,
                  )
            ),
          )
        : widget.barcodeFrameViewBuilder!.call(context,rect,_barcode)
    );
  }

  ///
  void _onCameraViewTap(TapUpDetails details) {

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
    final Size size = renderBox.size;
    
    final double x = localPosition.dx / size.width;
    final double y = localPosition.dy / size.height;
    
    _setFocusPoint.value = localPosition;
    _focusPointVisible.value = true;
    _focusAnimationController.forward(from: 0.0);
    
    _cameraController!.setFocusPoint(Offset(x, y));
    _keepFocusPointAlive();
  }

  /// 
  void _keepFocusPointAlive(){
    _hideFocusPointTimer?.cancel();
    _hideFocusPointTimer =Timer(const Duration(seconds: 3), () {
      _focusPointVisible.value = false;
    });
  }

  ///
  Future<List<Barcode>> _startDetectBarcodeImage(
    InputImage inputImage, 
    Future<InputImage?> Function() grayScaleWithRotationInputImage
  ) async {
    List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
    if(barcodes.isEmpty){
      final img = await grayScaleWithRotationInputImage();
      if(img != null){
        barcodes = await _barcodeScanner.processImage(img);
      }
    }
    return barcodes;
  }

  

  /// Resume detector and Camera stream
  Future<void> _pauseCamera() async {

    if(_isPaused ) return;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      if (_cameraController!.value.isPreviewPaused == false) {
        await _cameraController!.pausePreview();
      }
      _isPaused = true;
    }
    
  }

  /// Pause detector and Camera stream
  Future<void> _resumeCamera() async {

    if(!_isPaused) return;

    if (_cameraController != null && _cameraController!.value.isInitialized) {

      _barcode = null;
      _isProcessing = false;
      _isBarcodeCaptured = false;

      if (_cameraController!.value.isPreviewPaused) {
        await _cameraController!.resumePreview();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Reset zoom
      if(_currentZoomLevel > 1.0) {
        _currentZoomLevel = 1.0;
        await _cameraController!.setZoomLevel(_currentZoomLevel);
      }
      
      if (!_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_processCameraImage);
      }
      if (mounted) {
        setState(() {});
      }
      _barcodeFrameBytes.value = null;
      _isPaused = false;
    }
  }


  ///
  Rect _defaultBarcodeRect(){
    return Rect.fromLTWH(
      _cameraLayoutSize!.width / 2 - widget.barcodeScanFrameSize.width/2,
      _cameraLayoutSize!.height / 2 - widget.barcodeScanFrameSize.height/2,
      widget.barcodeScanFrameSize.width,
      widget.barcodeScanFrameSize.height,
    );
  }

  ///
  Rect _calculateBarcodeRect() {
    
    Rect rect = CoordinatesTranslator.calculateFrameRect(
      _barcode!.boundingBox,
      _cameraController!.value.previewSize!,
      _inputImageRotation!,
      CameraLensDirection.back,
      _cameraLayoutSize!,
    );
    
    return Rect.fromLTWH(
      rect.left - widget.barcodeFramePadding,
      rect.top - widget.barcodeFramePadding,
      rect.width + widget.barcodeFramePadding * 2,
      rect.height + widget.barcodeFramePadding * 2,
    );
  }

  ///
  Future<void> _startLiveFeed(CameraDescription camera) async {

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController?.initialize();


    initializeController();
    
    
    _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
    
    if (!mounted) return;
    
    await _cameraController!.startImageStream(_processCameraImage);
    setState(() {});

    try {
      await _cameraController?.setFocusMode(FocusMode.auto);
      await _cameraController?.setFocusPoint(const Offset(0.5, 0.5));
    } catch (e) {
      log("Error : $e");
    }

  }

  ///
  void initializeController(){

    // Function for detect barcode from image
    widget.controller.attachDetectBarcodeFromFile(_detectBarcodeFromFile);

    // Function for toggle flash mode
    widget.controller.attachSetFlashMode(_cameraController!.setFlashMode);

    // 
    widget.controller.attachPause(_pauseCamera);
    
    // 
    widget.controller.attachResume(_resumeCamera);

  }

  /// stream detection
  void _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }
      final barcodes = await _barcodeScanner.processImage(inputImage);
      _inputImageRotation = inputImage.metadata!.rotation;

      log("barcodes : $barcodes");

      if (barcodes.isNotEmpty) {

        final bx = barcodes.first.boundingBox;

        double barcodeArea = bx.width * bx.height;
        final frameArea = image.width * image.height;
        double percentage = barcodeArea / frameArea;

        // Increase accuracy
        if(widget.enableAutoZoom && percentage < widget.minBarcodeSizeThreshold && (_currentZoomLevel + .5) <= _maxZoomLevel){
          _currentZoomLevel += .5;
          await _cameraController!.setZoomLevel(_currentZoomLevel);
          await Future.delayed(const Duration(milliseconds: 100));
          _isProcessing = false;
          return;
        }

        // Vibration.vibrate();
        
        // _cameraController!.stopImageStream();
        // _cameraController!.pausePreview();
        _pauseCamera();

        widget.onDetected(barcodes);

        // do animation 
        if(widget.animation.enable) {
          _barcodeFrameBytes.value = await ImageUtils.captureFrameAsPng(
            cameraImage: image,
            rotation: _getCameraRotation()
          );

          await Future.delayed(const Duration(milliseconds: 50));
          _barcode = barcodes.first;
          _frameRect.value = _calculateBarcodeRect();

          await Future.delayed(const Duration(milliseconds: 200));
          _isBarcodeCaptured = true;
          _frameRect.value = _defaultBarcodeRect();

          await Future.delayed(const Duration(milliseconds: 300));
          widget.onCompleted();
        }


      }
    } catch (e) {
      log('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }
  

  ///
  int _getCameraRotation() {
    final camera = _cameras[_cameraIndex];
    return camera.sensorOrientation;
  }

  ///
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final deviceOrientation = _cameraController!.value.deviceOrientation;
      var rotationCompensation = _orientations[deviceOrientation] ?? 0;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    if (Platform.isAndroid) {
      return ImageUtils.buildAndroidInputImage(image, rotation);
    }

    return ImageUtils.buildIOSInputImage(image, rotation);
  }

  ///
  Future<List<Barcode>> _detectBarcodeFromFile(File file) async {
    File? tempFile;
    List<Barcode> barcodes = [];
    try {
      final sourceFile = File(file.path);
      final inputImage = InputImage.fromFile(sourceFile);
      barcodes = await _startDetectBarcodeImage(
        inputImage, 
        () async {
          log("Apply grayscale and rotation....");
          try {
            final Uint8List imageBytes = await sourceFile.readAsBytes();
            img.Image? image = img.decodeImage(imageBytes);
            if (image == null) return null;
            
            image = img.bakeOrientation(image);
            final grayScaleImg = img.grayscale(image);
            final rotateGrayScaleImg = img.copyRotate(grayScaleImg, angle: 90);
            
            final encodedBytes = Uint8List.fromList(
              img.encodeJpg(rotateGrayScaleImg)
            );
            
            final tempDir = await getTemporaryDirectory();
            final tempPath = '${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
            tempFile = File(tempPath);
            await tempFile!.writeAsBytes(encodedBytes);
            
            final inputImage = InputImage.fromFile(tempFile!);
            return inputImage;
          } catch (e) {
            log("Error: $e");
            return null;
          }
        },
      );

    } catch (e) {
      log("Error scanning barcode: $e");
    } finally {
      // Cleanup temp file
      final isFileExist = await tempFile?.exists();
      if (isFileExist == true) {
        await tempFile!.delete();
      }
      
    }
    return barcodes;
  }
}


// class BarcodeFrameDetectView extends StatelessWidget {
//   const BarcodeFrameDetectView({
//     super.key, 
//     required this.rect, 
//     required this.isBarcodeCaptured, 
//     this.barcode,
//     required this.animation
//   });

//   final Rect rect;
//   final bool isBarcodeCaptured;
//   final Barcode? barcode;
//   final BarcodeScannerAnimation animation;

//   bool get isQrCode => barcode?.format == BarcodeFormat.qrCode;

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedPositioned(
//       duration: animation.duration,
//       curve: animation.curve,
//       left: rect.left,
//       top: rect.top,
//       width: rect.width,
//       height: (barcode == null || isQrCode) 
//         ? rect.height
//         : rect.width * .5,
//       child: AnimatedContainer(
//         duration: animation.duration,
//         padding: EdgeInsets.all(15.0),
//         curve: animation.curve,
//         decoration: BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage("assets/barcode_frame_scanner.png"),
//             fit: BoxFit.fill
//           )
//         ),
//         clipBehavior: Clip.antiAlias,
//         child: AnimatedOpacity(
//           duration: Duration(milliseconds: 200),
//           opacity: isBarcodeCaptured ? 1.0 : 0.0,
//           child: (barcode == null || barcode!.format == BarcodeFormat.qrCode)
//             ? ClipRRect(
//                 borderRadius: BorderRadius.circular(8.0),
//                 child: Image.asset(
//                   'assets/qrcode.png',
//                   fit: BoxFit.fitWidth,
//                 ),
//               )
//             : Image.asset(
//                 'assets/barcode.png',
//                 fit: BoxFit.fitWidth,
//               )
//         ),
//       ),
//     );
//   }
// }






// class CornerBorderShape extends ShapeBorder {
//   final double borderWidth;
//   final double cornerLength;
//   final double borderRadius;
//   final Color color;

//   const CornerBorderShape({
//     this.borderWidth = 5,
//     this.cornerLength = 20,
//     this.borderRadius = 0,
//     this.color = Colors.white,
//   });

//   @override
//   EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderWidth);

//   @override
//   Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
//     return Path()..addRect(rect);
//   }

//   @override
//   Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
//     return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)));
//   }

//   @override
//   void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
//     log("paint()...");
//     final paint = Paint()
//       ..color = color
//       ..strokeWidth = borderWidth
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;

//     // Top-left corner
//     canvas.drawPath(
//       Path()
//         ..moveTo(rect.left + cornerLength, rect.top)
//         ..lineTo(rect.left + borderRadius, rect.top)
//         ..arcToPoint(
//           Offset(rect.left, rect.top + borderRadius),
//           radius: Radius.circular(borderRadius),
//           clockwise: false,
//         )
//         ..lineTo(rect.left, rect.top + cornerLength),
//       paint,
//     );

//     // Top-right corner
//     canvas.drawPath(
//       Path()
//         ..moveTo(rect.right - cornerLength, rect.top)
//         ..lineTo(rect.right - borderRadius, rect.top)
//         ..arcToPoint(
//           Offset(rect.right, rect.top + borderRadius),
//           radius: Radius.circular(borderRadius),
//         )
//         ..lineTo(rect.right, rect.top + cornerLength),
//       paint,
//     );

//     // Bottom-left corner
//     canvas.drawPath(
//       Path()
//         ..moveTo(rect.left, rect.bottom - cornerLength)
//         ..lineTo(rect.left, rect.bottom - borderRadius)
//         ..arcToPoint(
//           Offset(rect.left + borderRadius, rect.bottom),
//           radius: Radius.circular(borderRadius),
//           clockwise: false,
//         )
//         ..lineTo(rect.left + cornerLength, rect.bottom),
//       paint,
//     );

//     // Bottom-right corner
//     canvas.drawPath(
//       Path()
//         ..moveTo(rect.right, rect.bottom - cornerLength)
//         ..lineTo(rect.right, rect.bottom - borderRadius)
//         ..arcToPoint(
//           Offset(rect.right - borderRadius, rect.bottom),
//           radius: Radius.circular(borderRadius),
//         )
//         ..lineTo(rect.right - cornerLength, rect.bottom),
//       paint,
//     );
//   }

//   @override
//   ShapeBorder scale(double t) => this;

// }