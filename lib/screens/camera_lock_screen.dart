import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class CameraLockScreen extends StatefulWidget {
  const CameraLockScreen({super.key});

  @override
  State<CameraLockScreen> createState() => _CameraLockScreenState();
}

class _CameraLockScreenState extends State<CameraLockScreen>
    with SingleTickerProviderStateMixin {
  CameraController? controller;
  bool _isVerifying = false;
  String _statusMessage = 'Position your face in the frame';
  bool _permissionDenied = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();

    // Setup pulse animation for the face detection frame
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _requestCameraPermission() async {
    // Check if permission is already granted
    final status = await Permission.camera.status;

    if (status.isGranted) {
      // Permission already granted, initialize camera
      initCamera();
    } else if (status.isDenied) {
      // Permission denied, request it
      final result = await Permission.camera.request();

      if (result.isGranted) {
        initCamera();
      } else if (result.isPermanentlyDenied) {
        // User permanently denied permission
        setState(() {
          _permissionDenied = true;
        });
      } else {
        // User denied permission this time
        setState(() {
          _permissionDenied = true;
        });
      }
    } else if (status.isPermanentlyDenied) {
      // Open app settings
      setState(() {
        _permissionDenied = true;
      });
    }
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Find front camera for facial recognition
    CameraDescription? frontCamera;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    final selectedCamera = frontCamera ?? cameras[0];

    controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Capturing image...';
    });

    try {
      // Capture the image from camera
      final XFile image = await controller!.takePicture();

      setState(() {
        _statusMessage = 'Uploading to server...';
      });

      // Upload image to S3
      final File imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'face_$timestamp.png';

      // Construct S3 URL (matching reference implementation)
      final url = Uri.parse(
        'https://jay-streaming.s3.ap-south-1.amazonaws.com/$filename',
      );

      debugPrint('Uploading to URL: $url');
      debugPrint('File size: ${imageBytes.length} bytes');

      final response = await http.put(
        url,
        body: imageBytes,
        headers: {'Content-Type': 'image/png'},
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'Upload successful!';
        });

        // Show success for 2 seconds, then reset
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          setState(() {
            _isVerifying = false;
            _statusMessage = 'Position your face in the frame';
          });
        }
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Verification error: $e');

      if (mounted) {
        setState(() {
          _statusMessage = 'Error: ${e.toString()}';
          _isVerifying = false;
        });

        // Reset error message after 3 seconds
        await Future.delayed(const Duration(seconds: 3));

        if (mounted) {
          setState(() {
            _statusMessage = 'Position your face in the frame';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show permission denied screen
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E27),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 80,
                  color: Colors.white54,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app needs camera access to verify your identity.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: const Color(0xFF0A0E27),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E27),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final cameraAspectRatio = controller!.value.aspectRatio;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Stack(
        children: [
          // Camera preview with proper aspect ratio
          Center(
            child: AspectRatio(
              aspectRatio: 1 / cameraAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(controller!),
              ),
            ),
          ),

          // Gradient overlay for better text visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.2, 0.6, 1.0],
              ),
            ),
          ),

          // Top section - Title and status
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Godrej Advantis IoT9',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Face Verification',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Face detection frame overlay
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: CustomPaint(
                    size: Size(size.width * 0.7, size.width * 0.85),
                    painter: FaceFramePainter(
                      color: _isVerifying
                          ? const Color(0xFF00D9FF)
                          : Colors.white.withOpacity(0.8),
                      strokeWidth: _isVerifying ? 4.0 : 3.0,
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom section - Instructions and button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isVerifying
                            ? const Color(0xFF00D9FF).withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isVerifying
                              ? const Color(0xFF00D9FF)
                              : Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isVerifying)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00D9FF),
                              ),
                            )
                          else
                            const Icon(
                              Icons.face,
                              color: Colors.white,
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Verification button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _startVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D9FF),
                          foregroundColor: const Color(0xFF0A0E27),
                          disabledBackgroundColor: const Color(
                            0xFF00D9FF,
                          ).withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isVerifying
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0A0E27),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Proceed to Verification',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Additional info
                    Text(
                      'Ensure good lighting for best results',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the face detection frame
class FaceFramePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  FaceFramePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = 40.0;
    final radius = 20.0;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
        ..lineTo(cornerLength, 0),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(
          Offset(size.width, radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width, cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLength)
        ..lineTo(0, size.height - radius)
        ..arcToPoint(
          Offset(radius, size.height),
          radius: Radius.circular(radius),
        )
        ..lineTo(cornerLength, size.height),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, size.height)
        ..lineTo(size.width - radius, size.height)
        ..arcToPoint(
          Offset(size.width, size.height - radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(FaceFramePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
