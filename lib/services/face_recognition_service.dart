import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'face_detection_service.dart';
import 'face_embedding_service.dart';
import 'face_storage_service.dart';

class FaceRecognitionService {
  final FaceDetectionService _detectionService;
  final FaceEmbeddingService _embeddingService;
  final FaceStorageService _storageService;

  FaceRecognitionService()
    : _detectionService = FaceDetectionService(),
      _embeddingService = FaceEmbeddingService(),
      _storageService = FaceStorageService();

  /// Initialize the service (load TFLite model)
  Future<void> initialize() async {
    await _embeddingService.initialize();
  }

  /// Enroll a new user
  Future<EnrollmentResult> enrollUser(String userName, XFile imageFile) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Create InputImage for ML Kit
      final inputImage = InputImage.fromFilePath(imageFile.path);

      // Detect face
      final face = await _detectionService.detectFaceFromImage(inputImage);
      if (face == null) {
        return EnrollmentResult(
          success: false,
          message:
              'No face detected. Please ensure your face is clearly visible.',
        );
      }

      // Decode image for cropping
      final image = img.decodeImage(bytes);
      if (image == null) {
        return EnrollmentResult(
          success: false,
          message: 'Failed to process image',
        );
      }

      // Check face quality
      if (!_detectionService.isFaceQualityGood(
        face,
        Size(image.width.toDouble(), image.height.toDouble()),
      )) {
        return EnrollmentResult(
          success: false,
          message: 'Face quality too low. Move closer and center your face.',
        );
      }

      // Crop face with padding
      final faceBoundingBox = _detectionService.getFaceBoundingBox(
        face,
        padding: 0.2,
      );
      final croppedFace = img.copyCrop(
        image,
        x: faceBoundingBox.left.toInt().clamp(0, image.width),
        y: faceBoundingBox.top.toInt().clamp(0, image.height),
        width: faceBoundingBox.width.toInt().clamp(0, image.width),
        height: faceBoundingBox.height.toInt().clamp(0, image.height),
      );

      // Generate embedding
      final faceBytes = Uint8List.fromList(img.encodePng(croppedFace));
      final embedding = await _embeddingService.generateEmbedding(faceBytes);

      // Generate unique user ID
      final userId = DateTime.now().millisecondsSinceEpoch.toString();

      // Store user
      await _storageService.enrollUser(userId, userName, embedding);

      return EnrollmentResult(
        success: true,
        message: 'Successfully enrolled $userName',
        userId: userId,
      );
    } catch (e) {
      return EnrollmentResult(
        success: false,
        message: 'Error during enrollment: $e',
      );
    }
  }

  /// Verify a face against enrolled users
  Future<VerificationResult> verifyUser(
    XFile imageFile, {
    double threshold = 0.7,
  }) async {
    try {
      // Check if any users are enrolled
      final userCount = await _storageService.getEnrolledUserCount();
      if (userCount == 0) {
        return VerificationResult(
          success: false,
          message: 'No users enrolled. Please enroll a user first.',
        );
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Create InputImage for ML Kit
      final inputImage = InputImage.fromFilePath(imageFile.path);

      // Detect face
      final face = await _detectionService.detectFaceFromImage(inputImage);
      if (face == null) {
        return VerificationResult(success: false, message: 'No face detected');
      }

      // Decode image for cropping
      final image = img.decodeImage(bytes);
      if (image == null) {
        return VerificationResult(
          success: false,
          message: 'Failed to process image',
        );
      }

      // Crop face
      final faceBoundingBox = _detectionService.getFaceBoundingBox(
        face,
        padding: 0.2,
      );
      final croppedFace = img.copyCrop(
        image,
        x: faceBoundingBox.left.toInt().clamp(0, image.width),
        y: faceBoundingBox.top.toInt().clamp(0, image.height),
        width: faceBoundingBox.width.toInt().clamp(0, image.width),
        height: faceBoundingBox.height.toInt().clamp(0, image.height),
      );

      // Generate embedding
      final faceBytes = Uint8List.fromList(img.encodePng(croppedFace));
      final currentEmbedding = await _embeddingService.generateEmbedding(
        faceBytes,
      );

      // Compare with all enrolled users
      final enrolledEmbeddings = await _storageService
          .getAllEnrolledEmbeddings();
      double highestSimilarity = 0.0;
      String? matchedUserId;

      for (var entry in enrolledEmbeddings.entries) {
        final similarity = _embeddingService.compareFaces(
          currentEmbedding,
          entry.value,
        );

        if (similarity > highestSimilarity) {
          highestSimilarity = similarity;
          matchedUserId = entry.key;
        }
      }

      // Check if match exceeds threshold
      if (highestSimilarity >= threshold && matchedUserId != null) {
        final userName = await _storageService.getUserName(matchedUserId);
        return VerificationResult(
          success: true,
          message: 'Welcome, $userName!',
          userId: matchedUserId,
          userName: userName ?? 'Unknown',
          similarity: highestSimilarity,
        );
      } else {
        return VerificationResult(
          success: false,
          message:
              'Face not recognized (confidence: ${(highestSimilarity * 100).toStringAsFixed(1)}%)',
          similarity: highestSimilarity,
        );
      }
    } catch (e) {
      return VerificationResult(
        success: false,
        message: 'Error during verification: $e',
      );
    }
  }

  /// Get all enrolled users
  Future<List<EnrolledUser>> getEnrolledUsers() async {
    final userIds = await _storageService.getAllEnrolledUserIds();
    final names = await _storageService.getAllUserNames();

    return userIds.map((id) {
      return EnrolledUser(userId: id, userName: names[id] ?? 'Unknown');
    }).toList();
  }

  /// Delete a user
  Future<bool> deleteUser(String userId) async {
    return await _storageService.deleteUser(userId);
  }

  void dispose() {
    _detectionService.dispose();
    _embeddingService.dispose();
  }
}

// Result classes
class EnrollmentResult {
  final bool success;
  final String message;
  final String? userId;

  EnrollmentResult({required this.success, required this.message, this.userId});
}

class VerificationResult {
  final bool success;
  final String message;
  final String? userId;
  final String? userName;
  final double? similarity;

  VerificationResult({
    required this.success,
    required this.message,
    this.userId,
    this.userName,
    this.similarity,
  });
}

class EnrolledUser {
  final String userId;
  final String userName;

  EnrolledUser({required this.userId, required this.userName});
}
