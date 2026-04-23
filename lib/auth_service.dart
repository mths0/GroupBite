import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';



class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChange => _auth.authStateChanges();

  /// Step 1: Send OTP
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(UserCredential user) onAutoVerified,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCredential = await _auth.signInWithCredential(credential);
        onAutoVerified(userCredential);
      },

      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },

      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },

      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Step 2: Verify OTP
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return await _auth.signInWithCredential(credential);
  }

  
  // Add to AuthService
  Future<void> sendRegistrationMagicLink(
    String email,
    Map<String, dynamic> userData,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Save the email (Firebase needs this for the handshake)
    await prefs.setString('email_for_signin', email);

    // 2. Save the pending registration data as a JSON string
    await prefs.setString('pending_registration_data', jsonEncode(userData));

    final actionCodeSettings = ActionCodeSettings(
      url: 'https://food-delivery-platform-fa227.firebaseapp.com/finishSignIn',
      handleCodeInApp: true,
      androidPackageName: 'com.example.food_delivery_platform',
      androidInstallApp: true,
      androidMinimumVersion: '1',
      iOSBundleId: 'com.example.foodDeliveryPlatform',
    );

    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }

  Future<void> sendMagicLink(String email) async {
    final actionCodeSettings = ActionCodeSettings(
      url: 'https://food-delivery-platform-fa227.firebaseapp.com/finishSignIn',
      handleCodeInApp: true,
      androidPackageName: 'com.example.food_delivery_platform',
      androidInstallApp: true,
      androidMinimumVersion: '1',
      iOSBundleId: 'com.example.foodDeliveryPlatform',
    );

    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email_for_signin', email);
  }

  Future<UserCredential> signInWithEmailLink(String emailLink) async {
    if (!_auth.isSignInWithEmailLink(emailLink)) {
      throw Exception('Invalid email sign-in link');
    }

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email_for_signin');

    if (email == null) {
      throw Exception('No saved email found for sign-in.');
    }

    final credential = await _auth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );

    await prefs.remove('email_for_signin');
    return credential;
  }

  Future<void> completeEmailLinkSignIn(String link) async {
    if (!_auth.isSignInWithEmailLink(link)) return;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email_for_signin');

    if (email == null) {
      throw Exception('No saved email found');
    }

    await _auth.signInWithEmailLink(
      email: email,
      emailLink: link,
    );

    await prefs.remove('email_for_signin');
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
