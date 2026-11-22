import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'domain/engine/soc_calculator.dart' show lookupBaseSOC;
import 'core/theme/theme_provider.dart';
import 'presentation/pages/home/home_page.dart';

const bool _nativeTableEnabled = bool.fromEnvironment('SOC_NATIVE_TABLE');

void _assertNativeReferenceParity() {
  // Canary verification of the ACTUAL release-compiled FFI path; a packer
  // that breaks exported symbols must fail immediately rather than silently
  // pass a UI-only smoke test.
  const checks = <(String, int, int, double)>[
    ('F', 0, 10, 23.90),
    ('F', 70, 55, 7.70),
    ('UNF', 0, 25, 17.71),
    ('UNF', 70, 55, 8.56),
  ];
  for (final (fert, erosion, depth, expected) in checks) {
    final actual = lookupBaseSOC(fert, erosion, depth);
    if (actual == null || (actual - expected).abs() > 1e-9) {
      throw StateError('Protected SOC reference validation failed');
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_nativeTableEnabled) {
    _assertNativeReferenceParity();
  }
  runApp(const ProviderScope(child: SocApp()));
}

class SocApp extends ConsumerWidget {
  const SocApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);

    return MaterialApp(
      title: '碳盾 SOC-Shield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(seedColor),
      darkTheme: AppTheme.darkTheme(seedColor),
      themeMode: themeMode,
      home: const HomePage(),
    );
  }
}
