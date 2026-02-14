

# flutter_barcode_scanner_animation

Flutter package designed to enhance barcode scanning experiences by integrating seamless animations with live camera feed. Utilizing the device camera and Google ML Kit's barcode scanning capabilities, this package provides an intuitive and efficient way to automatically zoom in on barcodes, making detection faster and more reliable. The package features smooth auto-zoom animations that dynamically adjust focus as the barcode approaches, ensuring accurate capture from the live camera feed. Perfect for developers looking to create engaging, real-time barcode scanning applications with a polished user interface and improved scanning performance.


<br>
<br>

![scan_barcode.gif](https://github.com/horlengg/flutter_barcode_scanner_animation/raw/dev/scan_barcode.gif)


<br>
<br>

## Features

* Supports multiple barcode formats for versatile scanning.
* Compatible with both iOS and Android platforms.
* Automatic zoom functionality to enhance accuracy when barcode size is small.
* Set focus point in camera by click on that position
* Smooth animation to capture barcode once detected during live camera feed.
* Ability to scan barcodes from uploaded images.
* Flash mode toggle for better scanning in low-light conditions.
* Customizable overlay and capture frame styles for a tailored user interface.


<br>
<br>


## Setup

### iOS

Add two rows to the `ios/Runner/Info.plist`:

* one with the key `Privacy - Camera Usage Description` and a usage description.
* and one with the key `Privacy - Microphone Usage Description` and a usage description.

If editing `Info.plist` as text, add:

```xml
<key>NSCameraUsageDescription</key>
<string>your usage description here</string>
<key>NSMicrophoneUsageDescription</key>
<string>your usage description here</string>
```

#### Requirement
- Minimum iOS Deployment Target: 15.5
- Xcode 15.3.0 or newer
- Swift 5
- ML Kit does not support 32-bit architectures (i386 and armv7). ML Kit does support 64-bit architectures (x86_64 and arm64). Check this [list](https://developer.apple.com/support/required-device-capabilities/) to see if your device has the required device capabilities. More info [here](https://developers.google.com/ml-kit/migration/ios).

Since ML Kit does not support 32-bit architectures (i386 and armv7), you need to exclude armv7 architectures in Xcode in order to run `flutter build ios` or `flutter build ipa`. More info [here](https://developers.google.com/ml-kit/migration/ios).

Go to Project > Runner > Building Settings > Excluded Architectures > Any SDK > armv7

<p align="center" width="100%">
  <img src="https://raw.githubusercontent.com/flutter-ml/google_ml_kit_flutter/master/resources/build_settings_01.png">
</p>

Your Podfile should look like this:

```ruby
platform :ios, '15.5'  # or newer version

...

# add this line:
$iOSVersion = '15.5'  # or newer version

post_install do |installer|
  # add these lines:
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=*]"] = "armv7"
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
  end

  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # add these lines:
    target.build_configurations.each do |config|
      if Gem::Version.new($iOSVersion) > Gem::Version.new(config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'])
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
      end
    end

  end
end
```

Notice that the minimum `IPHONEOS_DEPLOYMENT_TARGET` is 15.5, you can set it to something newer but not older.


<br>
<br>

### Android

The endorsed [`camera_android_camerax`][2] implementation of the camera plugin built with CameraX has
better support for more devices than `camera_android`, but has some limitations; please see [this list][3]
for more details. If you wish to use the [`camera_android`][4] implementation of the camera plugin
built with Camera2 that lacks these limitations, please follow [these instructions][5].

If you wish to allow image streaming while your app is in the background, there are additional steps required;
please see [these instructions][6] for more details.

#### Requirement
- minSdkVersion: 21
- targetSdkVersion: 35
- compileSdkVersion: 35


<br>
<br>
<br>

## Usage


Sample code usage:

```dart

BarcodeScannerView(
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


```





<br>
<br>
<br>
<br>

## 📬 Contact

If you have any questions, suggestions, or issues, feel free to reach out via my website:

👉 [Website](https://horleng.vercel.app)
