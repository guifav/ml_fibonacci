import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/palette.dart';
import 'game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait; the UI is designed for vertical phones.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const FibonacciShellsApp());
}

class FibonacciShellsApp extends StatelessWidget {
  const FibonacciShellsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fibonacci Shells',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgBottom,
        textTheme: const TextTheme().apply(
          bodyColor: textColor,
          displayColor: textColor,
        ),
      ),
      home: const GameScreen(),
    );
  }
}
