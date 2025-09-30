import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class VerticalAxisTransition extends PageRouteBuilder {
  final Widget page;

  VerticalAxisTransition({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
}