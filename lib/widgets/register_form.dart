// lib/widgets/register_form.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/home_dispatcher_screen.dart';
import '../utils/constants.dart';
import 'custom_text_field.dart';
import 'social_button.dart';

class RegisterForm extends StatefulWidget {
  final GoogleSignInAccount? googleUser;
  const RegisterForm({super.key, this.googleUser});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _displayNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  GoogleSignInAccount? _googleAccount;
  String? _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.googleUser != null) {
      _googleAccount = widget.googleUser;
      _displayNameController.text = _googleAccount!.displayName ?? '';
      _emailController.text = _googleAccount!.email;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_googleAccount != null) {
      await _completeGoogleRegistration();
    } else {
      await _emailPasswordRegistration();
    }
  }

  Future<void> _emailPasswordRegistration() async {
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.registerWithEmail(
      username: _nicknameController.text.trim(),
      email: _emailController.text.trim(),
      displayName: _displayNameController.text.trim(),
      password: _passwordController.text.trim(),
      role: _selectedRole!,
    );
    
    if(mounted) setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeDispatcherScreen()),
        (route) => false,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.errorMessage ?? 'Registration failed!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _completeGoogleRegistration() async {
    if (_nicknameController.text.isEmpty || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a nickname and select a role.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.completeGoogleRegistration(
      googleUser: _googleAccount!,
      nickname: _nicknameController.text.trim(),
      role: _selectedRole!,
    );
    
    if(mounted) setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeDispatcherScreen()),
        (route) => false,
      );
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.errorMessage ?? 'Registration failed!'),
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
    
    if (googleUser != null) {
      setState(() {
        _googleAccount = googleUser;
        _displayNameController.text = googleUser.displayName ?? '';
        _emailController.text = googleUser.email;
      });
    }
    if(mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isGoogleFlow = _googleAccount != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Create Account',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kTextColor)),
          const SizedBox(height: 24),
          CustomTextField(
              hintText: 'Display Name',
              icon: Icons.person_outline,
              controller: _displayNameController,
              enabled: !isGoogleFlow),
          CustomTextField(
              hintText: 'Nickname (required)',
              icon: Icons.badge_outlined,
              controller: _nicknameController),
          CustomTextField(
              hintText: 'Email',
              icon: Icons.email_outlined,
              controller: _emailController,
              enabled: !isGoogleFlow),
          if (!isGoogleFlow)
            CustomTextField(
                hintText: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _passwordController),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.work_outline, color: Colors.grey),
                hintText: 'Select your role',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              value: _selectedRole,
              items: ['Normal', 'Manager', 'Doctor', 'Mixed']
                  .map((role) =>
                      DropdownMenuItem(value: role, child: Text(role)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedRole = value),
              validator: (value) =>
                  value == null ? 'Please select a role' : null,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    isGoogleFlow
                        ? 'COMPLETE REGISTRATION'
                        : 'REGISTER',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
          ),
          if (!isGoogleFlow) ...[
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
            SocialButton(
                onPressed: _handleGoogleSignIn, isLoading: _isLoading),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Already have an account?"),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Login')),
            ],
          ),
        ],
      ),
    );
  }
}