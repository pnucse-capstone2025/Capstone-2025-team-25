// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth_check_screen.dart';
import 'utils/constants.dart';
import 'services/notification_service.dart';
import 'providers/notification_provider.dart';
import 'services/background_service.dart';
import 'providers/chat_provider.dart';
import 'providers/task_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/task_request_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'providers/ddi_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await initializeService();
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DdiProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => TaskRequestProvider()),
        ChangeNotifierProxyProvider<UserProvider, ChatProvider>(
          create: (context) => ChatProvider(null),
          update: (context, userProvider, previousChatProvider) {
            final chatProvider = previousChatProvider!;
            chatProvider.updateUser(userProvider.userUuid);
            if (userProvider.userUuid == null) {
              chatProvider.clearChats(); 
            }
            return chatProvider;
          },
        ),
        ChangeNotifierProxyProvider<UserProvider, ProfileProvider>(
          create: (context) => ProfileProvider(null),
          update: (context, userProvider, previousProfileProvider) {
            final profileProvider = previousProfileProvider!;
            profileProvider.updateUser(userProvider.userUuid);
            if (userProvider.userUuid == null) {
              profileProvider.clearProfile(); 
            }
            return profileProvider;
          },
        ),
        ChangeNotifierProxyProvider<UserProvider, TaskProvider>(
          create: (context) =>
              TaskProvider(null),
          update: (context, userProvider, previousTaskProvider) {
            final taskProvider = previousTaskProvider!;
            taskProvider.updateUser(userProvider.userUuid);

            if (userProvider.userUuid == null) {
              taskProvider.clearTasks();
            }

            return taskProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'UmiDo App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor),
          primaryColor: kPrimaryColor,
          scaffoldBackgroundColor: kBackgroundColor,
          useMaterial3: true,
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: kPrimaryColor,
          ),
        ),
        home: const AuthCheckScreen(),
      ),
    );
  }
}
