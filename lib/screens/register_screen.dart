// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/glass_container.dart';
import '../widgets/register_form.dart'; 

class RegisterScreen extends StatelessWidget {
  final GoogleSignInAccount? googleUser;
  const RegisterScreen({super.key, this.googleUser});

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
            height: 640,
            child: RegisterForm(googleUser: googleUser),
          ),
        ],
      ),
    );
  }
}