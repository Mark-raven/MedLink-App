import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MedLinkApp());
}

class MedLinkApp extends StatelessWidget {
  const MedLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
    );
  }
}
