import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/themes/app_theme.dart';

// var kColorScheme = ColorScheme.fromSeed(
//   seedColor: const Color.fromRGBO(245, 124, 0, 1),
// );

// Restaurant 500000000 
// Customer 511111111
// Driver 522222222

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const OurApp());
}

class OurApp extends StatefulWidget {
  const OurApp({super.key});

  @override
  State<OurApp> createState() => _OurAppState();
}

class _OurAppState extends State<OurApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const StartScreen(),
    );
  }
}
