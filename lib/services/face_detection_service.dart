import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:ui' as ui;

class FaceDetectionService {
  final FaceDetector _faceDetector;

  FaceDetectionService()
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableClassification: false,
          enableTracking: false,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

  /// Detect face from camera image
  Future<Face?> detectFaceFromImage(InputImage inputImage) async {
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return null;
      }

      // Return the face with largest bounding box (closest to camera)
      Face largestFace = faces.first;
      double maxArea = _calculateArea(largestFace.boundingBox);

      for (var face in faces) {
        double area = _calculateArea(face.boundingBox);
        if (area > maxArea) {
          maxArea = area;
          largestFace = face;
        }
      }

      return largestFace;
    } catch (e) {
      print('Face detection error: $e');
      return null;
    }
  }

  /// Calculate area of bounding box
  double _calculateArea(ui.Rect rect) {
    return rect.width * rect.height;
  }

  /// Check if face quality is good enough
  bool isFaceQualityGood(Face face, ui.Size imageSize) {
    final boundingBox = face.boundingBox;

    // Face should be at least 20% of image width
    final faceWidthRatio = boundingBox.width / imageSize.width;
    if (faceWidthRatio < 0.2) {
      return false;
    }

    // Face should be reasonably centered
    final centerX = boundingBox.left + boundingBox.width / 2;
    final centerY = boundingBox.top + boundingBox.height / 2;
    final imageCenterX = imageSize.width / 2;
    final imageCenterY = imageSize.height / 2;

    final offsetX = (centerX - imageCenterX).abs() / imageSize.width;
    final offsetY = (centerY - imageCenterY).abs() / imageSize.height;

    // Face center should be within 30% of image center
    if (offsetX > 0.3 || offsetY > 0.3) {
      return false;
    }

    return true;
  }

  /// Get face bounding box with padding
  ui.Rect getFaceBoundingBox(Face face, {double padding = 0.3}) {
    final box = face.boundingBox;
    final paddingX = box.width * padding;
    final paddingY = box.height * padding;

    return ui.Rect.fromLTRB(
      (box.left - paddingX).clamp(0, double.infinity),
      (box.top - paddingY).clamp(0, double.infinity),
      box.right + paddingX,
      box.bottom + paddingY,
    );
  }

  void dispose() {
    _faceDetector.close();
  }
}
