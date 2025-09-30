// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late final tz.Location _local;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      print("NotificationService already initialized.");
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    tz.initializeTimeZones();
    _local = tz.local;

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _isInitialized = true;
    print("NotificationService initialized successfully.");
  }

  Future<void> scheduleTaskNotifications({
    required String taskId, 
    required String taskName,
    required String time,
    required DateTime startDate,
    required int notificationIndex,
    int? durationDays,
  }) async {
    final int numericTaskId = taskId.hashCode.abs();
    final tz.Location localLocation = _local;
    final tz.TZDateTime nowInLocal = tz.TZDateTime.now(localLocation);

    int hour, minute;
    try {
      if (time.contains('T')) {
        final dateTime = DateTime.parse(time);
        hour = dateTime.hour;
        minute = dateTime.minute;
      } else {
        final parts = time.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      }
    } catch (e) {
      print("❗ Error parsing time '$time' for task $taskId: $e");
      return;
    }

    DateTime effectiveStartDate = startDate;
    if (hour < 23 && hour > 15) {
      effectiveStartDate = startDate.subtract(const Duration(days: 1));
    }

    final tz.TZDateTime startDateLocal = tz.TZDateTime.from(
      effectiveStartDate,
      localLocation,
    );

    final int constrainedTaskId = numericTaskId % 1000000;
    final int baseNotificationId =
        (constrainedTaskId * 1000) + notificationIndex;

    if (durationDays != null && durationDays > 0) {
      final endDate = startDateLocal.add(Duration(days: durationDays));
      for (int i = 0; i < durationDays; i++) {
        final dayToSchedule = startDateLocal.add(Duration(days: i));
        tz.TZDateTime scheduledDate = tz.TZDateTime(
          localLocation,
          dayToSchedule.year,
          dayToSchedule.month,
          dayToSchedule.day,
          hour,
          minute,
        );
        if (scheduledDate.isBefore(nowInLocal)) {
          continue;
        }
        if (scheduledDate.isBefore(endDate)) {
          final int dailyNotificationId = baseNotificationId + i;
          await _zonedSchedule(
            id: dailyNotificationId,
            title: taskName,
            body: 'Time for your task: $taskName',
            scheduledDate: scheduledDate,
          );
        }
      }
    } else {
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        localLocation,
        nowInLocal.year,
        nowInLocal.month,
        nowInLocal.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(nowInLocal)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      await _zonedSchedule(
        id: baseNotificationId,
        title: taskName,
        body: 'Time for your task: $taskName',
        scheduledDate: scheduledDate,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel_id',
          'Task Notifications',
          channelDescription: 'Reminders for your tasks.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(sound: 'default.wav'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  Future<void> cancelNotificationsForTask(String taskId) async {
    final int numericId = taskId.hashCode.abs();
    final int constrainedTaskId = numericId % 1000000;
    final int baseId = constrainedTaskId * 1000;
    final int range = 1000;

    final pendingRequests = await flutterLocalNotificationsPlugin
        .pendingNotificationRequests();
    for (final request in pendingRequests) {
      if (request.id >= baseId && request.id < (baseId + range)) {
        await flutterLocalNotificationsPlugin.cancel(request.id);
      }
    }
  }
}
