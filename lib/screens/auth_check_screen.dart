// lib/screens/auth_check_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'home_dispatcher_screen.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';
import '../providers/notification_provider.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    final NotificationService notificationService = NotificationService();
    final NotificationProvider notificationProvider = NotificationProvider();
    notificationService.init();
    notificationProvider.requestNotificationPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoggedIn) {
          return const HomeDispatcherScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
