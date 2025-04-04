import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class EmotionClassifier {
  Interpreter? _interpreter;
  final List<String> _labels = [
    'Neutral', 'Happiness', 'Surprise', 'Sadness',
    'Anger', 'Disgust', 'Fear', 'Contempt', 'Unknown'
  ];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/emoreader_pure_float32.tflite',
        options: InterpreterOptions()
          ..threads = 2
          ..useNnApiForAndroid = false,
      );

      // Verify model expects [1,64,64,3] input
      final inputTensor = _interpreter!.getInputTensors().first;
      print('Model input shape: ${inputTensor.shape}');
      
      if (!inputTensor.shape.equals([1, 64, 64, 3])) {
        throw Exception('Model requires [1,64,64,3] RGB input but got ${inputTensor.shape}');
      }

      // Verify output shape
      final outputTensor = _interpreter!.getOutputTensors().first;
      if (outputTensor.shape.length != 2 || outputTensor.shape[1] != 9) {
        throw Exception('Expected output shape [1,9] for 9 emotions');
      }
    } catch (e) {
      print("Model loading error: $e");
      rethrow;
    }
  }

  Future<img.Image> _processImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Image decoding failed');
    
    // Resize to 64x64 (maintains RGB channels)
    return img.copyResize(image, width: 64, height: 64);
  }

  List<List<List<List<double>>>> _prepareInput(img.Image image) {
    // Create tensor with shape [1,64,64,3]
    final input = List.generate(1, (_) => 
      List.generate(64, (y) => 
        List.generate(64, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        })));
    
    return input;
  }

  Future<String> classifyImage(String imagePath) async {
    try {
      final image = await _processImage(imagePath);
      final input = _prepareInput(image);
      final output = List.generate(1, (_) => List.filled(9, 0.0));
      
      _interpreter!.run(input, output);
      
      // Pair labels with confidences and exclude Neutral (index 0)
      final results = _labels.asMap().entries
        .where((e) => e.key != 0) // Skip Neutral
        .map((e) => MapEntry(e.value, output[0][e.key]))
        .toList();
      
      // Sort by confidence (highest first)
      results.sort((a, b) => b.value.compareTo(a.value));
      
      // Get top 2 non-neutral emotions
      final first = results[0];
      final second = results[1];
      
      return '''
      Primary: ${first.key} (${(first.value * 100).toStringAsFixed(1)}%)
      Secondary: ${second.key} (${(second.value * 100).toStringAsFixed(1)}%)
      ''';
    } catch (e) {
      throw Exception('Classification failed: $e');
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}

extension ShapeEquals on List<int> {
  bool equals(List<int> other) {
    if (length != other.length) return false;
    for (int i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}