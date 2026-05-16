import 'package:flutter/material.dart';

import 'auth/login_screen.dart';
import 'splash/splash_screen.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  bool _splashComplete = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashComplete) {
      return SplashScreen(
        onComplete: () {
          setState(() {
            _splashComplete = true;
          });
        },
      );
    }

    return const LoginScreen();
  }
}


