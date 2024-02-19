import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nugget/common/constants/sizes.dart';
import 'package:nugget/features/authentication/view_models/user_info_view_model.dart';
import 'package:permission_handler/permission_handler.dart';

//추가 import
import 'dart:io';
import 'yolo.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';


typedef void Callback(List<dynamic> list, int h, int w);

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  late CameraController _cameraController;
  late FlashMode _flashMode;
  bool _hasPermission = false;
  bool _isCameraInitialized = false;

  //추가
  int _frameCounter = 0; // 프레임 카운터 선언
  final int _frameThreshold = 5; // 처리 프레임 설정

  @override
  void initState() {
    super.initState();
    _initPermission();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.ultraHigh,
    );

    await _cameraController.initialize();
    _flashMode = _cameraController.value.flashMode;

    _isCameraInitialized = true;
    if (mounted) {
      setState(() {});
    }

    //추가
    Interpreter interpreter = await Interpreter.fromAsset('assets/models/yolov8n_float16.tflite');

    _cameraController.startImageStream((CameraImage cameraImage) async {
      _frameCounter++; // 프레임 카운터 증가
      if (_frameCounter >= _frameThreshold) {
        // 프레임 카운터가 임계값에 도달했는지 확인
        _frameCounter = 0; // 프레임 카운터 리셋

        // Convert CameraImage to img.Image
        img.Image image = convertBGRA8888ToImage(cameraImage);

        try {
          List<String> indices = await yolov8(image, interpreter); // 비동기 처리
          print(indices);
        } catch (e) {
          // 오류 처리
          print(e.toString());
        }
      }
    });

  }

  ///추가 convertBGRA8888ToImage
  // CameraImage (BGRA format) to img.Image conversion
  img.Image convertBGRA8888ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgLibImage = img.Image(width : width, height : height); // Create img.Image

    final bgra = image.planes[0].bytes;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int offset = (y * width + x) * 4; // BGRA8888 means 4 bytes per pixel
        final blue = bgra[offset];
        final green = bgra[offset + 1];
        final red = bgra[offset + 2];
        final alpha = bgra[offset + 3];

        imgLibImage.setPixelRgba(x, y, red, green, blue, alpha);
      }
    }

    return imgLibImage;
  }

  Future<void> _initPermission() async {
    final cameraPermission = await Permission.camera.request();
    final microphonePermission = await Permission.microphone.request();

    final cameraDenied =
        cameraPermission.isDenied || cameraPermission.isPermanentlyDenied;
    final microphoneDenied = microphonePermission.isDenied ||
        microphonePermission.isPermanentlyDenied;

    if (!cameraDenied && !microphoneDenied) {
      _hasPermission = true;
      await _initCamera();
    } else {
      if (!mounted) return;

      await showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('Nugget앱을 사용하기 위해선 카메라와 마이크 권한이 반드시 필요합니다.'),
            content: const Text('카메라와 마이크 권한을 허용해주세요.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('확인'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userInfoViewModelProvider);
    return Scaffold(
      body: _isCameraInitialized
          ? Stack(
              children: [
                Positioned.fill(
                  child: CameraPreview(
                    _cameraController,
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20,
                  child: GestureDetector(
                    onTap: () async {
                      // 캡처를 진행
                      final image = await _cameraController.takePicture();
                      // testYolov8(image.path);
                      // 화면에 캡처한 이미지 띄우기
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('캡처된 이미지'),
                            content: Image.file(File(image.path)),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text('확인'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          Sizes.size10,
                        ),
                      ),
                      width: 50,
                      height: 50,
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.userPlus,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
