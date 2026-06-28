import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clarity/screens/login_screen.dart';
import 'package:clarity/services/api.dart';
import 'core/navigation.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final isLoggedIn = await AuthService.isLoggedIn();
  runApp(Clarity(isLoggedIn: isLoggedIn));
}

class Clarity extends StatelessWidget {
  final bool isLoggedIn;
  const Clarity({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isDark = themeNotifier.mode == ThemeMode.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: Color(0xFF0A1428),
                  systemNavigationBarIconBrightness: Brightness.light,
                )
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  systemNavigationBarColor: Colors.white,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
          child: MaterialApp(
            title: 'Clarity',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeNotifier.mode,
            home: isLoggedIn ? const MainScreen() : const LoginScreen(),
          ),
        );
      },
    );
  }
}
