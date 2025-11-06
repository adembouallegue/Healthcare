import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/pages/splashscreen.dart';
import 'package:healthcare/theme/dark_mode.dart';
import 'package:healthcare/theme/light_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Platform.isAndroid
      ? await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'AIzaSyD3GS3z8-fGLO_i5PDXLVn1t_Etwe2P3Oo',
          appId: '1:888532691546:android:5ded804e67e5e5d198c663',
          messagingSenderId: '888532691546',
          projectId: 'university-guide-17286'))
      : await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: splashscreenPage(),
      theme: lighMode,
      darkTheme: darkMode,
    );
  }
}
