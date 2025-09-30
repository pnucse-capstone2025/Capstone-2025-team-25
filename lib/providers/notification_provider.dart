import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_model.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService notificationService = NotificationService();
  final FirebaseMessaging fcm = FirebaseMessaging.instance;

  Future<void> requestNotificationPermissions() async {
    print("Requesting notification permissions...");
    final notificationStatus = await Permission.notification.request();
    if (notificationStatus.isGranted) {
      print("Notification permission granted.");
    }
    if (!kIsWeb) {
      final scheduleStatus = await Permission.scheduleExactAlarm.request();
      if (scheduleStatus.isGranted) {
        print("Exact alarm permission granted.");
      }
      final fcmStatus = await fcm.requestPermission();
      if (fcmStatus.authorizationStatus == AuthorizationStatus.authorized) {
        print("FCM permission granted.");
      }
      final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
      if (batteryStatus.isGranted) {
        print("Battery optimization exemption granted.");
      }
    }
  }

  String convertLocalTimeToUtcString(String localTimeString) {
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    final parts = localTimeString.split(':');
    int hour = int.parse(parts[0]);
    hour -= 9;
    if (hour < 0) {
      hour += 24;
    }
    final minute = int.parse(parts[1]);
    final second = parts.length > 2 ? int.parse(parts[2]) : 0;
    final localTime = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      second,
    );
    final utcTime = localTime.toUtc();
    return DateFormat('HH:mm:ss').format(utcTime);
  }

  Future<int> handleOnce(AppTask task, TaskRule rule, int counter) async {
    if (rule.startTime == null) return counter;
    await notificationService.scheduleTaskNotifications(
      taskId: task.uuid,
      taskName: task.name,
      time: rule.startTime!,
      durationDays: rule.durationDays,
      startDate: task.startDate!,
      notificationIndex: counter++,
    );
    return counter;
  }

  Future<int> handleNTimesStrict(
    AppTask task,
    TaskRule rule,
    List<String> strictTimes,
    int counter,
  ) async {
    for (final time in strictTimes) {
      await notificationService.scheduleTaskNotifications(
        taskId: task.uuid,
        taskName: task.name,
        time: time,
        durationDays: rule.durationDays,
        startDate: task.startDate!,
        notificationIndex: counter++,
      );
    }
    return counter;
  }

  Future<int> handleNTimesInterval(
    AppTask task,
    TaskRule rule,
    int counter,
  ) async {
    try {
      final parsedTime = DateTime.parse(rule.startTime!);
      int hour = parsedTime.hour;
      int minute = parsedTime.minute;

      for (int i = 0; i < rule.count!; i++) {
        final scheduledTime = tz.TZDateTime(
          tz.UTC,
          2000,
          1,
          1,
          hour,
          minute,
        ).add(Duration(hours: i * rule.intervalHours!));
        final timeString =
            "${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}";
        await notificationService.scheduleTaskNotifications(
          taskId: task.uuid,
          taskName: task.name,
          time: timeString,
          durationDays: rule.durationDays,
          startDate: task.startDate!,
          notificationIndex: counter++,
        );
      }
    } catch (e) {
      print(
        "Error parsing time in _handleNTimesInterval for task ${task.uuid}: $e",
      );
    }
    return counter;
  }

  Future<int> handleInterval(AppTask task, TaskRule rule, int counter) async {
    if (rule.startTime == null || rule.intervalHours == null) return counter;
    try {
      final parsedTime = DateTime.parse(rule.startTime!);
      int hour = parsedTime.hour;
      int minute = parsedTime.minute;

      for (int i = 0; (hour + i * rule.intervalHours!) < 24; i++) {
        final scheduledTime = tz.TZDateTime(
          tz.UTC,
          2000,
          1,
          1,
          hour,
          minute,
        ).add(Duration(hours: i * rule.intervalHours!));
        final timeString =
            "${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}";
        await notificationService.scheduleTaskNotifications(
          taskId: task.uuid,
          taskName: task.name,
          time: timeString,
          durationDays: rule.durationDays,
          startDate: task.startDate!,
          notificationIndex: counter++,
        );
      }
    } catch (e) {
      print("Error parsing time in _handleInterval for task ${task.uuid}: $e");
    }
    return counter;
  }

  Future<int> handleMealBased(
    AppTask task,
    TaskRule rule,
    Map<String, dynamic> extras,
    UserSettings settings,
    String relation,
    List<String> meals,
    int counter,
  ) async {
    final mealTimes = {
      'breakfast':
          extras['breakfast_time'] as String? ?? settings.breakfastTime,
      'lunch': extras['lunch_time'] as String? ?? settings.lunchTime,
      'dinner': extras['dinner_time'] as String? ?? settings.dinnerTime,
    };
    final offset = (relation == 'before' ? -15 : 15);

    for (final meal in meals) {
      final baseTime = mealTimes[meal];
      if (baseTime == null) continue;

      final timeParts = baseTime.split(':');
      var scheduledTime = tz.TZDateTime(
        tz.UTC,
        2000,
        1,
        1,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      ).add(Duration(minutes: offset));

      if (meal == 'breakfast') {
        final prevDay = scheduledTime.subtract(const Duration(days: 1));
        if (!prevDay.isBefore(tz.TZDateTime.from(task.startDate!, tz.UTC))) {
          scheduledTime = prevDay;
        }
      }
      final timeString =
          "${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}";
      print(
        "Scheduling meal-based notification for task ${task.uuid} at $timeString",
      );
      await notificationService.scheduleTaskNotifications(
        taskId: task.uuid,
        taskName: task.name,
        time: timeString,
        durationDays: rule.durationDays,
        startDate: task.startDate!,
        notificationIndex: counter++,
      );
    }
    return counter;
  }

  Future<int> handleBedtime(
    AppTask task,
    TaskRule rule,
    Map<String, dynamic> extras,
    UserSettings settings,
    int counter,
  ) async {
    final bedtime = extras['bedtime'] as String? ?? settings.bedtime;
    await notificationService.scheduleTaskNotifications(
      taskId: task.uuid,
      taskName: task.name,
      time: bedtime,
      durationDays: rule.durationDays,
      startDate: task.startDate!,
      notificationIndex: counter++,
    );
    return counter;
  }

  Future<void> scheduleTaskNotifications(
    AppTask task, {
    UserSettings? settings,
  }) async {
    if (task.rule == null || task.startDate == null) {
      print(
        'Skipping notifications for task "${task.name}": Missing rule or start date.',
      );
      return;
    }

    await notificationService.cancelNotificationsForTask(task.uuid);
    print(
      'Cancelled previous notifications for task ${task.uuid}. Rescheduling...',
    );

    final userSettings = settings ?? UserSettings();

    final rule = task.rule!;
    Map<String, dynamic> extras = {};
    if (rule.extras != null && rule.extras!.isNotEmpty) {
      try {
        extras = jsonDecode(rule.extras!);
      } catch (e) {
        print("Error parsing extras JSON for task ${task.uuid}: $e");
      }
    }

    int notificationCounter = 0;

    switch (rule.ruleType) {
      case 'once':
        await handleOnce(task, rule, notificationCounter);
        break;
      case 'n_times':
        final strictTimes = List<String>.from(extras['strict_times'] ?? []);
        final correctUtcTimes = strictTimes.map((localTime) {
          return convertLocalTimeToUtcString(localTime);
        }).toList();

        if (correctUtcTimes.isNotEmpty) {
          notificationCounter = await handleNTimesStrict(
            task,
            rule,
            correctUtcTimes,
            notificationCounter,
          );
        } else if (rule.count != null &&
            rule.intervalHours != null &&
            rule.startTime != null) {
          notificationCounter = await handleNTimesInterval(
            task,
            rule,
            notificationCounter,
          );
        }
        break;
      case 'interval':
        await handleInterval(task, rule, notificationCounter);
        break;
      case 'meal_based':
        final relation = extras['relation'] as String? ?? 'before';
        final meals = List<String>.from(extras['meals'] ?? []);
        await handleMealBased(
          task,
          rule,
          extras,
          userSettings,
          relation,
          meals,
          notificationCounter,
        );
        break;
      case 'bedtime':
        await handleBedtime(
          task,
          rule,
          extras,
          userSettings,
          notificationCounter,
        );
        break;
    }
  }
}

