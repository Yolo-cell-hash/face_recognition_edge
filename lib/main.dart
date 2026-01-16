import 'package:flutter/material.dart';
import 'package:cam_widget/screens/camera_lock_screen.dart';
import 'package:cam_widget/screens/enroll_user_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      initialRoute: '/',
      routes: {
        '/': (context) => const EnrollUserScreen(),
        '/camera_lock': (context) => const CameraLockScreen(),
      },
    );
  }
}
