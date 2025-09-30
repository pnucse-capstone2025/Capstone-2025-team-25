import 'package:flutter/material.dart';


const kPrimaryColor = Color(0xFF4BB6B7);
const kTextColor = Color(0xFF3C4046);
const kBackgroundColor = Color(0xFFF6F5F7);

class UserSettings {
  final String breakfastTime; // "HH:mm"
  final String lunchTime; // "HH:mm"
  final String dinnerTime; // "HH:mm"
  final String bedtime; // "HH:mm"

  UserSettings({
    this.breakfastTime = '23:00', //  8:00 AM KST
    this.lunchTime = '03:30', // 12:30 PM KST
    this.dinnerTime = '10:00', // 7:00 PM KST
    this.bedtime = '13:30', // 10:30 PM KST
  });
}


final String? kBaseUrl = 'http://127.0.0.1:3000';
