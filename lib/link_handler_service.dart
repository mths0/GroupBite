import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/models/restaurant.dart';
import 'package:food_delivery_platform/role_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LinkHandlerService {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // We pass the navigatorKey so the service can trigger navigation
  final GlobalKey<NavigatorState> navigatorKey;

  LinkHandlerService(this.navigatorKey);

  void init() async {
    // 1. Check for initial link (Cold Start)
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleMagicLink(initialLink.toString());
    }

    // 2. Listen for links (Background/Foreground)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleMagicLink(uri.toString());
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  // Inside LinkHandlerService._handleMagicLink
  Future<void> _handleMagicLink(String link) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Complete Auth
      final userCredential = await _authService.signInWithEmailLink(link);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return;

      // 2. Check for PENDING registration data
      final pendingDataString = prefs.getString('pending_registration_data');

      if (pendingDataString != null) {
        // THIS IS A REGISTRATION FLOW
        final Map<String, dynamic> data = jsonDecode(pendingDataString);

        // Clear pending data
        // if (navigatorKey.currentContext != null) {
        //   RoleNavigator.navigate(navigatorKey.currentContext!, newRestaurant);
        // }
      } else {
        // THIS IS A NORMAL LOGIN FLOW
        final customUser = await _dbService.getUserByEmail(firebaseUser.email!);
        if (customUser != null) {
          RoleNavigator.navigate(navigatorKey.currentContext!, customUser);
        }
      }
    } catch (e) {
      debugPrint("Link Handling Error: $e");
    }
  }
}
