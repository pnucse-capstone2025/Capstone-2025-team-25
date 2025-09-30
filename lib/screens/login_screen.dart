import 'package:flutter/material.dart';
import '../widgets/glass_container.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/background.png', 
              fit: BoxFit.cover,
            ),
          ),

          GlassContainer(
            width: 340,
            height: 520,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: LoginForm(),
            ),
          ),
        ],
      ),
    );
  }
}