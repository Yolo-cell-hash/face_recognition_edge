import 'package:flutter/material.dart';
import '../services/face_recognition_service.dart';
import 'enroll_camera_screen.dart';

class EnrollUserScreen extends StatefulWidget {
  const EnrollUserScreen({super.key});

  @override
  State<EnrollUserScreen> createState() => _EnrollUserScreenState();
}

class _EnrollUserScreenState extends State<EnrollUserScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FaceRecognitionService _faceRecognitionService =
      FaceRecognitionService();
  bool _isEnrolling = false;
  String _statusMessage = '';
  List<EnrolledUser> _enrolledUsers = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadEnrolledUsers();
  }

  Future<void> _initializeService() async {
    try {
      await _faceRecognitionService.initialize();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: $e';
      });
    }
  }

  Future<void> _loadEnrolledUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final users = await _faceRecognitionService.getEnrolledUsers();
      setState(() {
        _enrolledUsers = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
      });
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Delete User?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$userName"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _faceRecognitionService.deleteUser(userId);
      if (success) {
        setState(() {
          _statusMessage = 'Deleted $userName';
        });
        // Reload users list
        await _loadEnrolledUsers();
      } else {
        setState(() {
          _statusMessage = 'Failed to delete $userName';
        });
      }
    }
  }

  Future<void> _captureAndEnroll() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a name';
      });
      return;
    }

    // Navigate to camera preview screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EnrollCameraScreen(userName: _nameController.text.trim()),
      ),
    );

    // Handle result from camera screen
    if (result != null && result is EnrollmentResult) {
      setState(() {
        _statusMessage = result.message;
      });

      if (result.success) {
        // Clear name field
        _nameController.clear();

        // Reload enrolled users list
        await _loadEnrolledUsers();

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1F3A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF00D9FF), size: 32),
                  SizedBox(width: 12),
                  Text('Success!', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Text(
                result.message,
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Color(0xFF00D9FF)),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Widget _buildUserTile(EnrolledUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF00D9FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _deleteUser(user.userId, user.userName),
            tooltip: 'Delete user',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _faceRecognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('Enroll New User'),
        backgroundColor: const Color(0xFF0A0E27),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 80, color: Color(0xFF00D9FF)),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              enabled: !_isEnrolling,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'User Name',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Enter full name',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D9FF)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isEnrolling ? null : _captureAndEnroll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: const Color(0xFF0A0E27),
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isEnrolling
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Enrolling...'),
                        ],
                      )
                    : const Text(
                        'Capture & Enroll',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 32),
            // Enrolled Users Section
            if (_enrolledUsers.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.people, color: Color(0xFF00D9FF), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Enrolled Users (${_enrolledUsers.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...(_enrolledUsers.map((user) => _buildUserTile(user))),
              const SizedBox(height: 24),
            ],
            // Divider
            Container(height: 1, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 32),
            // Proceed to Verification button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/camera_lock');
                },
                icon: const Icon(Icons.verified_user),
                label: const Text(
                  'Proceed to Verification',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: const Color(0xFF00D9FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF00D9FF), width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
