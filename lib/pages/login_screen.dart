import 'package:flutter/material.dart';
import 'package:food_delivery_platform/auth_service.dart';
import 'package:food_delivery_platform/database_service.dart';
import 'package:food_delivery_platform/components/loading_indicator.dart';
import 'package:food_delivery_platform/utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  String? errorText;
  bool isLoading = false;

  Future<void> validateEmail() async {
    final email = emailController.text.trim();

    final validationError = Validators.validateEmail(email);
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

    try {
      final db = DatabaseService();
      final user = await db.getUserByEmail(email);

      if (user == null) {
        setState(() {
          errorText = "No account found. Please register.";
          isLoading = false;
        });
        return;
      }

      final authService = AuthService();
      await authService.sendMagicLink(email);

      setState(() {
        isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in link sent to $email'),
        ),
      );
    } catch (e) {
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Email Login"),
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Enter your email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We'll send you a sign-in link",
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'customer@gmail.com',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: isLoading
                    ? const LoadingIndicator()
                    : FilledButton(
                        onPressed: validateEmail,
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