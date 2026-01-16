import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceEmbeddingService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // Model configuration
  static const int inputSize = 112; // FaceNet512 expects 160x160
  static const int embeddingSize = 192; // Output dimension

  /// Initialize the TFLite model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/facenet512.tflite',
      );

      // Print model diagnostics
      print('FaceNet model initialized successfully');
      print('Input tensor shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output tensor shape: ${_interpreter!.getOutputTensor(0).shape}');
      print('Input type: ${_interpreter!.getInputTensor(0).type}');
      print('Output type: ${_interpreter!.getOutputTensor(0).type}');

      _isInitialized = true;
    } catch (e) {
      print('Error loading FaceNet model: $e');
      rethrow;
    }
  }

  /// Generate face embedding from cropped face image
  Future<List<double>> generateEmbedding(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to 160x160 (FaceNet input size)
      img.Image resized = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      // Convert to normalized 3D array (0-1 range)
      var input = _imageToByteListFloat32(resized);

      // Output tensor
      var output = List.filled(
        1 * embeddingSize,
        0.0,
      ).reshape([1, embeddingSize]);

      // Run inference
      _interpreter!.run(input, output);

      // Extract embedding from output
      List<double> embedding = List<double>.from(output[0]);

      // Normalize embedding (L2 normalization)
      embedding = _normalizeEmbedding(embedding);

      return embedding;
    } catch (e) {
      print('Error generating embedding: $e');
      rethrow;
    }
  }

  /// Convert image to normalized float32 list
  List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        var pixel = image.getPixel(x, y);

        // Normalize to 0-1 range
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return convertedBytes.reshape([1, inputSize, inputSize, 3]);
  }

  /// L2 normalization
  List<double> _normalizeEmbedding(List<double> embedding) {
    double sumSquares = 0.0;
    for (var value in embedding) {
      sumSquares += value * value;
    }
    double norm = math.sqrt(sumSquares);

    if (norm == 0) return embedding;

    return embedding.map((value) => value / norm).toList();
  }

  /// Compare two embeddings and return similarity score (0-1, higher = more similar)
  double compareFaces(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Embeddings must have same dimension');
    }

    // Calculate cosine similarity
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    // embeddings are already normalized, so cosine similarity = dot product
    return dotProduct;
  }

  /// Calculate Euclidean distance (alternative metric)
  double euclideanDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Embeddings must have same dimension');
    }

    double sum = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      double diff = embedding1[i] - embedding2[i];
      sum += diff * diff;
    }

    return math.sqrt(sum);
  }

  /// Match face against stored embedding with threshold
  bool isSamePerson(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.7,
  }) {
    double similarity = compareFaces(embedding1, embedding2);
    return similarity >= threshold;
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
