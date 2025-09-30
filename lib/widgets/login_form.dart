// lib/widgets/login_form.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../screens/home_dispatcher_screen.dart';
import '../screens/register_screen.dart';
import '../utils/constants.dart';
import '../utils/page_transitions.dart';
import 'custom_text_field.dart';
import 'social_button.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.loginUser(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeDispatcherScreen()),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.errorMessage ?? 'Login failed!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final googleUser = await userProvider.signInWithGoogleUI();

    if (googleUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return; 
    }

    final isExistingUser = await userProvider.loginWithGoogle(googleUser.id);

    if (mounted) setState(() => _isLoading = false);

    if (isExistingUser) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeDispatcherScreen()),
      );
    } else {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RegisterScreen(googleUser: googleUser),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Text('Login here',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kTextColor)),
          const SizedBox(height: 48),
          CustomTextField(
            hintText: 'Email',
            icon: Icons.email_outlined,
            controller: _emailController,
          ),
          CustomTextField(
            hintText: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            controller: _passwordController,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('LOGIN',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('or')),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          SocialButton(onPressed: _handleGoogleSignIn, isLoading: _isLoading),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: () => Navigator.push(
                    context, VerticalAxisTransition(page: const RegisterScreen())),
                child: const Text('Register'),
              ),
            ],
          ),
          const SizedBox(height: 24), 
        ],
      ),
    );
  }
}