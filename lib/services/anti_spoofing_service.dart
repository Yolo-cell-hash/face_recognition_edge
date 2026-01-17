import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class AntiSpoofingService {
  OrtSession? _session;
  bool _isInitialized = false;

  // Model configuration for MiniFASNetV2
  static const int inputSize = 80; // 80x80 input
  static const double livenessThreshold =
      -0.7; // Threshold for real vs fake (30% minimum)

  /// Initialize the ONNX model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize ONNX Runtime environment
      OrtEnv.instance.init();

      // Load model from assets
      final modelData = await rootBundle.load(
        'assets/models/2.7_80x80_MiniFASNetV2.onnx',
      );
      final bytes = modelData.buffer.asUint8List();

      // Create session options
      final sessionOptions = OrtSessionOptions();

      // Create session
      _session = OrtSession.fromBuffer(bytes, sessionOptions);

      _isInitialized = true;
      print('Anti-spoofing model initialized successfully');
      print('Input shape: ${_session!.inputNames}');
      print('Output shape: ${_session!.outputNames}');
    } catch (e) {
      print('Error loading anti-spoofing model: $e');
      rethrow;
    }
  }

  /// Check if the face is real (liveness detection)
  /// Returns a LivenessResult with score and isReal flag
  Future<LivenessResult> checkLiveness(Uint8List faceImageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Decode and preprocess image
      img.Image? image = img.decodeImage(faceImageBytes);
      if (image == null) {
        throw Exception('Failed to decode image for liveness check');
      }

      // Resize to 80x80
      img.Image resized = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      // Convert to normalized float array (CHW format: channels, height, width)
      final inputData = _preprocessImage(resized);

      // Convert to Float32List to ensure float32 tensor type (not float64)
      final inputFloat32 = Float32List.fromList(inputData);

      // Create input tensor
      final inputOrt = OrtValueTensor.createTensorWithDataList(
        inputFloat32,
        [1, 3, inputSize, inputSize], // NCHW format
      );

      // Run inference
      final inputs = {'input': inputOrt};
      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, inputs);

      // Get output (assuming single output with liveness score)
      final output = outputs?[0]?.value as List<List<double>>;

      // Extract score (model outputs probabilities for [fake, real])
      // Assuming output is [batch, num_classes] where num_classes = 2
      final realScore = output[0][1]; // Probability of being real
      final fakeScore = output[0][0]; // Probability of being fake

      inputOrt.release();
      runOptions.release();
      outputs?.forEach((element) => element?.release());

      // Determine if real based on threshold
      final isReal = realScore > livenessThreshold;

      print('Liveness check: Real=$realScore, Fake=$fakeScore, IsReal=$isReal');

      return LivenessResult(score: realScore, isReal: isReal);
    } catch (e) {
      print('Error during liveness check: $e');
      rethrow;
    }
  }

  /// Preprocess image to model input format
  /// Returns normalized float array in CHW format
  List<double> _preprocessImage(img.Image image) {
    final data = <double>[];

    // Mean and std for normalization (ImageNet values commonly used)
    final mean = [0.485, 0.456, 0.406];
    final std = [0.229, 0.224, 0.225];

    // Convert to CHW format (channels first)
    // Red channel
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        data.add((pixel.r / 255.0 - mean[0]) / std[0]);
      }
    }

    // Green channel
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        data.add((pixel.g / 255.0 - mean[1]) / std[1]);
      }
    }

    // Blue channel
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        data.add((pixel.b / 255.0 - mean[2]) / std[2]);
      }
    }

    return data;
  }

  void dispose() {
    _session?.release();
    _isInitialized = false;
  }
}

/// Result of liveness detection
class LivenessResult {
  final double score; // Confidence score for being real (0-1)
  final bool isReal; // Whether the face is real (not spoofed)

  LivenessResult({required this.score, required this.isReal});

  @override
  String toString() {
    return 'LivenessResult(score: ${(score * 100).toStringAsFixed(1)}%, isReal: $isReal)';
  }
}
