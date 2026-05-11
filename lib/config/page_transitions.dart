import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

PageRouteBuilder<T> sharedAxisRoute<T>({
  required Widget page,
  RouteSettings? settings,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) =>
    PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: type,
            child: child,
          ),
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );

PageRouteBuilder<T> fadeThroughRoute<T>({
  required Widget page,
  RouteSettings? settings,
}) =>
    PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
