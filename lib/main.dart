import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/link_handler_service.dart';
import 'package:food_delivery_platform/notification_service.dart';
import 'package:food_delivery_platform/pages/register_screen.dart';
import 'package:food_delivery_platform/pages/start_screen.dart';
import 'package:food_delivery_platform/themes/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint('Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if Firebase is already initialized to avoid the "duplicate-app" error
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint("Firebase Initialization Error: $e");
    }
  }
  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );
  await NotificationService.instance.init();

  runApp(const OurApp());
}

class OurApp extends StatefulWidget {
  const OurApp({super.key});

  @override
  State<OurApp> createState() => _OurAppState();
}

class _OurAppState extends State<OurApp> {
  late LinkHandlerService _linkHandler;

  @override
  void initState() {
    super.initState();
    // Initialize the cleaner service
    _linkHandler = LinkHandlerService(navigatorKey);
    _linkHandler.init();
  }

  @override
  void dispose() {
    _linkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const StartScreen(),
      routes: {
        '/register': (context) =>
            const RegisterScreen(), // You can replace this with a dedicated registration screen if needed
      },
    );
  }
}
