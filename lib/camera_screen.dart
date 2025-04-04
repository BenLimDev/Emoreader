import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'emotion_classifier.dart';

class CameraScreen extends StatefulWidget {
  final EmotionClassifier classifier;
  
  const CameraScreen({required this.classifier, super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String _result = 'Initializing camera...';
  bool _isProcessing = false;
  File? _capturedImage;
  int whichCamera = 0; // 0 for back camera, 1 for front camera

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(
        cameras[whichCamera], // Using front camera (cameras[1])
        ResolutionPreset.medium,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _result = 'Ready to detect emotions';
      });
    } catch (e) {
      setState(() => _result = 'Camera error: ${e.toString()}');
    }
  }

  Widget _buildCameraPreview() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1, // Force 1:1 aspect ratio
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize!.height,
              height: _controller!.value.previewSize!.width,
              child: CameraPreview(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndAnalyze() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _result = 'Processing...';
      _isProcessing = true;
    });

    try {
      final image = await _controller!.takePicture();
      final imageFile = File(image.path);
      
      setState(() => _capturedImage = imageFile);
      
      final result = await widget.classifier.classifyImage(image.path);
      
      setState(() => _result = 'Detected: \n$result');
    } catch (e) {
      setState(() => _result = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _capturedImage = null;
      _result = 'Ready to detect emotions';
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    setState(() {
      whichCamera = (whichCamera + 1) % 2; // Toggle between 0 and 1
      _capturedImage = null;
      _result = 'Initializing camera...';
      _isProcessing = false;
    });
    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Emotion Detection'),
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
                child: _capturedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_capturedImage!, fit: BoxFit.cover),
                      )
                    : _isCameraInitialized
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildCameraPreview(),
                          )
                        : const Center(
                            child: Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          ),
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
              if (_isCameraInitialized)
                Column(
                  children: [
                    if (_capturedImage == null)
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isProcessing ? null : _switchCamera,
                            child: const Text('Switch Camera'),
                          ),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : _captureAndAnalyze,
                            child: const Text('Capture'),
                          )
                        ]
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _retakePhoto,
                            child: const Text('Retake'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Image Picker'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
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

