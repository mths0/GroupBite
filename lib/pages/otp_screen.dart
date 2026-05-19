import 'package:flutter/material.dart';

import 'package:yjeek/components/loading_indicator.dart';
import 'package:yjeek/database_service.dart';
import 'package:yjeek/models/abstract_user.dart';
import 'package:yjeek/utils/validators.dart';

import '../auth_service.dart';
import '../role_navigator.dart';

enum OtpPurpose {
  login,
  register,
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.user,
    required this.purpose,
    required this.verificationId,
  });

  final User user;
  final OtpPurpose purpose;
  final String verificationId;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController otpController = TextEditingController();
  String? errorText;
  bool isLoading = false;

  void onOtpVerified() async {
    final db = DatabaseService();
    final phone = widget.user.phone;

    // Check DB using the NEW unified users table
    final existingUser = await db.getUserByPhone(phone);

    // ===== REGISTER =====
    if (widget.purpose == OtpPurpose.register) {
      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account already exists. Please login.'),
          ),
        );
        return;
      }

      // Create user (driver / customer / restaurant)
      await db.createUser(widget.user.toJson());

      RoleNavigator.navigate(context, widget.user);
      return;
    }

    // ===== LOGIN =====
    if (existingUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account not found. Please register.')),
      );
      return;
    }

    // Navigate using the USER FROM DATABASE (important)
    RoleNavigator.navigate(context, existingUser);
  }

  void verifyOtp() async {
    final otp = otpController.text.trim();
    final otpValid = Validators.validateOTP(otp);

    if (otpValid != null) {
      setState(() {
        errorText = otpValid;
      });
      return;
    }
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final authService = AuthService();

      await authService.verifyOtp(
        verificationId: widget.verificationId,
        smsCode: otp,
      );
      //allowed to enter Dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP Verified Successfully')),
      );
      onOtpVerified();
    } catch (e) {
      setState(() {
        errorText = 'Invalid OTP';
        print(e);
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter OTP',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('We sent a 6-digit code to your phone'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '123456',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: isLoading
                        ? const LoadingIndicator()
                        : ElevatedButton(
                            onPressed: verifyOtp,
                            child: const Text('Verify'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
