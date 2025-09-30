import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import '../models/chat_models.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final chatService = ChatService();
  final notificationService = NotificationService();
  await notificationService.init();

  String? userUuid;
  List<Chat> currentChats = [];

  service.on('setUserUuid').listen((data) {
    userUuid = data?['userUuid'];
    print("Background service received userUuid: $userUuid");
  });

  Timer.periodic(const Duration(seconds: 2), (timer) async {
    if (userUuid != null) {
      try {
        final Map<String, DateTime> oldLastMessageTimestamps = {
          for (var chat in currentChats) chat.chatUuid: chat.lastMessageSentAt,
        };

        final newChats = await chatService.getChats(userUuid!);

        for (final chat in newChats) {
          final oldTimestamp = oldLastMessageTimestamps[chat.chatUuid];
          final newTimestamp = chat.lastMessageSentAt;

          if (oldTimestamp == null || newTimestamp.isAfter(oldTimestamp)) {
            if (chat.lastMessageSenderUuid != userUuid) {}
          }
        }
        currentChats = newChats;
      } catch (e) {
        print("Background polling failed: $e");
      }
    }
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(onForeground: onStart, autoStart: true),
  );
}
