import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/tuner_model.dart';
import 'screens/tuner_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TunerModel(),
      child: const HeliumFlashTunerApp(),
    ),
  );
}

class HeliumFlashTunerApp extends StatelessWidget {
  const HeliumFlashTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeliumFlash Tuner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00CC66),
          secondary: Color(0xFF00CC66),
          surface: Color(0xFF161B22),
          onSurface: Color(0xFFE6EDF3),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          foregroundColor: Color(0xFFE6EDF3),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFE6EDF3)),
        ),
      ),
      home: const TunerScreen(),
    );
  }
}
