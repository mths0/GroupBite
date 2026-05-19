import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:yjeek/auth_service.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/notification_service.dart';
import 'package:yjeek/role_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LinkHandlerService {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  final GlobalKey<NavigatorState> navigatorKey;

  LinkHandlerService(this.navigatorKey);

  void init() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleMagicLink(initialLink.toString());
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleMagicLink(uri.toString());
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  Future<void> _handleMagicLink(String link) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userCredential = await _authService.signInWithEmailLink(link);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return;

      final pendingDataString = prefs.getString('pending_registration_data');

      if (pendingDataString != null) {
        final Map<String, dynamic> data = jsonDecode(pendingDataString);
  
        await _dbService.createUser(data);
        await prefs.remove('pending_registration_data');

        final newUser = await _dbService.getUserByEmail(firebaseUser.email!);
        if (newUser != null) {
          await NotificationService.instance.saveTokenForUser(newUser.id);

          if (navigatorKey.currentContext != null) {
            RoleNavigator.navigate(navigatorKey.currentContext!, newUser);
          }
        }
      } else {
        final customUser = await _dbService.getUserByEmail(firebaseUser.email!);
        if (customUser != null) {
          await NotificationService.instance.saveTokenForUser(customUser.id);

          if (navigatorKey.currentContext != null) {
            RoleNavigator.navigate(navigatorKey.currentContext!, customUser);
          }
        }
      }
    } catch (e) {
      debugPrint("Link Handling Error: $e");
    }
  }
}
