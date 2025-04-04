import 'dart:io';
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
    'Neutral',
    'Happiness',
    'Surprise',
    'Sadness',
    'Anger',
    'Disgust',
    'Fear',
    'Contempt',
    'Unknown'
  ];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/emoreader_pure_float32.tflite',
        options: InterpreterOptions()
          ..threads = 2
          ..useNnApiForAndroid = false,
      );

      // Verify input tensor matches [1, 48, 48, 1] shape
      final inputTensor = _interpreter!.getInputTensors().first;
      if (!inputTensor.shape.equals([1, 48, 48, 1])) {
        throw Exception('Model expects input shape [1,48,48,1]');
      }
    } catch (e) {
      print("Error loading model: $e");
      rethrow;
    }
  }

  Future<img.Image> _processImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Image decoding failed');
    
    // Convert to grayscale and resize
    return img.grayscale(img.copyResize(image, width: 48, height: 48));
  }

  List<List<List<List<double>>>> _prepareInput(img.Image image) {
    return [
      List.generate(48, (y) {
        return List.generate(48, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0]; // Normalize to [0,1]
        });
      })
    ];
  }

  Future<String> classifyImage(String imagePath) async {
    try {
      final image = await _processImage(imagePath);
      final input = _prepareInput(image);
      final output = List.generate(1, (_) => List.filled(9, 0.0));
      
      _interpreter!.run(input, output);
      
      final confidences = output[0];
      final maxConfidence = confidences.reduce((a, b) => a > b ? a : b);
      final predictedIndex = confidences.indexOf(maxConfidence);
      
      return '${_labels[predictedIndex]} (${(maxConfidence * 100).toStringAsFixed(1)}%)';
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
      setState(() => _result = 'Detected: $result');
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
              // Image preview
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
              
              // Result display
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _result,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
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