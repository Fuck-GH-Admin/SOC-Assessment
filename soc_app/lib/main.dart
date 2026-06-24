import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/home/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SocApp(),
    ),
  );
}

class SocApp extends StatelessWidget {
  const SocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOC 土壤碳评估',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
