import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'emotion_classifier.dart';

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