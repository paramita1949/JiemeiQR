import 'package:flutter/material.dart';
import 'package:qrscan_flutter/screens/home_screen.dart';

void main() {
  runApp(const QrScanApp());
}

class QrScanApp extends StatelessWidget {
  const QrScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRSCAN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF6C63FF),
        ),
        scaffoldBackgroundColor: const Color(0xFF111318),
      ),
      home: const HomeScreen(),
    );
  }
}
