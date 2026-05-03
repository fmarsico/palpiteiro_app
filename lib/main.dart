import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_colors.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const PalpiteiroApp());
}

class PalpiteiroApp extends StatelessWidget {
  const PalpiteiroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palpiteiro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.gold,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: GoogleFonts.dmSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.card,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
