import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

Future<List<String>> yolov8(img.Image image, Interpreter interpreter) async {
  // img.Image? image = await _loadImage('assets/images/any_image.png');
  // Interpreter interpreter = await Interpreter.fromAsset('assets/models/yolov8n_float16.tflite');
  try {
    final input = _preProcess(image);

    // output shape:
    // 1 : batch size
    // 4 + 80: left, top, right, bottom and probabilities for each class
    // 8400: num predictions
    // final output = List<num>.filled(1 * 84 * 8400, 0).reshape([1, 84, 8400]);
    final output = List.filled(84 * 8400, 0.0).reshape([1, 84, 8400]);
    int predictionTimeStart = DateTime.now().millisecondsSinceEpoch;
    interpreter.run([input], output);
    int predictionTime = DateTime.now().millisecondsSinceEpoch - predictionTimeStart;
    print('Prediction time: $predictionTime ms');

    List<dynamic> maxPredList = List.filled(84*5, 0.0).reshape([84,5]);
    double premaxPred = 0;
    for(int i = 5; i < 84; i++){
      premaxPred = 0;
      List<double> tempBox = List.filled(4, 0.0);
      for(int t = 0; t < 8400; t++){
        if(premaxPred < output[0][i][t]){
          premaxPred = output[0][i][t];
          tempBox[0] = output[0][0][t];
          tempBox[1] = output[0][1][t];
          tempBox[2] = output[0][2][t];
          tempBox[3] = output[0][3][t];
        }
      }
      maxPredList[i][4] = premaxPred;
      maxPredList[i][0] = tempBox[0];
      maxPredList[i][1] = tempBox[1];
      maxPredList[i][2] = tempBox[2];
      maxPredList[i][3] = tempBox[3];
    }

    List<int> indices = [];
    double threshold = 0.4; // 임계값
    List<dynamic> resultBox = [];

    for (int i = 0; i < maxPredList.length; i++) {
      if (maxPredList[i][4] > threshold) {
        indices.add(i);
        resultBox.add(maxPredList[i].sublist(0,4));
      }
    }

    print(resultBox);
    print("Indices of values over 40%: $indices");
    
    return getLabels(indices);
  }
  finally {
    // interpreter.close(); // 리소스 해제
  }  
}

List<String> getLabels(List<int> num) {

  List<String> objects = [
  'person', 'bicycle', 'car', 'motorbike', 'aeroplane', 'bus', 'train', 'truck', 'boat', 'traffic light',
  'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
  'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee',
  'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard',
  'tennis racket', 'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
  'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'sofa',
  'pottedplant', 'bed', 'diningtable', 'toilet', 'tvmonitor', 'laptop', 'mouse', 'remote', 'keyboard',
  'cell phone', 'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase', 'scissors',
  'teddy bear', 'hair drier', 'toothbrush'
  ];

  List<String> temp = [];

  for(int i = 0; i < num.length; i++){
    temp.add(objects[num[i]-4]);
  }

  return temp;
}

Future<img.Image?> _loadImage(String imagePath) async {
  final imageData = await rootBundle.load(imagePath);
  print(imageData.buffer.asUint8List().shape);
  return img.decodeImage(imageData.buffer.asUint8List());
}

List<List<List<num>>> _preProcess(img.Image image) {
  final imgResized = img.copyResize(image, width: 640, height: 640);

  return convertImageToMatrix(imgResized);
}

// yolov8 requires input normalized between 0 and 1
List<List<List<num>>> convertImageToMatrix(img.Image image) {
  return List.generate(
    image.height,
    (y) => List.generate(
      image.width,
      (x) {
        final pixel = image.getPixel(x, y);
        return [pixel.rNormalized, pixel.gNormalized, pixel.bNormalized];
      },
    ),
  );
}
