import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:vibration/vibration.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_barcode_scanner_animation/flutter_barcode_scanner_animation.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanBarcodeApp());
  configLoading();
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = false
    ..dismissOnTap = false;
}

class ScanBarcodeApp extends StatefulWidget {
  const ScanBarcodeApp({super.key});

  @override
  State<ScanBarcodeApp> createState() => _ScanBarcodeAppState();
}

class _ScanBarcodeAppState extends State<ScanBarcodeApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultScreen(),
      builder: EasyLoading.init(),
    );
  }
}



class DefaultScreen extends StatefulWidget {
  const DefaultScreen({super.key});

  @override
  State<DefaultScreen> createState() => _DefaultScreenState();
}

class _DefaultScreenState extends State<DefaultScreen> {

  Barcode? _barcode;
  final barcodeScanner = BarcodeScanner();
   List<Uint8List> croppedImages = [];
   
  void _handleOpenScanBarcode() async {
    _barcode = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => Scaffold(body: BarcodeScannerDemoPage())
      )
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    log("size == ${MediaQuery.of(context).size}");
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
        title: Text("Flutter Barcode Scanner Animation"),
        backgroundColor: Color(0xFF035F9E),
        foregroundColor: Colors.white,
      ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 20,
              children: [
            
                if(_barcode != null)
                  ...[
                    Text("type = ${_barcode!.type}"),
                    Text("type = ${_barcode!.format}"),
                    Text("rawValue = ${_barcode!.rawValue}"),
                  ],

                ElevatedButton(
                  onPressed: _handleOpenScanBarcode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF035F9E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12,horizontal: 25)
                  ),
                  child: Text("Scan Barcode")
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class BarcodeScannerDemoPage extends StatefulWidget {
  const BarcodeScannerDemoPage({super.key});

  @override
  State<BarcodeScannerDemoPage> createState() => _BarcodeScannerDemoPageState();
}

class _BarcodeScannerDemoPageState extends State<BarcodeScannerDemoPage> {

  final BarcodeScannerController _controller = BarcodeScannerController();

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BarcodeScannerView(
        controller: _controller,
        onDetected: _onDetected,
        onCompleted: _onComplete,
        // formats: [BarcodeFormat.qrCode],
        // barcodeFrameViewBuilder: (context, rect,barcode){
        //   return Container(
        //     decoration: BoxDecoration(
        //       border: Border.all(width: 1,color: Colors.white),
        //       borderRadius: BorderRadius.circular(20)
        //     ),
        //     child: barcode == null
        //       ? null
        //       : Text(
        //         'barcode format : ${barcode.format}',
        //         style: TextStyle(fontSize: 10,color: Colors.white),
        //       ),
        //   );
        // },
        // animation: BarcodeScannerAnimation(duration: Duration(milliseconds: 200),curve: Curves.ease),
        // barcodeScanFrameSize: Size(250, 250),
        children: [
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Align(
              alignment: AlignmentGeometry.center,
              child: Text(
                "Scan Barcode Demo",
                style: TextStyle(
                  color: Colors.white,
                  fontSize : 20,
                  fontWeight: FontWeight.w600
                )
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 25,
              children: [

                IconButton(
                  onPressed: _toggleFlash, 
                  style: IconButton.styleFrom(
                    backgroundColor: Color(0xFF035F9E),
                    foregroundColor: Colors.white
                  ),
                  icon: Icon(Icons.flash_on)
                ),

                IconButton(
                  onPressed: _uploadBarcode, 
                  style: IconButton.styleFrom(
                    backgroundColor: Color(0xFF035F9E),
                    foregroundColor: Colors.white
                  ),
                  icon: Icon(Icons.qr_code)
                ),
              ],
            ),
          ),
        ]
      )
    );
  }

  void _onDetected(List<Barcode> barcodes){
    Vibration.vibrate();
    for (var element in barcodes) {
      log("$element");
    }
    // call api
  }
  void _onComplete() async {
    await _loadFakeData();
    await _controller.resume();
  }

  Future<void> _toggleFlash() async {
    _controller.setFlashMode(
      _controller.flashMode == FlashMode.torch
        ? FlashMode.off 
        : FlashMode.torch
    );
  }

  void _uploadBarcode() async {

    await _controller.pause();

    final xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if(xFile == null) {
      await _controller.resume();
      return ;
    }

    final barcodes = await _controller.detectBarcodeFromFile(File(xFile.path));
    if(barcodes.isNotEmpty){
      log("barcodes found == ${barcodes.length}");
      for(final barcode in barcodes){
        log("barcode.rawValue == ${barcode.rawValue}");
      }
      // await _loadFakeData();
      // await _controller.resume();
      if(mounted){
        Navigator.pop(context,barcodes.first);
      }
    }else {
      await _controller.resume();
      EasyLoading.showToast(
        "No barcode found in image!.",
        duration: Duration(seconds: 3)
      );
    }
    

  }

  Future<void> _loadFakeData({Duration duration = const Duration(seconds: 2)}) async{
    // show loading
    EasyLoading.show(
      status: 'Loading...',
      maskType: EasyLoadingMaskType.black,
    );

    // fake api request
    await Future.delayed(duration);

    // resume camera and detector
    await _controller.resume();

    EasyLoading.dismiss();
    EasyLoading.showToast(
      "Invalid barcode!.",
      duration: Duration(seconds: 3)
    );

  }
}