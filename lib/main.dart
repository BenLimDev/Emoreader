import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const EmotionDetectorApp());
}

class EmotionDetectorApp extends StatelessWidget {
  const EmotionDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emotion Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const EmotionDetectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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

class EmotionDetectionScreen extends StatefulWidget {
  const EmotionDetectionScreen({super.key});

  @override
  State<EmotionDetectionScreen> createState() => _EmotionDetectionScreenState();
}

class _EmotionDetectionScreenState extends State<EmotionDetectionScreen> {
  final _classifier = EmotionClassifier();
  File? _selectedImage;
  String _result = 'Initializing...';
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _classifier.loadModel();
      setState(() {
        _isLoading = false;
        _result = 'Ready to detect emotions';
      });
    } catch (e) {
      setState(() {
        _result = 'Failed to initialize: ${e.toString()}';
      });
    }
  }

  Future<void> _pickAndClassifyImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _result = 'Processing...';
      _isProcessing = true;
    });

    try {
      final result = await _classifier.classifyImage(pickedFile.path);
      setState(() => _result = 'Detected: \n $result');
    } catch (e) {
      setState(() => _result = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Detector'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : const Icon(Icons.image, size: 50, color: Colors.grey),
              ),
              const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _result.split('\n').map((line) => 
                        Text(line, textAlign: TextAlign.center)
                      ).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (!_isLoading)
                ElevatedButton(
                  onPressed: _isProcessing ? null : _pickAndClassifyImage,
                  child: const Text('Select Image'),
                ),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
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