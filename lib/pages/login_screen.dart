import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';

import 'package:food_delivery_platform/components/loading_indicator.dart';
import 'package:food_delivery_platform/pages/otp_screen.dart';
import 'package:food_delivery_platform/role_navigator.dart';
import 'package:food_delivery_platform/utils/validators.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  String? errorText;
  bool isLoading = false;

  Future<void> validatePhone() async {
    final phone = phoneController.text.trim();

    final validationError = Validators.validatePhone(phone);
    if (validationError != null) {
      setState(() {
        errorText = validationError;
      });
      return;
    }

    setState(() {
      errorText = null;
      isLoading = true;
    });

    print("Phone is valid: +966$phone");
    
    // check if user exists
    final db = DatabaseService();
    final user = await db.getUserByPhone(phone);
    if (user == null) {
      setState(() {
        errorText = "No account found. Please register.";
        isLoading = false;
      });
      return;
    }

    // next step OTP ?
    final authService = AuthService();

    authService.sendOtp(
      phone: '+966$phone',

      onCodeSent: (verificationId) {
        setState(() => isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              //TODO change this to be for all users
              user: user,
              purpose: OtpPurpose.login,
              verificationId: verificationId,
            ),
          ),
        );
      },

      onAutoVerified: (_) {
        RoleNavigator.navigate(context, user);
      },

      onError: (error) {
        setState(() {
          errorText = error;
          isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Phone Number"),
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: Container(
          margin: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Enter your phone number',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We'll send you a verification code",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Country Code Box
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: const [
                            Text(
                              '+966',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(width: 4),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 15,
                      ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 9,

                      decoration: InputDecoration(
                        hintText: '5X XXX XXXX',
                        errorText: errorText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: isLoading
                    ? const LoadingIndicator()
                    : FilledButton(
                        onPressed: validatePhone,
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
