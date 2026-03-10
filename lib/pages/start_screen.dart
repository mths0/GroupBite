import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:food_delivery_platform/pages/login_screen.dart';
import 'package:food_delivery_platform/pages/register_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            children: [
              Expanded(
                child: Lottie.asset(
                  'assets/animations/salad_animation.json',
                  repeat: true,
                  animate: true,
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Text(
                "Welcome to FoodFlow",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              SizedBox(
                height: 10,
              ),
              Text("Discover restaurant, order your favorite meals."),
              SizedBox(
                height: 10,
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RegisterScreen(),
                      ),
                    );
                  },
                  child: Text("Get Started"),
                ),
              ),
              // TextField(
              //   decoration: InputDecoration(label: Text("User name")),
              // ),
              // TextField(
              //   decoration: InputDecoration(
              //     label: Text("Password"),
              //   ),
              //   obscureText: true,
              // ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(),
                        ),
                      );
                    },
                    child: Text("Login"),
                  ),
                ],
              ),
              SizedBox(
                height: 50,
              ),
              // TextButton(onPressed: changeScreen, child: Text("Register")),
            ],
          ),
        ),
      ),
    );
  }
}
