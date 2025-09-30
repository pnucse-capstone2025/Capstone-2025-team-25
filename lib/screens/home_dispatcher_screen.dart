// lib/screens/home_dispatcher_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';

import '../providers/task_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/task_request_provider.dart';
import '../providers/user_provider.dart';

import 'normal_user_home_screen.dart';
import 'privileged_user_home_screen.dart';

class HomeDispatcherScreen extends StatefulWidget {
  const HomeDispatcherScreen({super.key});

  @override
  State<HomeDispatcherScreen> createState() => _HomeDispatcherScreenState();
}

class _HomeDispatcherScreenState extends State<HomeDispatcherScreen> {
  final NotificationService _notificationService = NotificationService();
  @override
  void initState() {
    super.initState();
    print("✅ HomeDispatcherScreen initState has run.");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.init();
      _setupFirebaseMessagingListener(context);
    });
  }

  void _setupFirebaseMessagingListener(BuildContext context) {
    print("✅ Setting up FirebaseMessaging listener...");
    final chatProvider = context.read<ChatProvider>();
    final userProvider = context.read<UserProvider>();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('-----------------------------------------');
      print('✅ [FCM] Foreground message received!');
      if (userProvider.userUuid != null) {
        chatProvider.fetchChats(userProvider.userUuid!);
      }
      final notification = message.notification;
      print(
        '[FCM] Notification Payload: ${notification?.title} - ${notification?.body}',
      );
      print('[FCM] Data Payload: ${message.data}');
      final incomingChatUuid = message.data['chat_uuid'];
      print('[FCM] Parsed incoming chat_uuid: $incomingChatUuid');
      final activeChatUuid = chatProvider.activeChatUuid;
      print('[FCM] Current active chat_uuid from provider: $activeChatUuid');

      final bool shouldShowNotification =
          notification != null && incomingChatUuid != activeChatUuid;
      print('[FCM] Should I show a notification? $shouldShowNotification');
      if (shouldShowNotification) {
        print('[FCM] Attempting to show local notification...');
      }
      print('-----------------------------------------');
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<UserProvider>(context).userRole;

    switch (userRole) {
      case UserRole.normal:
        return const NormalUserHomeScreen();
      case UserRole.manager:
      case UserRole.doctor:
      case UserRole.mixed:
        return const PrivilegedUserHomeScreen();
      default:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  }
}
